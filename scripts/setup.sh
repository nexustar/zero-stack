#!/usr/bin/env bash
# EXPLICIT, opt-in bootstrap. Running this script IS your consent to install
# toolchain bits. It is NOT part of normal skill use — deploy-worker.sh only
# CHECKS (via preflight.sh) and never mutates your environment.
#
# It will, only as needed:
#   1. ensure Node.js >= 22 (via nvm — installing nvm if absent)
#   2. pre-install the pinned wrangler into the skill dir (so first deploy is fast)
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1) Node >= 22 -------------------------------------------------------------
nv="$(node -v 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)"
if [ -n "$nv" ] && [ "$nv" -ge 22 ]; then
  echo "✓ Node $(node -v) already satisfies >= 22." >&2
else
  echo "Node >= 22 not active. Using nvm (per your stated preference)." >&2
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    echo "Installing nvm into $NVM_DIR ..." >&2
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  fi
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  nvm install 22
  nvm use 22
  echo "✓ Node $(node -v) active in THIS shell. New shells: 'nvm use 22'." >&2
fi

# 2) Pinned wrangler in the skill dir --------------------------------------
if [ ! -x "$SKILL_DIR/node_modules/.bin/wrangler" ]; then
  echo "Installing pinned wrangler into the skill: wrangler@^4.102.0 ..." >&2
  ( cd "$SKILL_DIR"
    [ -f package.json ] || npm init -y >/dev/null 2>&1
    npm i -D 'wrangler@^4.102.0' --no-fund --no-audit --loglevel=error )
fi
echo "✓ wrangler: $("$SKILL_DIR/node_modules/.bin/wrangler" --version 2>/dev/null | tail -1)" >&2
echo "Setup complete. You can now run provision-tidb.sh + deploy-worker.sh." >&2
