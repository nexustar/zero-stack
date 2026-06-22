#!/usr/bin/env bash
# One-shot: provision a zero-signup TiDB Cloud Zero database, then deploy the
# full-stack app (static frontend + Worker API) to a temporary Cloudflare
# account. Prints a live URL plus claim links. See README.md for details.
#
# Usage:  ./run.sh [project-name]
# Needs:  Node.js >= 22, npm, curl. If Node < 22, run scripts/setup.sh first.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="${1:-}"

bash "$DIR/scripts/provision-tidb.sh" "$PROJECT"
echo
bash "$DIR/scripts/deploy-worker.sh" "$PROJECT"
