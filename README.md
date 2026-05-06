# CardZero

[![ClawHub](https://img.shields.io/badge/ClawHub-cardzero%40v1.4.0-blue)](https://clawhub.ai/mrocker/cardzero)
[![npm](https://img.shields.io/npm/v/cardzero-mcp)](https://www.npmjs.com/package/cardzero-mcp)
[![Base](https://img.shields.io/badge/Chain-Base%20L2-0052FF)](https://base.org)
[![x402](https://img.shields.io/badge/Protocol-x402-green)](https://x402.org)
[![ERC-8004](https://img.shields.io/badge/A2A-ERC--8004%20%2B%20ERC--8183-purple)](https://eips.ethereum.org)
[![USDC](https://img.shields.io/badge/Currency-USDC-2775CA)](https://www.circle.com/usdc)

**The first universal payment wallet for AI Agents.**

> **Beta** — Smart contract audit in progress. Recommended wallet balance: < $100 USDC.

## What is CardZero?

CardZero gives every AI Agent its own on-chain wallet on [Base](https://base.org) (Coinbase L2). Funded with USDC, each wallet is controlled by a human owner who sets spending rules — per-transaction limits, daily caps, address whitelists, and emergency freeze. The Agent operates autonomously within those rules.

Think of it as the first credit card for your AI Agent. Configure it once, and your Agent can pay for APIs, data, and services as naturally as it can search the web.

## How it Works

```
1. Agent creates a wallet       POST /v1/wallets (zero gas, instant)
       |
2. Agent tells Owner the claim key
       |
3. Owner claims on Dashboard    https://cardzero.ai
   - Sets username & password
   - Configures spending rules
   - Gets Agent Configuration (API Key + Wallet ID)
       |
4. Owner gives config to Agent
       |
5. Agent pays autonomously      POST /v1/payments (USDC, on-chain)
```

## Quick Start

### 1. OpenClaw

Add the [`SKILL.md`](plugins/openclaw/SKILL.md) to your agent's skills directory. It contains everything your Agent needs: API endpoints, authentication, wallet lifecycle, error handling, and payment instructions.

### 2. Claude Code

Copy the snippet from [`plugins/claude-code/SKILL.md`](plugins/claude-code/SKILL.md) into your project's `CLAUDE.md`. Set the environment variables:

```
CARDZERO_API_URL=https://api.cardzero.ai/v1
CARDZERO_API_KEY=czapi_your_key_here
CARDZERO_WALLET_ID=wallet_your_id_here
```

### 3. ChatGPT

Import [`plugins/chatgpt/openapi.json`](plugins/chatgpt/openapi.json) as a Custom Action in your GPT configuration.

### 4. Cursor / Windsurf

Copy [`plugins/cursor/.cursorrules`](plugins/cursor/.cursorrules) to your project root as `.cursorrules` (Cursor) or `.windsurfrules` (Windsurf).

### 5. MCP Server (Claude Desktop, Cursor, VS Code)

```bash
npx -y cardzero-mcp
```

Configure with your API Key and Wallet ID. See [`plugins/mcp/README.md`](plugins/mcp/README.md) for setup instructions for each platform.

### 6. Any Platform

CardZero is a standard REST API. If your Agent can make HTTP requests, it can use CardZero. See the [API endpoints](#api-at-a-glance) below or the full [OpenAPI spec](openapi.yaml).

## API at a Glance

Base URL: `https://api.cardzero.ai/v1`

| Action | Method | Endpoint | Auth |
|--------|--------|----------|------|
| Create wallet | `POST` | `/wallets` | None |
| Check balance | `GET` | `/wallets/{id}/balance` | API Key |
| Make payment | `POST` | `/payments` | API Key |
| Payment history | `GET` | `/wallets/{id}/payments` | API Key |
| x402 payment | `POST` | `/x402/pay` | API Key |
| Payment status | `GET` | `/payments/{id}` | None |
| **Create Job** (A2A escrow) | `POST` | `/jobs` | API Key |
| **Fund Job** | `POST` | `/jobs/{id}/fund` | API Key |
| **Submit deliverable** | `POST` | `/jobs/{id}/submit` | API Key |
| **Check Job state** | `GET` | `/jobs/{id}` | None |
| **Reputation** (ERC-8004) | `GET` | `/reputation/{walletAddress}` | None |
| **Catalog** | `GET` | `/catalog` | None |

Authentication: `Authorization: Bearer czapi_...`

**Pricing:**
- Direct payments: 2% service fee (recipient gets full amount, fee deducted from wallet)
- Job escrow: 2% platform fee + 5% evaluator fee (split on Job completion)

For complete API documentation, see [`openapi.yaml`](openapi.yaml).

## A2A Escrow (ERC-8183) — v1.4.0

CardZero is the first non-token-gated implementation of ERC-8004 (Identity + Reputation) and ERC-8183 (Job lifecycle escrow). Use Jobs when you need a Provider Agent to deliver something specific:

```
1. Client → POST /jobs            (creates Job, status='open')
2. Client → POST /jobs/{id}/fund  (locks budget USDC, status='funded')
3. Provider → POST /jobs/{id}/submit  (posts deliverable hash, status='submitted')
4. Evaluator (CardZero EOA) auto-runs → split funds + reputation event
   - approved: provider 93% + evaluator 5% + platform 2%
   - rejected: full refund to client
5. (or) After expiry: Client → POST /jobs/{id}/refund
```

All four lifecycle transitions are anchored on Base mainnet with on-chain reputation reflection.

## Dashboard

Manage your Agent's wallets at **[cardzero.ai](https://cardzero.ai)**:

- Claim wallets and set up your account
- Fund wallets with USDC on Base
- Configure spending rules (per-tx limit, daily limit, whitelist)
- Freeze/unfreeze wallets instantly
- View payment history with on-chain transaction links
- Rotate API keys

## Examples

See [`examples/curl.sh`](examples/curl.sh) for curl commands covering the core API workflow.

## Links

- **Dashboard:** [cardzero.ai](https://cardzero.ai)
- **MCP Server:** [npmjs.com/package/cardzero-mcp](https://www.npmjs.com/package/cardzero-mcp)
- **ClawHub SKILL:** [clawhub.ai/mrocker/cardzero](https://clawhub.ai/mrocker/cardzero)
- **API Docs:** [cardzero.ai/docs/api](https://cardzero.ai/docs/api)
- **Getting Started:** [cardzero.ai/docs/getting-started](https://cardzero.ai/docs/getting-started)
- **OpenAPI Spec:** [`openapi.yaml`](openapi.yaml)
- **FAQ:** [cardzero.ai/docs/faq](https://cardzero.ai/docs/faq)
- **x402 Protocol:** [x402.org](https://x402.org)

## License

Proprietary. All rights reserved.
