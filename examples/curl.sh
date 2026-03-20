#!/usr/bin/env bash
# CardZero API — curl examples
# Base URL: https://api.cardzero.ai/v1
#
# Prerequisites:
#   export CARDZERO_API_KEY="czapi_your_key_here"
#   export CARDZERO_WALLET_ID="wallet_your_id_here"

API="https://api.cardzero.ai/v1"

# ─── 1. Create a wallet (no auth required) ──────────────────────────────────

curl -s -X POST "$API/wallets" \
  -H "Content-Type: application/json" \
  -d '{"name": "my-agent-wallet"}' | jq .

# Response includes: id, chainAddress, claimKey, status
# Give the claimKey to the wallet owner so they can claim it at https://cardzero.ai

# ─── 2. Check balance ───────────────────────────────────────────────────────

curl -s "$API/wallets/$CARDZERO_WALLET_ID/balance" \
  -H "Authorization: Bearer $CARDZERO_API_KEY" | jq .

# ─── 3. Make a payment ──────────────────────────────────────────────────────

curl -s -X POST "$API/payments" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CARDZERO_API_KEY" \
  -d '{
    "to": "0x1234567890123456789012345678901234567890",
    "amount": "2.50",
    "currency": "USDC",
    "memo": "Payment for API access",
    "idempotencyKey": "unique-key-123"
  }' | jq .

# ─── 4. View payment history ────────────────────────────────────────────────

curl -s "$API/wallets/$CARDZERO_WALLET_ID/payments?limit=10" \
  -H "Authorization: Bearer $CARDZERO_API_KEY" | jq .

# ─── 5. Check payment status (no auth required) ─────────────────────────────

curl -s "$API/payments/pay_abc123def456" | jq .
