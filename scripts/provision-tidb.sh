#!/usr/bin/env bash
# Provision a zero-signup TiDB Cloud Zero database and emit its credentials.
# No account, no API key, no card. The instance auto-expires in ~30 days
# unless claimed via the printed claimUrl.
#
# Usage:   provision-tidb.sh [project-name] [out.json]
# Writes:  the instance JSON to <out.json> (default: ./.zero-stack/tidb.json)
# Deps:    curl, node   (no jq required)
set -euo pipefail

PROJECT="${1:-}"
TAG="zero-stack${PROJECT:+/$PROJECT}"
OUT="${2:-.zero-stack/tidb.json}"
command -v node >/dev/null || { echo "need: node" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"

resp="$(curl -fsS -X POST https://zero.tidbapi.com/v1beta1/instances \
  -H 'Content-Type: application/json' \
  -d "{\"tag\":\"${TAG}\"}")"

# Extract .instance into $OUT, then read fields back — all via node.
printf '%s' "$resp" | node -e '
  const d = JSON.parse(require("fs").readFileSync(0, "utf8"));
  process.stdout.write(JSON.stringify(d.instance, null, 2));
' > "$OUT"

read -r host user pass exp claim < <(node -e '
  const i = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  const c = i.connection;
  process.stdout.write([c.host, c.username, c.password, i.expiresAt, i.claimInfo.claimUrl].join(" ") + "\n");
' "$OUT")

# Smoke-test the HTTP SQL API so we fail loudly here, not inside the Worker.
auth="$(printf '%s:%s' "$user" "$pass" | base64 | tr -d '\n')"
ver="$(curl -fsS -X POST "https://http-${host}/v1beta/sql" \
  -H "Authorization: Basic ${auth}" -H 'Content-Type: application/json' \
  -H 'TiDB-Database: test' -d '{"query":"SELECT VERSION() AS v"}' \
  | node -e 'const d=JSON.parse(require("fs").readFileSync(0,"utf8"));process.stdout.write(String(d.rows?.[0]?.[0]??"?"))')"

echo "TiDB Cloud Zero ready:" >&2
echo "  version:   $ver"   >&2
echo "  host:      $host"  >&2
echo "  expiresAt: $exp"   >&2
echo "  claimUrl:  $claim" >&2
echo "  creds ->   $OUT"   >&2
