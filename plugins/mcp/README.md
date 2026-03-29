# CardZero MCP Server

MCP Server for CardZero — gives your AI agent payment capabilities via [Model Context Protocol](https://modelcontextprotocol.io).

**npm:** [`cardzero-mcp`](https://www.npmjs.com/package/cardzero-mcp)

## Prerequisites

You need a CardZero API Key and Wallet ID. Get them from the [CardZero Dashboard](https://cardzero.ai) after claiming a wallet.

## Setup

### Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "cardzero": {
      "command": "npx",
      "args": ["-y", "cardzero-mcp"],
      "env": {
        "CARDZERO_API_KEY": "czapi_...",
        "CARDZERO_WALLET_ID": "wallet_..."
      }
    }
  }
}
```

### Claude Code

```bash
claude mcp add cardzero -- npx -y cardzero-mcp
```

Or add `.mcp.json` to your project:

```json
{
  "mcpServers": {
    "cardzero": {
      "command": "npx",
      "args": ["-y", "cardzero-mcp"],
      "env": {
        "CARDZERO_API_KEY": "czapi_...",
        "CARDZERO_WALLET_ID": "wallet_..."
      }
    }
  }
}
```

### Cursor

Settings > MCP Servers > Add:

- **Name**: cardzero
- **Command**: `npx -y cardzero-mcp`
- **Env**: `CARDZERO_API_KEY`, `CARDZERO_WALLET_ID`

### VS Code

Add to `.vscode/settings.json`:

```json
{
  "mcp": {
    "servers": {
      "cardzero": {
        "command": "npx",
        "args": ["-y", "cardzero-mcp"],
        "env": {
          "CARDZERO_API_KEY": "czapi_...",
          "CARDZERO_WALLET_ID": "wallet_..."
        }
      }
    }
  }
}
```

## Available Tools

| Tool | Description |
|------|-------------|
| `create_wallet` | Create a new wallet. Returns address and claim key for the owner. |
| `get_balance` | Check current USDC balance. |
| `send_payment` | Send USDC to any Ethereum address. 2% fee deducted automatically. |
| `list_payments` | View recent payment history. |
| `pay_x402` | Pay for x402-protected HTTP resources (HTTP 402 paywall). |
| `get_payment` | Check status of a specific payment by ID. |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `CARDZERO_API_KEY` | Yes | Agent API Key (`czapi_...`) |
| `CARDZERO_WALLET_ID` | Yes | Wallet ID (`wallet_...`) |
| `CARDZERO_API_URL` | No | Default: `https://api.cardzero.ai/v1` |
