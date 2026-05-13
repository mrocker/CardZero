# CardZero Deployment Ceremony

> Public-facing record of how CardZero's on-chain components are deployed and operated on Base mainnet. Written for peer protocol teams, auditors, and integrators evaluating the operational threat model. Companion to `docs/SECURITY-REVIEW.md` and `docs/SPRINT8-DEPLOY-CEREMONY.md` (internal step-by-step).

**Last updated:** 2026-05-13
**Scope:** CardZeroFactory / CardZeroFactoryV3 (wallet factories), CardZeroWallet V1/V2/V3 (account contracts), CardZeroJobs (ERC-8183 escrow), CardZeroIdentityRegistry + CardZeroReputationRegistry (ERC-8004)

---

## 1. Principles

1. **Deterministic addresses.** Every wallet address is predictable from `(owner, agentSalt)` before any chain interaction. Clients can be told "your wallet is `0x…`" and pre-fund it before the contract is deployed.
2. **Idempotent deployment.** Re-calling `createWallet` with the same inputs is a no-op, not a revert. A bundler retry or paymaster replay cannot create a divergent state.
3. **Role isolation.** Privileged operations are split across four EOAs that never share a private key with any other role. Compromising any one EOA bounds the blast radius.
4. **Frozen commitments.** The scoring rules that drive reputation events are committed on-chain as a `keccak256` hash of a public document. Any post-hoc change to the document is detectable by recomputing.
5. **Sepolia full-lifecycle gate.** No mainnet deployment lands without the same end-to-end flow having run green on Sepolia.
6. **Separated post-deploy operations.** Role grants, registry wiring, and admin handoffs each happen as their own transaction, so each is independently inspectable on Basescan.

---

## 2. Deterministic CREATE2 salt step

The wallet factory uses OpenZeppelin's `Create2.deploy` over an `ERC1967Proxy` constructor. The user-facing salt is composed:

```solidity
// CardZeroFactory.createWallet (and CardZeroFactoryV3.createWallet)
bytes32 finalSalt = keccak256(abi.encodePacked(owner, agentSalt));

bytes memory initData = abi.encodeCall(
    CardZeroWallet.initialize,
    (owner, feeRate, feeRecipient)
);

bytes memory proxyBytecode = abi.encodePacked(
    type(ERC1967Proxy).creationCode,
    abi.encode(address(walletImplementation), initData)
);

address predicted = Create2.computeAddress(finalSalt, keccak256(proxyBytecode));

// Idempotent — re-call returns the same address without redeploying
if (predicted.code.length > 0) return predicted;

wallet = Create2.deploy(0, finalSalt, proxyBytecode);
```

### Salt composition rationale

- **`owner` is part of the salt.** This means two different owners passing the same `agentSalt` get two different addresses. Salt collisions across owners are impossible.
- **`agentSalt` is per-wallet client-side identifier.** CardZero's API generates this as a random 32-byte value at wallet-creation request time and stores it in the off-chain DB.
- **`abi.encodePacked` (not `abi.encode`).** 32-byte `agentSalt` + 20-byte `owner` packs to exactly 52 bytes with no padding ambiguity. The kept-it-tight choice — `encode` would have given the same security but with unnecessary padding.
- **Fee params are NOT in the salt** but ARE in `initData`, which IS hashed into the CREATE2 calculation via `keccak256(proxyBytecode)`. So changing `feeRate` or `feeRecipient` changes the predicted address — the same `(owner, agentSalt)` pair maps to different addresses on different fee configurations. This is by design: it makes fee rates a frozen-at-deploy commitment per wallet.

### Pre-deployment prediction

API clients call `Factory.getWalletAddress(owner, agentSalt, feeRate, feeRecipient) returns (address)` as a `view` function. No chain state is mutated. Owner can pre-fund the predicted address with USDC; ERC-4337 sponsors the eventual deployment via the bundler on first userOp.

### Idempotency guarantee

```solidity
if (predicted.code.length > 0) return predicted;
```

Re-calling `createWallet` for an already-deployed wallet returns the existing address without consuming the `CREATE2` opcode. This protects against:

- Bundler retries during paymaster failures
- Concurrent claim attempts from the same client
- Cross-region API instances both attempting deployment

