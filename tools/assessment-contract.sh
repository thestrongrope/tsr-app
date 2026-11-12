#!/usr/bin/env bash
# Run assessment's Hurl contract files (domains/assessment/spec/tests/*.hurl) against one side.
# Usage: tools/assessment-contract.sh test|parity [--prepare] [extra hurl args]
#   test    the new API on the synthetic TEST stack (http://localhost:8089, or TSR_STACK=n for lane n; tools/test-stack.sh up); never run against the dev stack (real data)
#   parity  the PHP API on the parity stack (http://127.0.0.1:18091, tools/parity-php/README.md; synthetic data only)
#   --prepare  do the preparation below and stop
# Preparation, so both sides answer from the same data and a file can be run again: loads the A2 fixtures (the manage and copy files: members 902501 to 902513, classes 9631 to 9636, quizzes 963401 and up, standard MCQs A2S-*; header of db/synthetic/assessment-a2-fixtures.sql) after the A1 fixtures (db/synthetic/assessment-a1-fixtures.sql for the new API,
# tools/parity-php/assessment-a1-fixtures.sql for PHP: the same members, classes 9621 to 9624, enrolments, quizzes 962401 to 962499, questions, responses and guardian links),
# signs each fixture member in at that side's Auth emulator and writes build/<side>/assessment.vars (auth_qz_<alias>=Bearer ...). The fixtures are RESET on every run (the submit files write
# answers; the reset deletes them), so a file can be run again. The read files change nothing, and no two files answer the same quiz as the same member (Hurl runs files in parallel).
# Only the tsr-app-test and tsr-parity compose projects are touched. Needs docker, curl, jq, hurl. Prints no secret.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIDE="${1:?usage: assessment-contract.sh test|parity [--prepare] [hurl args]}"
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

FILES=(domains/assessment/spec/tests/*.hurl)

# alias=email: the fixture members the files sign in as (Hurl variable auth_qz_<alias>); tokens are in db/synthetic/assessment-a1-fixtures.sql.
MEMBERS=(
  "qz_reader=qz.902401@example.invalid"
  "qz_fresh=qz.902402@example.invalid"
  "qz_removed=qz.902403@example.invalid"
  "qz_inactive=qz.902404@example.invalid"
  "qz_stranger=qz.902405@example.invalid"
  "qz_teacher=qz.902406@example.invalid"
  "qz_nogender=qz.902407@example.invalid"
  "qz_closed=qz.902408@example.invalid"
  "qz_closed_fresh=qz.902409@example.invalid"
  "qz_parent=qz.902410@example.invalid"
  "qz_parent_revoked=qz.902411@example.invalid"
  "qz_parent_other=qz.902412@example.invalid"
  "qz_parent_removed_child=qz.902413@example.invalid"
  "qz_parent_stranger_child=qz.902414@example.invalid"
  "qz_submit1=qz.902421@example.invalid"
  "qz_submit2=qz.902422@example.invalid"
  "qz_submit3=qz.902423@example.invalid"
  "qz_submit4=qz.902424@example.invalid"
  "qz_submit5=qz.902425@example.invalid"
  "qz_submit6=qz.902426@example.invalid"
  "qz_submit7=qz.902427@example.invalid"
  "qz_submit8=qz.902428@example.invalid"
  "qz_submit9=qz.902429@example.invalid"
  "qm_teacher=qm.902501@example.invalid"
  "qm_admin=qm.902502@example.invalid"
  "qm_student=qm.902503@example.invalid"
  "qm_teacher2=qm.902504@example.invalid"
  "qm_removed_admin=qm.902505@example.invalid"
  "qm_other_admin=qm.902506@example.invalid"
  "qm_super=qm.902507@example.invalid"
  "qm_gents_admin=qm.902508@example.invalid"
  "qm_coord=qm.902509@example.invalid"
  "qm_ladies_admin=qm.902510@example.invalid"
  "qm_nobody=qm.902511@example.invalid"
  "qm_admin2=qm.902512@example.invalid"
  "qm_inactive_admin=qm.902513@example.invalid"
)

parity() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }
php_sql() { parity exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" tsr_synth'; }
test_sql() { docker compose -p "$TSR_TEST_PROJECT" -f docker-compose.dev.yml exec -T db psql -v ON_ERROR_STOP=1 -q -t -A -U tsr -d tsr > /dev/null; }

case "$SIDE" in
  test)
    export TSR_EMULATOR_PORT="$TSR_TEST_EMULATOR_PORT"
    "$ROOT/tools/require-synthetic-stack.sh" "$TSR_TEST_PROJECT"
    test_sql < db/synthetic/assessment-a1-fixtures.sql
    test_sql < db/synthetic/assessment-a2-fixtures.sql
    MINT="tools/dev-auth/mint-token.sh"
    BASE="$TSR_TEST_BASE_URL"
    VARS="$TSR_TEST_VARS_DIR/assessment.vars" ;;
  parity)
    parity_lock
    php_sql < tools/parity-php/assessment-a1-fixtures.sql
    php_sql < tools/parity-php/assessment-a2-fixtures.sql
    # Files named *-new-api.hurl hold cases PHP gets wrong (a PHP bug is not copied); they run on the new API only.
    KEPT=()
    for f in "${FILES[@]}"; do case "$f" in *-new-api.hurl) ;; *) KEPT+=("$f") ;; esac; done
    FILES=("${KEPT[@]}")
    MINT="tools/parity-php/mint-token.sh"
    BASE="http://127.0.0.1:18091"
    VARS="build/parity-php/assessment.vars" ;;
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
echo "assessment fixtures loaded on $SIDE; tokens in $VARS"

if [ "$PREPARE_ONLY" = 1 ]; then
  exit 0
fi

hurl --test --variable "base_url=$BASE" --variables-file "$VARS" "$@" "${FILES[@]}"
