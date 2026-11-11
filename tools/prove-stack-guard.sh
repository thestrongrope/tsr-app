#!/usr/bin/env bash
# Proves the contract-script guard without touching dev: on the TEST stack it must pass, then refuse while one
# non-synthetic-looking user row exists (added and removed here), writing nothing else. Needs tools/test-stack.sh up.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
sql() { docker compose -p tsr-app-test -f docker-compose.dev.yml exec -T db psql -U tsr -d tsr -X -q -v ON_ERROR_STOP=1 -c "$1"; }
tools/require-synthetic-stack.sh tsr-app-test
sql "insert into identity.users (token, email) values (999999, 'guard.probe@real-looking.example')"
trap 'sql "delete from identity.users where token = 999999"' EXIT
if tools/require-synthetic-stack.sh tsr-app-test 2>/dev/null; then echo "FAIL: guard passed on a non-synthetic row" >&2; exit 1; fi
echo "guard ok: passes on synthetic, refuses on a non-synthetic row"
