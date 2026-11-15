#!/usr/bin/env bash
# One request to a lane's API as one synthetic member, for looking at a route by hand and for counting the SQL commands of
# a single request (never during a timed run). Prints the status, the body size and the time; the body goes to
# build/test-n/probe.out. The token is minted at the lane's Auth emulator into build/test-n/probe.vars (git-ignored) and never printed.
# Usage: TSR_STACK=n tools/load/probe.sh <synthetic .invalid email, or - for a public route> <path> [METHOD] [JSON body file]
#   LOAD_COUNT_SQL=1  also print how many "Executed DbCommand" lines the API logged for this request (the API must log
#                     Microsoft.EntityFrameworkCore.Database.Command at Information, which is its default).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
case "${TSR_STACK:-}" in [1-8]) ;; *) echo "probe: set TSR_STACK to a lane, an integer from 1 to 8" >&2; exit 1 ;; esac
# shellcheck disable=SC1091
. tools/stack-env.sh
EMAIL="${1:?usage: probe.sh <email or -> <path> [METHOD] [body file]}"
ROUTE_PATH="${2:?path}"
METHOD="${3:-GET}"
BODY_FILE="${4:-}"
VARS="$TSR_TEST_VARS_DIR/probe.vars"
API="$TSR_TEST_PROJECT-api-1"
ARGS=(-sS --max-time 120 -X "$METHOD" -o "$TSR_TEST_VARS_DIR/probe.out" -w '%{http_code} %{size_download}B %{time_total}s\n')
if [ "$EMAIL" != "-" ]; then
  TSR_EMULATOR_PORT="$TSR_TEST_EMULATOR_PORT" tools/dev-auth/mint-token.sh "$EMAIL" "$VARS" > /dev/null
  ARGS+=(-H "Authorization: $(sed -n 's/^auth_value=//p' "$VARS")")
fi
if [ -n "$BODY_FILE" ]; then ARGS+=(-H 'Content-Type: application/json' --data-binary "@$BODY_FILE"); fi
# docker logs --since has one-second steps here: wait, so an earlier request's lines are not counted.
if [ "${LOAD_COUNT_SQL:-0}" = 1 ]; then sleep 1.2; fi
SINCE="$(date -u +%Y-%m-%dT%H:%M:%S.000000000Z)"
curl "${ARGS[@]}" "$TSR_TEST_BASE_URL$ROUTE_PATH"
if [ "${LOAD_COUNT_SQL:-0}" = 1 ]; then
  sleep 1
  echo "sql commands: $(docker logs --since "$SINCE" "$API" 2>&1 | grep -c 'Executed DbCommand' || true)"
  echo "log lines: $(docker logs --since "$SINCE" "$API" 2>&1 | grep -c -E '^(info|warn|fail|dbug|crit|trce):' || true)"
fi
