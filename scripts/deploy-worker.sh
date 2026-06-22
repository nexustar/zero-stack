#!/usr/bin/env bash
# Deploy the zero-stack scaffold (static frontend + Worker API + TiDB Zero) to a
# zero-signup, temporary Cloudflare account (`wrangler deploy --temporary`).
# Account + deployment live 60 minutes unless claimed via the printed Claim URL.
#
# Cloudflare exposes no REST API / SDK / MCP for the temporary-account flow (the
# proof-of-work gate lives inside the CLI), so wrangler is required. We keep ONE
# pinned wrangler in the SKILL dir and reuse it across runs.
#
# Usage:  deploy-worker.sh [project-name] [tidb.json] [workdir]
set -euo pipefail

PROJECT="${1:-}"
TIDB_JSON="${2:-.zero-stack/tidb.json}"
WORKDIR="${3:-.zero-stack/app}"
WORKER_NAME="zero-stack${PROJECT:+-$PROJECT}"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1) Preflight — fail fast with guidance, no environment mutation.
bash "$SKILL_DIR/scripts/preflight.sh" || exit 1

[ -f "$TIDB_JSON" ] || { echo "missing $TIDB_JSON — run provision-tidb.sh first" >&2; exit 1; }
connstr="$(node -e 'const i=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.stdout.write(i.connectionString||"")' "$TIDB_JSON")"
[ -n "$connstr" ] || { echo "no connectionString in $TIDB_JSON" >&2; exit 1; }
dbclaim="$(node -e 'const i=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.stdout.write((i.claimInfo&&i.claimInfo.claimUrl)||"")' "$TIDB_JSON")"
token="${API_TOKEN:-}"   # optional bearer gate; export API_TOKEN to enable

# 2) Ensure a pinned wrangler in the SKILL dir (one-time, reused across runs).
WR="$SKILL_DIR/node_modules/.bin/wrangler"
if [ ! -x "$WR" ]; then
  echo "Installing pinned wrangler into the skill (one-time): wrangler@^4.102.0" >&2
  ( cd "$SKILL_DIR"
    [ -f package.json ] || npm init -y >/dev/null 2>&1
    npm i -D 'wrangler@^4.102.0' --no-fund --no-audit --loglevel=error )
fi

# 3) Materialize the app project from the template (skip files that already exist
#    so re-deploys don't clobber user customizations).
mkdir -p "$WORKDIR/public"
[ -f "$WORKDIR/worker.js" ]         || cp "$SKILL_DIR/template/worker.js" "$WORKDIR/worker.js"
[ -f "$WORKDIR/public/index.html" ] || cp "$SKILL_DIR/template/public/index.html" "$WORKDIR/public/index.html"

cat > "$WORKDIR/package.json" <<EOF
{ "name": "${WORKER_NAME}", "private": true, "type": "module",
  "dependencies": { "@tidbcloud/serverless": "^0.3.0" } }
EOF

# creds live in [vars] (plaintext) — fine for a 60-min disposable deploy.
cat > "$WORKDIR/wrangler.toml" <<EOF
name = "${WORKER_NAME}"
main = "worker.js"
compatibility_date = "2026-06-01"

[assets]
directory = "./public"

[vars]
TIDB_URL = "${connstr}"
API_TOKEN = "${token}"
EOF

# 4) Install the worker's runtime dep (bundled by wrangler) and deploy.
cd "$WORKDIR"
echo "Installing app dependency (@tidbcloud/serverless)..." >&2
npm i --no-fund --no-audit --loglevel=error
echo "Deploying full stack to a temporary Cloudflare account..." >&2

# Capture wrangler output (still shown live via tee) so we can surface the URLs —
# wrangler buries the claim link mid-output where it's easy to miss.
out="$(mktemp)"; trap 'rm -f "$out"' EXIT
WRANGLER_SEND_METRICS=false "$WR" deploy --temporary 2>&1 | tee "$out"

live="$(grep -oE 'https://[A-Za-z0-9.-]+\.workers\.dev' "$out" | head -1 || true)"
cfclaim="$(grep -oE 'https://dash\.cloudflare\.com/claim-preview\?[^[:space:]]+' "$out" | head -1 || true)"

{
  echo
  echo "─────────────────────────────────────────────────────────────"
  echo "  Live app:                     ${live:-<see wrangler output above>}"
  echo "  Claim Cloudflare (<=60 min):  ${cfclaim:-<see wrangler output above>}"
  echo "  Claim database  (<=30 days):  ${dbclaim:-<in $TIDB_JSON>}"
  echo "─────────────────────────────────────────────────────────────"
} >&2
