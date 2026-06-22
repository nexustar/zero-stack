# zero-stack

A skill for coding agents (e.g. [Claude Code](https://claude.com/claude-code)) that spins up a full-stack app — frontend + API + SQL database — live on a public URL, with **no signup, no API key, no card**. Point your agent at it to scaffold and deploy a working stack in one shot.

It combines two zero-signup primitives: a MySQL-compatible [TiDB Cloud Zero](https://zero.tidbcloud.com/) database (~30-day life) and a [Cloudflare temporary account](https://developers.cloudflare.com/workers/platform/claim-deployments/) Worker (60-min life). Open it in a browser right away; **claim** to keep it, or let it expire.

> Greenfield scaffold — it generates a fresh Cloudflare Workers app. Not for grafting onto an existing non-Workers backend.

## ⚠️ Before you run

- It creates a **real, public, temporary** database + Worker on TiDB's and Cloudflare's free tiers (not local mocks). Both are **beta** features — the providers may change limits or pull them, so this can break over time.
- **Lifetimes:** Worker/account **60 min**, database **~30 days** — unless claimed (claim links are printed when you run).
- **Security:** `/api/*` is **open by default** and the DB connection string sits in plaintext config. Set `API_TOKEN` for anything beyond a demo. Runtime files (incl. DB credentials) land in the git-ignored `./.zero-stack/`.
- Bash, Linux/macOS only.

## Prerequisites

Node.js ≥ 22, npm, curl. No Cloudflare/TiDB account needed. (No Node 22? `nvm install 22 && nvm use 22`, or run `bash scripts/setup.sh`.)

## Use with a agent (primary)

This repo is a [Claude Code](https://claude.com/claude-code) skill. Install it, then ask your agent to use it:

```bash
cp -r . ~/.claude/skills/zero-stack    # then invoke /zero-stack in Claude Code
```

The agent reads `SKILL.md` and drives the scripts — provisioning the DB, deploying the app, and reporting the live URL + claim links.

## Deploy manually

To run it by hand (or to debug), drive the scripts yourself from the repo root:

```bash
# 1. provision a zero-signup TiDB Cloud Zero database
bash scripts/provision-tidb.sh

# 2. scaffold + deploy the app to a temporary Cloudflare account
bash scripts/deploy-worker.sh          # or: ./run.sh  (chains both steps)
```

You get a live `https://<name>.workers.dev` (a working Notes app) plus two claim URLs —
Cloudflare (≤60 min) and TiDB (≤30 days) — printed in a summary at the end.

Gate the API behind a token by exporting `API_TOKEN` before step 2:

```bash
export API_TOKEN="$(openssl rand -hex 16)"   # then send: Authorization: Bearer $API_TOKEN
```

## Customize

The Notes starter is a neutral demo proving the three layers connect. Make it yours by editing the generated app in `./.zero-stack/app/`:

- `public/index.html` — frontend
- `worker.js` — backend (`/api/*`, queries TiDB via `@tidbcloud/serverless`)
