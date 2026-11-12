#!/usr/bin/env bash
# Run the quizwrites lane's Hurl contract files against one side: the eight assessment routes that create, copy, score, enter offline, print and publish a class's quizzes.
# Usage: tools/contract-quizwrites.sh test|parity [--prepare] [extra hurl args]
#   test    the new API on the synthetic TEST stack (TSR_STACK=n: gateway 810n; unset: 8089); tools/test-stack.sh up first; never the dev stack (real data)
#   parity  the PHP API on the parity stack (http://127.0.0.1:18091; synthetic data only; inside the parity lock)
#   --prepare  load the fixtures, mint the tokens and stop
# Preparation (every run, so a file can be run again): loads ONLY this lane's fixtures (db/synthetic/quizwrites-fixtures.sql or tools/parity-php/quizwrites-fixtures.sql: members 922001 to 922021,
# classes 98201 to 98205, ids 9720000 and up; the load first deletes everything of the classes 98200 to 98299, the quizzes a run created included, and the notifications of tokens 922000 to 922999),
# signs the fixture members in at that side's Auth emulator and writes <vars folder>/quizwrites.vars (test) or build/parity-php/quizwrites.vars (parity) with auth_quizwrites_<alias>=Bearer ...
# Files named *-new-api.hurl hold what only the new API does (a PHP bug is not copied, PHP cannot run it) and run on the new API only. Needs docker, curl, jq, hurl. Prints no secret.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIDE="${1:?usage: contract-quizwrites.sh test|parity [--prepare] [hurl args]}"
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

FILES=(domains/assessment/spec/tests/manage-create.hurl domains/assessment/spec/tests/manage-standard-copy.hurl domains/assessment/spec/tests/manage-copy.hurl domains/assessment/spec/tests/manage-scores.hurl
  domains/assessment/spec/tests/manage-offline.hurl domains/assessment/spec/tests/manage-offline-save.hurl domains/assessment/spec/tests/manage-sheet.hurl domains/assessment/spec/tests/manage-publish.hurl)
for extra in domains/assessment/spec/tests/manage-*-new-api.hurl; do
  case "$extra" in
    domains/assessment/spec/tests/manage-update-new-api.hurl) ;;
    *) [ -e "$extra" ] && FILES+=("$extra") ;;
  esac
done

# alias=email: the fixture members the files sign in as (Hurl variable auth_quizwrites_<alias>); who is who: the header of db/synthetic/quizwrites-fixtures.sql.
MEMBERS=(
  "teacher=qw.922001@example.invalid"
  "admin=qw.922002@example.invalid"
  "student=qw.922003@example.invalid"
  "other_teacher=qw.922004@example.invalid"
  "removed_admin=qw.922005@example.invalid"
  "other_student=qw.922006@example.invalid"
  "super=qw.922007@example.invalid"
  "gents_admin=qw.922008@example.invalid"
  "ladies_admin=qw.922009@example.invalid"
  "nobody=qw.922010@example.invalid"
  "phone_student=qw.922012@example.invalid"
  "s13=qw.922013@example.invalid"
  "s14=qw.922014@example.invalid"
  "other_admin=qw.922017@example.invalid"
)

parity() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }
php_sql() { parity exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" tsr_synth'; }
test_sql() { docker compose -p "$TSR_TEST_PROJECT" -f docker-compose.dev.yml exec -T db psql -v ON_ERROR_STOP=1 -q -t -A -U tsr -d tsr > /dev/null; }

case "$SIDE" in
  test)
    export TSR_EMULATOR_PORT="$TSR_TEST_EMULATOR_PORT"
    "$ROOT/tools/require-synthetic-stack.sh" "$TSR_TEST_PROJECT"
    test_sql < db/synthetic/quizwrites-fixtures.sql
    MINT="tools/dev-auth/mint-token.sh"
    BASE="$TSR_TEST_BASE_URL"
    VARS="$TSR_TEST_VARS_DIR/quizwrites.vars" ;;
  parity)
    parity_lock
    php_sql < tools/parity-php/quizwrites-fixtures.sql
    KEPT=()
    for f in "${FILES[@]}"; do case "$f" in *-new-api.hurl) ;; *) KEPT+=("$f") ;; esac; done
    FILES=("${KEPT[@]}")
    MINT="tools/parity-php/mint-token.sh"
    BASE="http://127.0.0.1:18091"
    VARS="build/parity-php/quizwrites.vars" ;;
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
  printf 'auth_quizwrites_%s=%s\n' "$alias" "$(sed -n 's/^auth_value=//p' "$TMP")" >> "$VARS"
done
echo "quizwrites fixtures loaded on $SIDE; tokens in $VARS"

if [ "$PREPARE_ONLY" = 1 ]; then
  exit 0
fi

hurl --test --variable "base_url=$BASE" --variables-file "$VARS" "$@" "${FILES[@]}"
