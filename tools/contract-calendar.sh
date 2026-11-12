#!/usr/bin/env bash
# Run the calendar Hurl contract files (domains/notifications/spec/tests/calendar-*.hurl) against one side.
# Usage: tools/contract-calendar.sh test|parity [--prepare] [extra hurl args]
#   test    the new API on the synthetic TEST stack (TSR_STACK=n picks lane n: http://localhost:810n; tools/test-stack.sh up); never the dev stack (real data)
#   parity  the PHP API on the parity stack (http://127.0.0.1:18091, tools/parity-php/README.md; synthetic data only), inside the parity lock
#   --prepare  do the preparation below and stop
# Preparation: loads db/synthetic/calendar-fixtures.sql (new API) or tools/parity-php/calendar-fixtures.sql (PHP): members 928001 to 928099, classes 9701 to 9709, other rows 9280000 to 9289999
# (header of the file). It first deletes the rows it owns by explicit id lists (including the events and settings an earlier run created), so the files can be run again. Then it signs each
# fixture member in at that side's Auth emulator and writes <vars folder>/calendar.vars (new API) or build/parity-php/calendar.vars (PHP) with auth_cal_<alias>=Bearer ...
# The files that write (create, update, delete, settings) each use a class and a member of their own, so Hurl may run them in parallel; each must start from the reset fixture, so run the
# files through this script. Files named *-new-api.hurl run on the new API only (none today).
# Only the tsr-app-test-<n> and tsr-parity compose projects are touched. Needs docker, curl, jq, hurl. Prints no secret.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIDE="${1:?usage: contract-calendar.sh test|parity [--prepare] [hurl args]}"
shift || true
cd "$ROOT"
# shellcheck disable=SC1091
. tools/stack-env.sh
# shellcheck disable=SC1091
. tools/parity-lock.sh

PREPARE_ONLY=0
if [ "${1:-}" = "--prepare" ]; then
  PREPARE_ONLY=1
  shift
fi

FILES=(domains/notifications/spec/tests/calendar-*.hurl)

# alias=token: the fixture members the files sign in as (Hurl variable auth_cal_<alias>); emails are cal.<token>@example.invalid.
MEMBERS=(
  "member=928001" "super=928002"
  "teacher1=928011" "teacher2=928012" "teacher3=928013" "teacher4=928014" "teacher5=928015" "teacher6=928016"
  "reader=928021" "syncer=928022" "student1=928023"
)

parity() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }
php_sql() { parity exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" tsr_synth'; }
test_sql() { docker compose -p "$TSR_TEST_PROJECT" -f docker-compose.dev.yml exec -T db psql -v ON_ERROR_STOP=1 -q -t -A -U tsr -d tsr > /dev/null; }

case "$SIDE" in
  test)
    export TSR_EMULATOR_PORT="$TSR_TEST_EMULATOR_PORT"
    "$ROOT/tools/require-synthetic-stack.sh" "$TSR_TEST_PROJECT"
    test_sql < db/synthetic/calendar-fixtures.sql
    MINT="tools/dev-auth/mint-token.sh"
    BASE="$TSR_TEST_BASE_URL"
    VARS="$TSR_TEST_VARS_DIR/calendar.vars" ;;
  parity)
    parity_lock
    php_sql < tools/parity-php/calendar-fixtures.sql
    KEPT=()
    for f in "${FILES[@]}"; do case "$f" in *-new-api.hurl) ;; *) KEPT+=("$f") ;; esac; done
    FILES=("${KEPT[@]}")
    MINT="tools/parity-php/mint-token.sh"
    BASE="http://127.0.0.1:18091"
    VARS="build/parity-php/calendar.vars" ;;
  *) echo "side must be test or parity" >&2; exit 1 ;;
esac

mkdir -p "$(dirname "$VARS")"
umask 077
: > "$VARS"
TMP="$(mktemp)"
trap 'rm -f "$TMP"; parity_unlock' EXIT
for entry in "${MEMBERS[@]}"; do
  alias="${entry%%=*}"
  token="${entry#*=}"
  "$MINT" "cal.${token}@example.invalid" "$TMP" > /dev/null
  printf 'auth_cal_%s=%s\n' "$alias" "$(sed -n 's/^auth_value=//p' "$TMP")" >> "$VARS"
done
echo "calendar fixtures loaded on $SIDE; tokens in $VARS"

if [ "$PREPARE_ONLY" = 1 ]; then
  exit 0
fi

hurl --test --variable "base_url=$BASE" --variables-file "$VARS" "$@" "${FILES[@]}"
