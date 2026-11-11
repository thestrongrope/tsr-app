#!/usr/bin/env bash
# Run classes's Hurl contract files (domains/classes/spec/tests/*.hurl) against one side.
# Usage: tools/classes-contract.sh test|parity [--prepare] [extra hurl args]
#   test    the new API on the synthetic TEST stack (http://localhost:8089; tools/test-stack.sh up); never run against the dev stack (real data)
#   parity  the PHP API on the parity stack (http://127.0.0.1:18091, tools/parity-php/README.md; synthetic data only)
#   --prepare  do the preparation below and stop
# Preparation, so both sides answer from the same data and a file can be run again: loads the classes fixtures (db/synthetic/classes-fixtures.sql for the new API,
# tools/parity-php/classes-fixtures.sql for PHP: the same members, classes, enrolments, sessions, guardian links, guides and syllabus), signs
# each fixture member in at that side's Auth emulator and writes build/<side>/classes.vars (auth_<alias>=Bearer ...). The read slices do not change the fixtures; the write
# files change only the rows of the WRITE fixtures (db/synthetic/classes-write-fixtures.sql and tools/parity-php/classes-write-fixtures.sql, tokens 9003xx/9004xx, classes 94xx and every class
# created by the write admin), the BULK-ADD fixtures (classes-bulk-fixtures.sql, tokens 9007xx, classes 9451 and up; they first delete the members a bulk add created) and the ENROLMENT fixtures (classes-enrol-fixtures.sql beside them, tokens 9005xx, classes 9411 and up), which are RESET on every run, so a
# file can be run again and files can run in parallel.
# Only the tsr-app-test and tsr-parity compose projects are touched. Needs docker, curl, jq, hurl. Prints no secret.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIDE="${1:?usage: classes-contract.sh test|parity [--prepare] [hurl args]}"
shift || true
cd "$ROOT"

PREPARE_ONLY=0
if [ "${1:-}" = "--prepare" ]; then
  PREPARE_ONLY=1
  shift
fi

FILES=(domains/classes/spec/tests/*.hurl)

# alias=email: the fixture members the files sign in as (Hurl variable auth_<alias>); tokens are in db/synthetic/classes-fixtures.sql.
MEMBERS=(
  "teacher_g=cls.teacher.gents@example.invalid"
  "teacher_l=cls.teacher.ladies@example.invalid"
  "student_g=cls.student.gents@example.invalid"
  "student_l=cls.student.ladies@example.invalid"
  "outsider=cls.outsider@example.invalid"
  "nogender=cls.nogender@example.invalid"
  "admin=cls.admin@example.invalid"
  "removed=cls.removed@example.invalid"
  "parent=cls.parent@example.invalid"
  "wr_admin=wr.admin@example.invalid"
  "wr_teacher1=wr.teacher.one@example.invalid"
  "wr_teacher2=wr.teacher.two@example.invalid"
  "wr_teacher3=wr.teacher.three@example.invalid"
  "wr_student1=wr.student.one@example.invalid"
  "en_gadmin=en.900501@example.invalid"
  "en_ladmin=en.900502@example.invalid"
  "en_teacher=en.900511@example.invalid"
  "en_lteacher=en.900512@example.invalid"
  "en_student=en.900521@example.invalid"
  "en_j_free=en.900561@example.invalid"
  "en_j_ladies=en.900562@example.invalid"
  "en_j_in=en.900563@example.invalid"
  "en_j_removed=en.900564@example.invalid"
  "en_j_left=en.900565@example.invalid"
  "en_j_nogender=en.900566@example.invalid"
  "bk_adm_a=bk.900701@example.invalid"
  "bk_adm_b=bk.900702@example.invalid"
  "bk_adm_c=bk.900703@example.invalid"
  "bk_adm_d=bk.900704@example.invalid"
  "bk_ladm_e=bk.900705@example.invalid"
  "bk_adm_f=bk.900706@example.invalid"
  "bk_teacher=bk.900711@example.invalid"
  "bk_student=bk.900721@example.invalid"
)

parity() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }
php_sql() { parity exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" tsr_synth'; }
test_sql() { docker compose -p tsr-app-test -f docker-compose.dev.yml exec -T db psql -v ON_ERROR_STOP=1 -q -t -A -U tsr -d tsr > /dev/null; }

case "$SIDE" in
  test)
    export TSR_EMULATOR_PORT=19100
    "$ROOT/tools/require-synthetic-stack.sh" tsr-app-test
    test_sql < db/synthetic/classes-bulk-cleanup.sql
    test_sql < db/synthetic/classes-fixtures.sql
    test_sql < db/synthetic/classes-write-fixtures.sql
    test_sql < db/synthetic/classes-enrol-fixtures.sql
    test_sql < db/synthetic/classes-b2c-fixtures.sql
    test_sql < db/synthetic/classes-bulk-fixtures.sql
    MINT="tools/dev-auth/mint-token.sh"
    BASE="http://localhost:8089"
    VARS="build/test/classes.vars" ;;
  parity)
    php_sql < tools/parity-php/classes-bulk-cleanup.sql
    php_sql < tools/parity-php/classes-fixtures.sql
    php_sql < tools/parity-php/classes-write-fixtures.sql
    php_sql < tools/parity-php/classes-enrol-fixtures.sql
    php_sql < tools/parity-php/classes-b2c-fixtures.sql
    php_sql < tools/parity-php/classes-bulk-fixtures.sql
    # Files named *-new-api.hurl hold cases PHP gets wrong (a PHP bug is not copied); they run on the new API only.
    KEPT=()
    for f in "${FILES[@]}"; do case "$f" in *-new-api.hurl) ;; *) KEPT+=("$f") ;; esac; done
    FILES=("${KEPT[@]}")
    MINT="tools/parity-php/mint-token.sh"
    BASE="http://127.0.0.1:18091"
    VARS="build/parity-php/classes.vars" ;;
  *) echo "side must be test or parity" >&2; exit 1 ;;
esac

mkdir -p "$(dirname "$VARS")"
umask 077
: > "$VARS"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
for entry in "${MEMBERS[@]}"; do
  alias="${entry%%=*}"
  email="${entry#*=}"
  "$MINT" "$email" "$TMP" > /dev/null
  printf 'auth_%s=%s\n' "$alias" "$(sed -n 's/^auth_value=//p' "$TMP")" >> "$VARS"
done
echo "classes fixtures loaded on $SIDE; tokens in $VARS"

if [ "$PREPARE_ONLY" = 1 ]; then
  exit 0
fi

hurl --test --variable "base_url=$BASE" --variables-file "$VARS" "$@" "${FILES[@]}"
