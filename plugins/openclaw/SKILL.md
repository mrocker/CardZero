---
name: cardzero
version: 1.1.0
description: CardZero Agent Wallet — create wallets, check balance, execute USDC payments, view transaction history
tags: [payment, wallet, usdc, web3, agent]
requires:
  - CARDZERO_API_URL: CardZero API base URL (e.g. https://api.cardzero.ai)
  - CARDZERO_API_KEY: Your API Key (received from Owner after they claim the wallet)
  - CARDZERO_WALLET_ID: Your wallet ID (set after wallet creation)
---

# CardZero Payment Wallet

> **Beta** — Smart contract audit in progress. Recommended wallet balance: < $100 USDC.

You have a CardZero payment wallet on Base (Coinbase L2). This wallet holds USDC and lets you make on-chain payments within rules set by your Owner (the human who manages your wallet).

## Capabilities

1. **Create a new wallet** — Register a wallet for your Owner to claim
2. **Check balance** — Query your current USDC balance
3. **Make payments** — Send USDC to any address
4. **View payment history** — See recent transactions

## Authentication

All endpoints except **Create Wallet** require your API Key:

```
Authorization: Bearer czapi_xxxxxxxx_yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy
```

You receive this API Key from your Owner after they claim the wallet. Store it as `CARDZERO_API_KEY`.

## Wallet Lifecycle

A wallet goes through two stages:

1. **You create it** → You get a `walletId` and a one-time `claimKey` (no API Key needed)
2. **Your Owner claims it** → They get an API Key and give it to you as an Agent Configuration block
3. **You start operating** → Use the API Key for all subsequent requests

Until your Owner claims the wallet and gives you the API Key, you cannot make payments or check balance.

### Agent Configuration

After claiming, your Owner will give you a block like this:

```
== CardZero Agent Configuration ==
API Key:   czapi_a1b2c3d4_e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4
Wallet ID: wallet_7370ee785775
API URL:   https://api.cardzero.ai/v1
```

When you receive this, extract and save:
- `CARDZERO_API_KEY` — the API Key (starts with `czapi_`)
- `CARDZERO_WALLET_ID` — the wallet ID
- `CARDZERO_API_URL` — the API base URL

## Rules

### Before every payment
- Tell the user the **amount**, **recipient address**, and **reason** before sending
- If the user hasn't confirmed, ask for confirmation first

### When something goes wrong
- `INSUFFICIENT_BALANCE` → Tell the user your balance is too low and suggest they add funds
- `WALLET_FROZEN` → Tell the user your wallet has been frozen by the Owner and you cannot make payments until they unfreeze it
- `NO_SESSION_KEY` → This is rare — session keys are auto-managed by CardZero. If this persists, ask the Owner to contact support
- `WALLET_NOT_ACTIVE` → The wallet hasn't been claimed yet; remind the user to claim it with the claimKey you provided
- `INVALID_API_KEY` → Your API Key is invalid or has been revoked; ask the Owner to check

### Spending limits
Your Owner may set per-transaction and daily spending limits. If a payment exceeds these limits, the chain will reject it. When this happens, explain the limit to the user and suggest a smaller amount.

### Config Summary
Your Owner may paste a **Config Summary** block that looks like this:

```
== CardZero Wallet Summary ==
Address: 0xff0A...6F9
Status: Active
Balance: 142.50 USDC
Rules:
  - Per-tx limit: 5.00 USDC
  - Daily limit: 50.00 USDC
  - Frozen: No
Session Keys: 1 active (earliest expiry 2026-03-18)
```

When you receive this, parse it to understand your current spending context. Use the limits to proactively check before attempting a payment that would fail.

## API Reference

Base URL: `${CARDZERO_API_URL}/v1`

---

### 1. Create Wallet

**No authentication required** — this is the first step before you have an API Key.

```
POST /v1/wallets
Content-Type: application/json

{
  "name": "optional display name"
}
```

**Response (201):**
```json
{
  "id": "wallet_7370ee785775",
  "chainAddress": "0xa1f2...70D0",
  "claimKey": "czk_a1b2c3d4e5f6g7h8_i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2",
  "name": "My Agent Wallet",
  "status": "pending"
}
```

**After creating a wallet, you MUST:**
1. Save the `id` as your `CARDZERO_WALLET_ID`
2. Tell the Owner the `claimKey` clearly — this is the only time it's shown
3. Tell the Owner the `chainAddress` so they can send USDC to it
4. Explain: "Go to the CardZero Dashboard, enter this claim key, and set up your username and password to activate the wallet. The key expires in 7 days. After claiming, you'll get an Agent Configuration block — paste it back to me so I can start making payments."

**Example message to Owner:**
> I've created a CardZero wallet for you. Here's what you need to do:
>
> **Wallet address:** `0xa1f2...70D0`
> **Claim key:** `czk_a1b2c3d4e5f6g7h8_i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2`
>
> Go to the CardZero Dashboard and enter this claim key to activate the wallet. The key is valid for 7 days and can only be used once. After claiming, you'll see an **Agent Configuration** block — copy it and paste it back to me so I can start making payments.

---

### 2. Check Balance

**Requires API Key.**

```
GET /v1/wallets/{walletId}/balance
Authorization: Bearer {CARDZERO_API_KEY}
```

**Response (200):**
```json
{
  "walletId": "wallet_7370ee785775",
  "balance": "42.50",
  "currency": "USDC"
}
```

**Errors:**
- `WALLET_NOT_ACTIVE` — Wallet hasn't been claimed yet
- `WALLET_NOT_FOUND` — Invalid walletId
- `INVALID_API_KEY` — API Key is invalid or revoked
- `FORBIDDEN` — API Key is not bound to this wallet

---

### 3. Make Payment

**Requires API Key.** The wallet is automatically determined from your API Key — do NOT include `walletId` in the request body.

```
POST /v1/payments
Content-Type: application/json
Authorization: Bearer {CARDZERO_API_KEY}

{
  "to": "0x1234567890123456789012345678901234567890",
  "amount": "2.50",
  "currency": "USDC",
  "memo": "Payment for API access",
  "idempotencyKey": "unique-key-to-prevent-duplicates"
}
```

**Response (201):**
```json
{
  "paymentId": "pay_abc123def456",
  "status": "confirmed",
  "txHash": "0xabc123...",
  "remainingBalance": "40.00",
  "amount": "2.50",
  "to": "0x1234567890123456789012345678901234567890"
}
```

**Fields:**
- `to` — Recipient Ethereum address (0x-prefixed, 42 characters)
- `amount` — USDC amount as a string (e.g. "2.50")
- `currency` — Must be `"USDC"`
- `memo` — Optional note for the payment
- `idempotencyKey` — Optional; prevents duplicate charges if you retry

**Important:** Do NOT include `walletId` in the request body. Your API Key already identifies which wallet to use.

**Errors:**
- `WALLET_NOT_FOUND` — Invalid walletId
- `WALLET_NOT_ACTIVE` — Wallet hasn't been claimed
- `WALLET_FROZEN` — Owner froze the wallet
- `INSUFFICIENT_BALANCE` — Not enough USDC
- `NO_SESSION_KEY` — Internal signing key unavailable (auto-managed, rarely seen)
- `UNSUPPORTED_CURRENCY` — Only USDC is supported
- `CHAIN_ERROR` — On-chain transaction failed (may include "spend limit exceeded" for tx/daily limits)
- `INVALID_API_KEY` — API Key is invalid or revoked

**After a successful payment**, use `remainingBalance` to track your funds without a separate balance query.

**Fee disclosure:** A 2% service fee is automatically deducted from your wallet on each payment. For example, a $5.00 payment costs $5.10 total ($5.00 to the recipient + $0.10 fee). The fee is handled on-chain — you do not need to calculate or add it manually.

---

### 4. Pay for x402-Protected Resources

**Requires API Key.** Use this when you receive an HTTP `402 Payment Required` response from a service that supports the x402 payment protocol.

```
POST /v1/x402/pay
Content-Type: application/json
Authorization: Bearer {CARDZERO_API_KEY}

{
  "url": "https://api.example.com/premium-data",
  "maxAmount": "1.00",
  "recipient": "0x1234567890123456789012345678901234567890",
  "network": "eip155:8453",
  "asset": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
}
```

**Response (201):**
```json
{
  "paymentId": "pay_abc123def456",
  "txHash": "0xabc123...",
  "paymentHeader": "eyJ0eXBlIjoieDQwMiIs...",
  "type": "x402",
  "amount": "1.00",
  "to": "0x1234...",
  "remainingBalance": "41.00"
}
```

**Fields:**
- `url` — The URL that returned 402 (stored as memo for records)
- `maxAmount` — Maximum USDC amount to pay
- `recipient` — Merchant's Ethereum address (from the 402 response)
- `network` — Chain identifier: `eip155:8453` (Base Mainnet) or `eip155:84532` (Base Sepolia)
- `asset` — USDC contract address (from the 402 response)

**How to use x402:**
1. Make your original HTTP request to the protected resource
2. If you receive a `402 Payment Required` response, extract `recipient`, `maxAmount`, `network`, and `asset` from the response headers/body
3. Call `POST /v1/x402/pay` with those values plus the original `url`
4. Take the `paymentHeader` from the response
5. Retry your original request with the header: `X-PAYMENT: {paymentHeader}`

**Errors:** Same as Make Payment above, plus:
- `UNSUPPORTED_NETWORK` — Network not supported (must be Base)
- `UNSUPPORTED_ASSET` — Only USDC is supported

---

### 5. View Payment History


**Requires API Key.**

```
GET /v1/wallets/{walletId}/payments?limit=10&offset=0
Authorization: Bearer {CARDZERO_API_KEY}
```

**Response (200):**
```json
{
  "payments": [
    {
      "id": "pay_abc123def456",
      "wallet_id": "wallet_7370ee785775",
      "to_address": "0x1234...",
      "amount": "2.50",
      "memo": "Payment for API access",
      "tx_hash": "0xabc123...",
      "status": "confirmed",
      "created_at": 1710000000
    }
  ]
}
```

**Query parameters:**
- `limit` — Number of records (default: 20, max recommended: 50)
- `offset` — Skip N records for pagination

**Payment status values:** `pending`, `confirmed`, `failed`

**Errors:**
- `FORBIDDEN` — API Key is not bound to this wallet

---

### 6. Check Payment Status

**No authentication required** — payment IDs are unguessable.

```
GET /v1/payments/{paymentId}
```

Returns the same shape as a single payment object from the history endpoint.
