# CardZero Payment Wallet — Claude Code Integration

Add this to your project's `CLAUDE.md` to give Claude Code access to CardZero payments.

## Setup

Set these environment variables (or add to `.env`):

```
CARDZERO_API_URL=https://api.cardzero.ai/v1
CARDZERO_API_KEY=czapi_your_key_here
CARDZERO_WALLET_ID=wallet_your_id_here
```

## CLAUDE.md Snippet

Copy the block below into your project's `CLAUDE.md`:

---

### CardZero Payment Wallet

> **Beta** — Smart contract audit in progress. Recommended wallet balance: < $100 USDC.

You have a CardZero payment wallet on Base. Use it to make USDC payments.

**Config:**
- API URL: `${CARDZERO_API_URL}`
- API Key: `${CARDZERO_API_KEY}`
- Wallet ID: `${CARDZERO_WALLET_ID}`

**Endpoints:**

1. **Check balance:** `GET /wallets/{walletId}/balance` with `Authorization: Bearer {API_KEY}`
2. **Make payment:** `POST /payments` with body `{"to":"0x...","amount":"5.00","currency":"USDC"}` — walletId derived from API Key
3. **Payment history:** `GET /wallets/{walletId}/payments?limit=10` with `Authorization: Bearer {API_KEY}`
4. **x402 payment:** `POST /x402/pay` with body `{"url":"...","maxAmount":"1.00","recipient":"0x...","network":"eip155:8453","asset":"0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"}`

**Rules:**
- Always tell the user the amount, recipient, and reason before paying
- A 2% fee is deducted separately from the wallet
- If `INSUFFICIENT_BALANCE`, suggest the owner add funds
- If `WALLET_FROZEN`, the owner has frozen the wallet
- Use `idempotencyKey` to prevent duplicate payments on retry

**Example — check balance then pay:**
```bash
curl -H "Authorization: Bearer $CARDZERO_API_KEY" $CARDZERO_API_URL/wallets/$CARDZERO_WALLET_ID/balance
curl -X POST -H "Authorization: Bearer $CARDZERO_API_KEY" -H "Content-Type: application/json" \
  -d '{"to":"0xrecipient","amount":"2.50","currency":"USDC"}' \
  $CARDZERO_API_URL/payments
```
