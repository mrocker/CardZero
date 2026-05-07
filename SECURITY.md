# CardZero Security Policy

## Reporting a vulnerability

We welcome responsible disclosure. Please report security issues via:

- **Email:** [security@cardzero.ai](mailto:security@cardzero.ai)
- **GitHub Security Advisories:** [Open a draft advisory](https://github.com/mrocker/CardZero/security/advisories/new)

We aim to respond within **72 hours**, and to provide a fix or mitigation plan
within **2 weeks** of acknowledgment for confirmed issues.

Please do **not** publicly disclose a vulnerability before we have had a
chance to respond.

## Scope

The following are in scope and bounty-eligible (case-by-case, current beta):

| Area | Examples |
| --- | --- |
| **Smart contracts** (Base mainnet, see README) | Reentrancy, access-control, unauthorized fund movement, upgrade hijack, paymaster drain |
| **API** ([api.cardzero.ai](https://api.cardzero.ai)) | Auth bypass, IDOR, ownership confusion, idempotency-replay |
| **Cryptographic handling** | Session-key encryption, API-key derivation, webhook HMAC |
| **Dashboard** ([cardzero.ai](https://cardzero.ai)) | XSS that touches token storage, CSRF on mutating endpoints |

The following are **out of scope**:

- DoS / rate-limit bypass without a privilege escalation path
- Self-XSS or social-engineering
- Issues only reproducible on outdated browsers
- "Best practice" suggestions (HSTS, CSP tweaks) without a concrete bypass

## On-chain assets

CardZero's mainnet contracts are listed in the [README](README.md). All
contracts are non-custodial: only the user's smart-contract wallet (with
their session keys) can move funds.

## Beta status

CardZero is in **public beta** as of 2026-05. We recommend keeping per-wallet
balances under **$100 USDC** until external audit completes (Code4rena
contest planned). See [Wallet concepts](https://cardzero.ai/docs/concepts/wallet)
for the on-chain policy enforcement model.

## Hall of fame

We will publicly thank disclosers (with their permission) here once the
first valid report is resolved.
