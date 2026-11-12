#!/usr/bin/env bash
# Run the reports2 lane's Hurl contract files (MCQ summary, MCQ adherence, Quran leaderboard, pending nudge) against one side.
# Usage: tools/contract-reports2.sh test|parity [--prepare] [extra hurl args]
#   test    the new API on the synthetic TEST stack (TSR_STACK=n: tools/test-stack.sh up); never the dev stack (real data)
#   parity  the PHP API on the shared parity stack (http://127.0.0.1:18091); takes the parity lock; loads only this lane's rows
#   --prepare  load the fixtures, mint the tokens and stop
# Loads db/synthetic/reports2-fixtures.sql (new API) or tools/parity-php/reports2-fixtures.sql (PHP): tokens 921001 to 921999, classes 98101 to 98107, rows 9710000 to 9719999, all dates in 2019.
# The fixtures are RESET on every run (the nudge writes notifications and inbox rows; the reset deletes them so the 24 hour rule starts clean). Tokens go to <vars folder>/reports2.vars (auth_r2_<alias>=Bearer ...).
# The *-new-api.hurl files (every real send, and cases PHP gets wrong) run on the new API only: PHP sends a real push when a nudge is sent, so the parity side never sends.
# Only the tsr-app-test-<n> and tsr-parity compose projects are touched. Needs docker, curl, jq, hurl. Prints no secret.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIDE="${1:?usage: contract-reports2.sh test|parity [--prepare] [hurl args]}"
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

FILES=(domains/classes/spec/tests/report-mcq-*.hurl domains/classes/spec/tests/report-quran-leaderboard*.hurl domains/classes/spec/tests/report-pending-nudge*.hurl)

MEMBERS=(
  "r2_super=r2.921001@example.invalid"
  "r2_gadmin=r2.921002@example.invalid"
  "r2_ladmin=r2.921003@example.invalid"
  "r2_coord=r2.921004@example.invalid"
  "r2_one=r2.921005@example.invalid"
  "r2_nobody=r2.921006@example.invalid"
  "r2_named=r2.921007@example.invalid"
  "r2_grant=r2.921008@example.invalid"
)

parity() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }
php_sql() { parity exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" tsr_synth'; }
test_sql() { docker compose -p "$TSR_TEST_PROJECT" -f docker-compose.dev.yml exec -T db psql -v ON_ERROR_STOP=1 -q -t -A -U tsr -d tsr > /dev/null; }

case "$SIDE" in
  test)
    export TSR_EMULATOR_PORT="$TSR_TEST_EMULATOR_PORT"
    "$ROOT/tools/require-synthetic-stack.sh" "$TSR_TEST_PROJECT"
    test_sql < db/synthetic/reports2-fixtures.sql
    MINT="tools/dev-auth/mint-token.sh"
    BASE="$TSR_TEST_BASE_URL"
    VARS="$TSR_TEST_VARS_DIR/reports2.vars" ;;
  parity)
    parity_lock
    php_sql < tools/parity-php/reports2-fixtures.sql
    KEPT=()
    for f in "${FILES[@]}"; do case "$f" in *-new-api.hurl) ;; *) KEPT+=("$f") ;; esac; done
    FILES=("${KEPT[@]}")
    MINT="tools/parity-php/mint-token.sh"
    BASE="http://127.0.0.1:18091"
    VARS="build/parity-php/reports2.vars" ;;
  *) echo "side must be test or parity" >&2; exit 1 ;;
esac

mkdir -p "$(dirname "$VARS")"
umask 077
: > "$VARS"
TMP="$(mktemp)"
trap 'rm -f "$TMP"; parity_unlock' EXIT
for entry in "${MEMBERS[@]}"; do
  alias="${entry%%=*}"
  email="${entry#*=}"
  "$MINT" "$email" "$TMP" > /dev/null
  printf 'auth_%s=%s\n' "$alias" "$(sed -n 's/^auth_value=//p' "$TMP")" >> "$VARS"
done
echo "reports2 fixtures loaded on $SIDE; tokens in $VARS"

if [ "$PREPARE_ONLY" = 1 ]; then
  exit 0
fi

hurl --test --variable "base_url=$BASE" --variables-file "$VARS" "$@" "${FILES[@]}"
