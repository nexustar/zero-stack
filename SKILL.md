---
name: zero-stack
description: Scaffold and deploy a complete zero-signup full-stack app — static frontend + Worker API + TiDB Cloud Zero database — to a live public URL in one command, with no account, API key, or card. Use when the user wants to spin up a working full-stack starter (frontend + backend + DB) instantly, then customize it. Greenfield only; for existing non-Workers apps it does not apply.
---

# zero-stack

Generate a working full-stack app and deploy it live with **no signup, no API key,
no card** — then the user customizes it and (optionally) claims it to keep it.

Three layers, all zero-signup, one command:

- **Frontend** — static `public/index.html` (a small Notes UI), served by
  Cloudflare's Assets binding.
- **Backend** — a Worker owning `/api/*`, talking to the DB via TiDB's official
  HTTP serverless driver (`@tidbcloud/serverless`: plain HTTP, no TCP, real `?`
  parameter binding).
- **Database** — TiDB Cloud Zero (MySQL-compatible), created via one unauthenticated
  API call.

This is a **scaffold (greenfield)**: it emits a fresh, idiomatic Cloudflare Workers
full-stack app. It is *not* a tool to graft onto an existing arbitrary backend —
the zero-signup deploy only exists on Cloudflare Workers, so non-Workers apps
(Express/Flask/Django/…) can't use it without porting.

## Lifetimes (the one real gotcha)

- **Worker + Cloudflare temp account: 60 minutes** unless claimed.
- **TiDB Zero DB: ~30 days** unless claimed.

The 60-minute window is the weak link. To keep the stack, click **both** Claim URLs
(Worker ≤60 min, DB ≤30 days). Data survives regardless of the Worker.

## Prerequisites

TiDB provisioning is pure HTTP (curl + node). The Cloudflare half is **CLI-only**:
no REST API / SDK / MCP exposes the temporary-account flow (the proof-of-work gate
lives inside Wrangler), so `wrangler` is required. Needed:

- **Node.js ≥ 22** — Wrangler ≥ 4.102.0 (which has `--temporary`) requires it.
- **npm** — installs the pinned wrangler + the app's driver dependency.
- **curl** — for the TiDB API.

`deploy-worker.sh` runs `scripts/preflight.sh` first and **fails fast with guidance
if anything is missing — it never mutates the environment**. Wrangler is not a manual
prereq: the deploy script keeps one **pinned** copy in the *skill dir*
(`~/.claude/skills/zero-stack/node_modules`), reused across runs — not global, not
`npx @latest`, not per-disposable-project. (Cloudflare's "local + pinned" model
adapted to a global tool.)

If Node ≥ 22 is missing, fix it yourself (`nvm install 22 && nvm use 22`, or
fnm/volta/system pkg) **or** run the explicit opt-in bootstrap (running it is your
consent to install nvm + Node 22):

```bash
bash <skill>/scripts/setup.sh
```

## Steps

Run from any scratch dir. Artifacts go in `./.zero-stack/`. Ensure Node ≥ 22 is
active first (see Prerequisites).

1. **Provision the database**:
   ```bash
   bash <skill>/scripts/provision-tidb.sh "<project-name>"
   ```
   `<project-name>` is a short identifier for this deployment (e.g. `my-app`).
   If omitted, defaults apply. Prints TiDB version, `expiresAt`, DB **Claim URL**;
   writes the connection string to `./.zero-stack/tidb.json`. Surface the Claim URL
   to the user.

2. **Deploy the full stack**:
   ```bash
   bash <skill>/scripts/deploy-worker.sh "<project-name>"
   ```
   Runs preflight → ensures skill-local wrangler → writes the app (`worker.js`,
   `public/index.html`, `wrangler.toml`, `package.json`) into `./.zero-stack/app/`
   → installs the driver → `wrangler deploy --temporary`. From wrangler's output,
   capture and report to the user **both**:
   - the **Claim URL** (`https://dash.cloudflare.com/claim-preview?...`) — 60-min window
   - the **workers.dev URL** — the live app
   To gate `/api/*` behind a token, `export API_TOKEN=...` before this step.

3. **Verify** the live app and show the user:
   ```bash
   curl https://<app>.workers.dev/             # frontend HTML
   curl https://<app>.workers.dev/api/notes    # {"notes":[]}
   curl -X POST https://<app>.workers.dev/api/notes \
     -H 'content-type: application/json' -d '{"body":"hello"}'
   curl https://<app>.workers.dev/api/notes    # the note, persisted in TiDB
   ```
   Then point the user at the workers.dev URL in a browser — it's a working app.

## App shape (what the user customizes)

```
.zero-stack/app/
  public/index.html   # frontend UI  → edit for your app
  worker.js           # backend: /api/* + TiDB via @tidbcloud/serverless → add routes
  wrangler.toml       # name, [assets], [vars] (TIDB_URL, API_TOKEN)
```

Backend API (the starter Notes demo):
- `GET /api/notes` — list latest 100
- `POST /api/notes` — `{"body":"..."}` insert (parameter-bound)

Static assets serve everything else; the Worker only handles `/api/*`.

## Notes & caveats

- **TiDB connection string sits in `wrangler.toml [vars]`** (plaintext) — fine for a
  60-min disposable deploy. If kept, claim the account and move it to `wrangler secret`.
- Schema is created lazily (`CREATE TABLE IF NOT EXISTS`) so deploy stays one-command.
- Set `API_TOKEN` before deploy for anything past a quick demo (default is open).
- Endpoints (verified): provisioning `POST https://zero.tidbapi.com/v1beta1/instances`;
  the app's DB driver is `@tidbcloud/serverless@^0.3.0` over HTTP.
