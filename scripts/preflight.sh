#!/usr/bin/env bash
# Preflight for zero-stack. CHECK-ONLY — never mutates the environment.
# Exits non-zero with remediation hints if requirements are unmet.
#
# Requirements:
#   - Node.js >= 22   (wrangler's `deploy --temporary` requires it)
#   - npm             (to install wrangler locally, per Cloudflare's recommendation)
#   - curl            (to call the TiDB Cloud Zero API)
set -uo pipefail

ok=1
say() { printf '%s\n' "$*" >&2; }

nv="$(node -v 2>/dev/null | grep -oE '[0-9]+' | head -1)"
if [ -z "$nv" ]; then
  say "✗ Node.js: not found — need >= 22"; ok=0
elif [ "$nv" -lt 22 ]; then
  say "✗ Node.js: $(node -v) — need >= 22 (wrangler --temporary requires it)"; ok=0
else
  say "✓ Node.js: $(node -v)"
fi

if command -v npm >/dev/null; then say "✓ npm: v$(npm -v)"; else
  say "✗ npm: not found — needed to install wrangler"; ok=0; fi

if command -v curl >/dev/null; then say "✓ curl: present"; else
  say "✗ curl: not found — needed to call the TiDB API"; ok=0; fi

if [ "$ok" -ne 1 ]; then
  say ""
  say "To fix Node (this script will NOT change anything for you), use a version manager:"
  say "  • nvm:   nvm install 22 && nvm use 22"
  say "  • fnm:   fnm install 22 && fnm use 22"
  say "  • or run this skill's explicit bootstrap:  bash scripts/setup.sh"
  exit 1
fi
say "Preflight OK."
