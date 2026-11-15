#!/usr/bin/env bash
# Proves the contract-script guard without touching dev: on the TEST stack it must pass on the synthetic database, pass with the placeholder a bulk add gives a member it creates
# (<own token>@thestrongrope.com on a token of 900000 or above), and refuse while any other non-synthetic-looking user row exists (each added and removed here, one at a time), writing nothing else.
# Needs tools/test-stack.sh up.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck disable=SC1091
. tools/stack-env.sh
sql() { docker compose -p "$TSR_TEST_PROJECT" -f docker-compose.dev.yml exec -T db psql -U tsr -d tsr -X -q -v ON_ERROR_STOP=1 -c "$1"; }
guard() { tools/require-synthetic-stack.sh "$TSR_TEST_PROJECT" 2>/dev/null; }
PROBE_TOKEN=""
cleanup() { [ -z "$PROBE_TOKEN" ] || sql "delete from identity.users where token = $PROBE_TOKEN"; }
trap cleanup EXIT

# probe <token> <email> pass|refuse: one row, the guard's answer, the row removed.
probe() {
  PROBE_TOKEN="$1"
  sql "insert into identity.users (token, email) values ($1, '$2')"
  if guard; then answer=pass; else answer=refuse; fi
  cleanup
  PROBE_TOKEN=""
  [ "$answer" = "$3" ] || { echo "FAIL: guard did ${answer} for token $1 with that address, expected $3" >&2; exit 1; }
}

tools/require-synthetic-stack.sh "$TSR_TEST_PROJECT"
probe 900990 "900990@thestrongrope.com" pass
probe 999999 "guard.probe@real-looking.example" refuse
probe 899999 "899999@thestrongrope.com" refuse
probe 900991 "900992@thestrongrope.com" refuse
probe 900993 "900993@thestrongrope.com.example" refuse
probe 900994 "900994@THESTRONGROPE.COM" refuse
echo "guard ok: passes on synthetic and on a bulk-add placeholder; refuses a low token, another token's placeholder and any other non-.invalid address"
