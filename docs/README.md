# CardZero docs (Mintlify)

This directory contains the CardZero documentation site, authored in MDX
and rendered by [Mintlify](https://mintlify.com).

## Structure

```
docs/
├── mint.json              # Mintlify config (navigation, theme, OpenAPI link)
├── introduction.mdx       # Landing page
├── overview/              # What is CardZero, architecture, comparisons
├── concepts/              # Wallet, Jobs, Reputation, Identity, x402
├── getting-started/       # Quickstart, MCP, Claude Code, claim flow
├── api-reference/         # Per-endpoint reference
├── recipes/               # End-to-end recipes
├── reference/             # Error codes, rate limits, contract addresses, changelog
├── images/                # Logos + assets
└── README.md              # This file
```

## Local preview

```bash
npm i -g mintlify
cd public/docs
mintlify dev
# Opens http://localhost:3000
```

## Deploy (one-time setup)

1. **Sign up** at [mintlify.com](https://mintlify.com) (free tier; paid for
   advanced features like custom analytics).
2. **Connect** the `mrocker/CardZero` GitHub repo.
3. **Set root**: `public/docs` (not the repo root — Mintlify needs the
   `mint.json` location).
4. **Add custom domain**: `docs.cardzero.ai`. Configure CNAME in Cloudflare:
   - `docs.cardzero.ai` → `cname.mintlify.com` (Mintlify provides exact target).
5. **SSL**: Mintlify provisions automatically.

After connection, every push to `main` auto-deploys.

## Editing docs

- Edit any `.mdx` file. Mintlify supports standard MDX + their custom components
  (Card, CardGroup, Tabs, Tab, Note, Warning, AccordionGroup, Accordion,
  ParamField, ResponseField).
- Update `mint.json` to add new pages to navigation.
- Push to `main`. Wait ~30s for redeploy.

## Style guide

- **One H1 per file** (Mintlify uses front-matter `title:` as H1).
- **Code blocks** specify language: ```` ```typescript ```` not ```` ``` ````.
- **External links** use absolute URLs.
- **Internal links** use absolute paths from docs root: `/concepts/wallet`,
  not relative.
- **Examples should be runnable**. Test before committing.

## Updating after API changes

When endpoints change:

1. Update relevant `api-reference/*.mdx` page.
2. Update `openapi.yaml` in repo root (Mintlify reads it for
   auto-generated reference if linked in `mint.json`).
3. Update `recipes/*.mdx` if any examples are affected.
4. Add an entry to `reference/changelog.mdx`.
5. Push.

## When NOT to modify

- The introduction's CardGroup links — they're load-bearing for nav.
- mint.json structure unless you understand Mintlify config.
- Contract addresses in `reference/contract-addresses.mdx` — those are
  immutable on-chain.
