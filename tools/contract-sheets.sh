#!/usr/bin/env bash
# Run the lane-sheets Hurl contract files (the standard MCQ update and the quiz competition admin: standard-mcq-*.hurl and admin-quiz*.hurl in domains/assessment/spec/tests) against one side.
# Usage: tools/contract-sheets.sh test|parity [--prepare] [extra hurl args]
#   test    the new API on the synthetic TEST stack (TSR_STACK=n picks lane n; tools/test-stack.sh up); never the dev stack (real data)
#   parity  the PHP API on the parity stack (http://127.0.0.1:18091; synthetic data only; set TSR_PARITY_SRC=<tsr-app>/build/parity-php/src for PHP's quiz_reset migration)
#   --prepare  load the fixtures, mint the tokens and stop
# Loads ONLY this lane's members (tokens 923001 to 923008: db/synthetic/sheets-fixtures.sql, tools/parity-php/sheets-fixtures.sql) and writes <vars folder>/sheets.vars (auth_sheets_<alias>=Bearer ...).
# Neither side has Google credentials and no request goes to Google: PHP answers "not configured" from its own code and the new API likewise.
# Hurl runs files in parallel and the advisory locks are global: every case that reaches a lock sits in ONE file per lock (standard-mcq-update.hurl: 5001; admin-quiz-locked.hurl: 5002);
# the other files only test refusals that happen before any lock.
# quiz-info-new-api.hurl (GET /quiz/info, public) runs on its own after the batch (a request tries lock 5002).
# Files named *-new-api.hurl hold what only the new API answers; they run on the new API only. Needs docker, curl, jq, hurl. Prints no secret.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIDE="${1:?usage: contract-sheets.sh test|parity [--prepare] [hurl args]}"
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

FILES=(domains/assessment/spec/tests/standard-mcq-*.hurl domains/assessment/spec/tests/admin-quiz*.hurl)

MEMBERS=(
  "plain=sh.923001@example.invalid"
  "super=sh.923002@example.invalid"
  "gents=sh.923003@example.invalid"
  "mcq=sh.923004@example.invalid"
  "quiz=sh.923005@example.invalid"
  "quizreset=sh.923006@example.invalid"
  "reset=sh.923007@example.invalid"
  "revoked=sh.923008@example.invalid"
)

parity() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }
php_sql() { parity exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" tsr_synth'; }
test_sql() { docker compose -p "$TSR_TEST_PROJECT" -f docker-compose.dev.yml exec -T db psql -v ON_ERROR_STOP=1 -q -t -A -U tsr -d tsr > /dev/null; }

case "$SIDE" in
  test)
    export TSR_EMULATOR_PORT="$TSR_TEST_EMULATOR_PORT"
    "$ROOT/tools/require-synthetic-stack.sh" "$TSR_TEST_PROJECT"
    test_sql < db/synthetic/sheets-fixtures.sql
    MINT="tools/dev-auth/mint-token.sh"
    BASE="$TSR_TEST_BASE_URL"
    VARS="$TSR_TEST_VARS_DIR/sheets.vars" ;;
  parity)
    parity_lock
    # PHP's reference seed can lag its migrations; PHP's own idempotent migration brings the catalog level (quiz:reset:all).
    php_sql < "${TSR_PARITY_SRC:-build/parity-php/src}"/migrations/2026_10_22_quiz_reset_permission.sql
    php_sql < tools/parity-php/sheets-fixtures.sql
    KEPT=()
    for f in "${FILES[@]}"; do case "$f" in *-new-api.hurl) ;; *) KEPT+=("$f") ;; esac; done
    FILES=("${KEPT[@]}")
    MINT="tools/parity-php/mint-token.sh"
    BASE="http://127.0.0.1:18091"
    VARS="build/parity-php/sheets.vars" ;;
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
  printf 'auth_sheets_%s=%s\n' "$alias" "$(sed -n 's/^auth_value=//p' "$TMP")" >> "$VARS"
done
echo "sheets fixtures loaded on $SIDE; tokens in $VARS"

if [ "$PREPARE_ONLY" = 1 ]; then
  exit 0
fi

hurl --test --variable "base_url=$BASE" --variables-file "$VARS" "$@" "${FILES[@]}"
# GET /quiz/info tries the quiz admin lock for a request, so its file (new API only) runs alone, after the parallel batch.
if [ "$SIDE" = test ]; then
  hurl --test --variable "base_url=$BASE" --variables-file "$VARS" "$@" domains/assessment/spec/tests/quiz-info-new-api.hurl
fi