A divergent state is impossible because there's only one valid bytecode hash for any `(owner, agentSalt, feeRate, feeRecipient)` tuple.

### Why not direct `CREATE` with `nonce`?

`CREATE` addresses depend on the deployer's nonce, which is a global counter on the factory account. That makes pre-deployment prediction fragile (any other deploy increments the nonce and invalidates the prediction). `CREATE2` keeps the predicted address stable regardless of unrelated factory activity.

---

## 3. EOA role isolation (4-key model)

Four mainnet EOAs, each with a single role, generated independently and never sharing a key:

| Role | Address | Holds | Funded with | Notes |
|------|---------|-------|-------------|-------|
| **DEPLOYER** | `0x79985809b620F488D524fFA2e29c1377e018edce` | `ADMIN_ROLE` on all UUPS contracts; factory deployer | ~0.05 ETH | Currently single-key. Migration to 2-of-3 Safe + 48h TimelockController is the next pre-audit step (see §6). |
| **REGISTRAR** | `0xfd865c3C6AbC3F714D587c583166dd096a7EED51` | `REGISTRAR_ROLE` on `CardZeroIdentityRegistry` | ~0.02 ETH | Calls `register()` on agent claim. Cannot transfer USDC. |
| **ATTESTOR** | `0xf76a7a569060fD800dcfc2c2EEa8a4060385a1D4` | `ATTESTOR_ROLE` on `CardZeroReputationRegistry` | ~0.02 ETH | Writes reputation events. Cannot transfer USDC. |
| **EVALUATOR** | `0x8157Cb8e28707eD7aeC693662D51563c63620E59` | `EVALUATOR_ROLE` on `CardZeroJobs` | ~0.02 ETH | Calls `evaluatorComplete()` / `evaluatorReject()` for service-delivery escrow. Cannot withdraw escrow to itself. |

### Properties verified at deploy time

The deploy script's self-check enforces:

1. `DEPLOYER` does **not** hold `REGISTRAR_ROLE`, `ATTESTOR_ROLE`, or `EVALUATOR_ROLE` on any contract.
2. `REGISTRAR` holds *only* `REGISTRAR_ROLE`.
3. `ATTESTOR` holds *only* `ATTESTOR_ROLE`.
4. `EVALUATOR` holds *only* `EVALUATOR_ROLE`.
5. No EOA holds USDC at deploy completion (compromised hot keys cannot drain a balance that doesn't exist).
6. Each role's `getRoleMemberCount` is exactly 1.

The script aborts if any check fails. The mainnet deployment passed all six checks for the Sprint 8 (Identity/Reputation) and Sprint 9 (Jobs + V3 wallet) batches.

### Blast-radius bounds

- **REGISTRAR compromise:** Attacker can register arbitrary agent identities. Cannot affect existing reputation scores or move funds. Mitigation: `revoke + grant` to a fresh EOA via DEPLOYER.
- **ATTESTOR compromise:** Attacker can write reputation events. Cannot register agents or move funds. Reputation aggregator can flag the compromised window and discount events in that range. Mitigation: same as REGISTRAR.
- **EVALUATOR compromise:** Attacker can complete or reject jobs that are in `submitted` status. Cannot complete jobs that aren't submitted, cannot drain treasury. Bounded by `dailyCompleteLimit` (5000 USDC). Mitigation: rotation + on-call review of any complete/reject txs during the compromise window.
- **DEPLOYER compromise (today):** Worst case — can upgrade contracts arbitrarily. This is the SPoF that §6 addresses.

---

## 4. SCORING_RULES_HASH commitment

The reputation system's scoring methodology is committed at registry deploy as:

```solidity
bytes32 public immutable scoringRulesHash; // set in initializer
string public scoringRulesURI;              // points to public mirror
```

Current values (Base mainnet):

- `scoringRulesHash` = `0xe23c8005889bb20bf2214f125f498ada9b7e81776af010c2fb21c5387a4f06c3`
- `scoringRulesURI` = `https://cardzero.ai/SCORING-RULES.md`

The document at the URI is the canonical source. Any third party can fetch it and verify:

```bash
curl -s https://cardzero.ai/SCORING-RULES.md > /tmp/scoring.md
node -e "
  const { keccak256, toBytes } = require('viem');
  const fs = require('fs');
  console.log(keccak256(toBytes(fs.readFileSync('/tmp/scoring.md', 'utf8'))));
"
# expected: 0xe23c8005889bb20bf2214f125f498ada9b7e81776af010c2fb21c5387a4f06c3
```

If the on-chain hash and computed hash diverge, either the document was modified post-commitment (detectable; would require an admin `updateScoringRules` tx to re-commit) or the deployment is on a different chain.

### Why this matters for evaluator design

When discussing `scoringRulesHash` versus per-evaluator metadata (ERC-8183 thread, [magicians/27902/239](https://ethereum-magicians.org/t/erc-8183-agentic-commerce/27902/239)), the protocol-wide hash provides uniformity of attestation semantics for single-evaluator deployments. CardZero is currently single-evaluator; if/when we open up to third-party evaluators, the migration path is `EvaluatorRegistry.setMetadata(evaluator, methodologyURI)` per evaluator, of which protocol-wide hash is the one-entry degenerate case.

---

## 5. Sepolia full-lifecycle gate

Every mainnet deploy is preceded by a Sepolia deploy of the same artifact, executing the full lifecycle that mainnet will exercise. For wallets, that's:

1. Predict address (`Factory.getWalletAddress`)
2. Deploy via first userOp (paymaster-sponsored)
3. Grant session key (`grantSessionKey`)
4. Execute payment (`transfer` USDC)
5. Verify on-chain state matches expectations

For ERC-8004:

1. Register one agent via `REGISTRAR`
2. Write one reputation event via `ATTESTOR`
3. Verify `getReputation(agentId)` returns the event
4. Verify `scoringRulesHash` reads back correctly

For ERC-8183 / CardZeroJobs:

1. `createJob` → `clientApprove` → `fund` → `submit` → `evaluatorComplete`
2. Verify provider, evaluator, treasury splits match `platformFeeBps` / `evaluatorFeeBps`
3. Verify `CardZeroReputationRegistry` received the auto-attestation

Mainnet deploy is gated on:

- Sepolia smoke test ≥ 1 day old (lets a cron tick catch regressions)
- Self-check 6/6 green
- Founder review of Sepolia deployment artifacts

This gate caught the `uint64` vs `uint256` `expiry` ABI bug during Sprint 9 — a function selector mismatch that would have caused silent reverts on mainnet. Fixed before mainnet deploy.

---

## 6. Migration: Multisig + Timelock (planned, pre-audit)

**Current state:** `ADMIN_ROLE` on all four UUPS contracts (`CardZeroJobs`, `CardZeroIdentityRegistry`, `CardZeroReputationRegistry`, `CardZeroWalletV3` implementation upgrades) is held by `DEPLOYER` EOA.

**Target state:**

```
DEPLOYER EOA  →  Safe (2-of-3, Base)  →  TimelockController (48h delay)  →  ADMIN_ROLE
```

**Why both, not just one:**

- **Safe alone, no timelock:** removes single-key SPoF but allows surprise upgrades. Community has no review window.
- **Timelock alone, no Safe:** gives 48h review window but the proposer is still a single key. If compromised, attacker queues a malicious upgrade and waits.
- **Safe + Timelock:** removes SPoF AND gives community review. Attacker needs to compromise 2 of 3 signers AND wait 48h, during which the queued upgrade is visible on-chain and revocable.

**Sequence (executed per contract):**

```
1. Deploy TimelockController on Base mainnet (proposer = Safe, executor = Safe, delay = 172800s)
2. From DEPLOYER: contract.grantRole(ADMIN_ROLE, timelock)
3. Verify on Basescan: contract.hasRole(ADMIN_ROLE, timelock) == true
4. Test: queue a no-op admin call via Safe → wait 48h → execute → verify
5. From DEPLOYER: contract.renounceRole(ADMIN_ROLE, deployer)
6. Verify on Basescan: contract.hasRole(ADMIN_ROLE, deployer) == false
   AND contract.getRoleMemberCount(ADMIN_ROLE) == 1
```

Each step is a separate tx, individually visible on Basescan, in this order. Step 5 is the **point of no return** — after renounceRole, only the Safe (through the timelock) can administer the contract.

**Rollback options:**

- Before Step 5: revert by `grantRole` back to deployer + `revokeRole(timelock)`.
- After Step 5: rollback requires the Safe to queue a `grantRole(ADMIN_ROLE, newKey)` tx through the timelock — same 48h window.

**Sepolia rehearsal:** Full sequence runs on Sepolia first with throwaway signers, confirming the Safe + TimelockController + UUPS chain executes a real upgrade end-to-end.

Tracked in `docs/MULTISIG-TIMELOCK-MIGRATION.md` (execution plan + scripts).

---

## 7. Post-deploy operations as separated transactions

Operations that *could* be bundled but are intentionally separated:

| Operation | Why separate | Verifiable as |
|-----------|--------------|---------------|
| `Jobs.setReputationAttestor(reputationRegistry)` | Wires Jobs → Reputation. Done after Reputation has granted Jobs the `ATTESTOR_ROLE`. | One Basescan tx, function selector + decoded args readable. |
| `Reputation.grantRole(ATTESTOR_ROLE, jobs)` | Allows Jobs to attest reputation on `finalizeJob`. | One Basescan tx. |
| Per-EOA role grants (`grantRole(REGISTRAR_ROLE, registrarEOA)`, etc.) | Each grant is reviewed independently. | One Basescan tx per role. |
| `renounceRole(ADMIN_ROLE, deployer)` (after multisig migration) | Point of no return; deserves its own audit-trail entry. | One Basescan tx. |

Bundling these into a multicall would shave gas but lose the per-step audit trail. We pay the gas premium.

---

## 8. Reference

### Current mainnet deployments (Base, chainId 8453)

| Contract | Address | Proxy mode |
|----------|---------|------------|
| `CardZeroFactory` (V1) | `0xebf66b2dfcd8c4f96248ddfedc8f7c49d49f7283` | EIP-1167 (frozen) |
| `CardZeroFactory` (V2) | `0xa3fc38f1b9379ed269a9ac75b6de229fa55e412e` | ERC-1967 UUPS |
| `CardZeroFactoryV3` | `0x0c1d37f49ab9da5b6da2e2938be5567fbba4aabb` | ERC-1967 UUPS |
| `CardZeroWalletV2` impl | `0x601b1E85931fa25e2e82B387c829302D56De7470` | ERC-1967 UUPS |
| `CardZeroWalletV3` impl | `0x70ff113944ad5dcF11A28B240c8F3244112C2298` | ERC-1967 UUPS |
| `CardZeroIdentityRegistry` | `0x1db9b790ae49def806d3d16172de04d2557fecbe` | ERC-1967 UUPS |
| `CardZeroReputationRegistry` | `0xc00a5757c63d65005d22e507eae045df5e83b338` | ERC-1967 UUPS |
| `CardZeroJobs` | `0xb28a0cca5ac28466f3d175f35b97aa104d4c4ba8` | ERC-1967 UUPS |
| USDC (canonical) | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | n/a |
| EntryPoint (canonical) | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` | n/a |

### Public commitments

- Scoring rules document: https://cardzero.ai/SCORING-RULES.md
- Agent registration files: https://cardzero.ai/.well-known/agent/{walletAddress}
- LLM-friendly corpus: https://cardzero.ai/llms-full.txt
- OpenAPI: https://cardzero.ai/openapi.yaml

### Companion documents

- `docs/SECURITY-REVIEW.md` — code-level audit findings (Sprint 7 → present)
- `docs/SPRINT8-DEPLOY-CEREMONY.md` — internal step-by-step Sprint 8 deploy log
- `docs/MULTISIG-TIMELOCK-MIGRATION.md` — execution plan for §6
- `docs/STRATEGY-A2A-ESCROW.md` — context for ERC-8004/8183 inclusion
- `docs/PRE-LAUNCH-AUDIT.md` — pre-launch 13-dimension self-review

---

## 9. Open invitations

We welcome:

- Auditor scoping reviews against this document (`security@cardzero.ai`)
- Peer-protocol comparison: send your equivalent and we'll publish a side-by-side
- Issues filed against any of the linked commitments
- Patches to the salt computation, role isolation, or migration plan that strengthen the model without breaking address determinism

Last reviewed by: Nicholas (mrocker), 2026-05-13.
