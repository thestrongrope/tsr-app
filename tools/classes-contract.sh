#!/usr/bin/env bash
# Run classes's Hurl contract files (domains/classes/spec/tests/*.hurl) against one side.
# Usage: tools/classes-contract.sh test|parity [--prepare] [extra hurl args]
#   test    the new API on the synthetic TEST stack (http://localhost:8089, or TSR_STACK=n for lane n; tools/test-stack.sh up); never run against the dev stack (real data)
#   parity  the PHP API on the parity stack (http://127.0.0.1:18091, tools/parity-php/README.md; synthetic data only)
#   --prepare  do the preparation below and stop
# Preparation, so both sides answer from the same data and a file can be run again: loads the classes fixtures (db/synthetic/classes-fixtures.sql for the new API,
# tools/parity-php/classes-fixtures.sql for PHP: the same members, classes, enrolments, sessions, guardian links, guides and syllabus), signs
# each fixture member in at that side's Auth emulator and writes build/<side>/classes.vars (auth_<alias>=Bearer ...). The read slices do not change the fixtures; the write
# files change only the rows of the WRITE fixtures (db/synthetic/classes-write-fixtures.sql and tools/parity-php/classes-write-fixtures.sql, tokens 9003xx/9004xx, classes 94xx and every class
# created by the write admin), the BULK-ADD fixtures (classes-bulk-fixtures.sql, tokens 9007xx, classes 9451 and up; they first delete the members a bulk add created) and the ENROLMENT fixtures (classes-enrol-fixtures.sql beside them, tokens 9005xx, classes 9411 and up), which are RESET on every run, so a
# file can be run again and files can run in parallel.
# The CONDUCTION fixtures (classes-conduction-fixtures.sql, tokens 9008xx, classes 9471 and up, sessions 947101 and up) are reset the same way, run-created sessions included.
# The B4a fixtures (classes-b4a-fixtures.sql, tokens 9009xx and 9010xx, classes 9511 to 9559, syllabus 9501 to 9599) are loaded and reset the same way, for the 15 /admin files.
# The B5a REPORT fixtures (classes-b5a-fixtures.sql, tokens 9014xx, classes 9581 to 9589, sessions 958101 and up, fixed dates in November 2025) are loaded last and reset the same way, for the report files.
# The B5c REPORT fixtures (classes-b5c-fixtures.sql, tokens 9019xx, classes 9564 to 9568, language 9, fixed dates in October and November 2025, the coordinator rc_coord) are loaded last and reset the same way, for pending, TSR and students.
# Only the tsr-app-test and tsr-parity compose projects are touched. Needs docker, curl, jq, hurl. Prints no secret.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIDE="${1:?usage: classes-contract.sh test|parity [--prepare] [hurl args]}"
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

FILES=()
for f in domains/classes/spec/tests/*.hurl; do
  # The MCQ report, leaderboard and nudge files belong to tools/contract-reports2.sh (their own fixtures and variables).
  case "$f" in */report-mcq-*|*/report-quran-leaderboard*|*/report-pending-nudge*) ;; *) FILES+=("$f") ;; esac
done

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
  "cd_teacher=cd.900801@example.invalid"
  "cd_teacher2=cd.900802@example.invalid"
  "cd_lteacher=cd.900803@example.invalid"
  "cd_teacher4=cd.900804@example.invalid"
  "cd_student=cd.900811@example.invalid"
  "cd_student2=cd.900821@example.invalid"
  "cd_outsider=cd.900826@example.invalid"
  "b4_syl=b4.900901@example.invalid"
  "b4_read=b4.900902@example.invalid"
  "b4_save=b4.900903@example.invalid"
  "b4_look_a=b4.900904@example.invalid"
  "b4_look_b=b4.900905@example.invalid"
  "b4_enrol_a=b4.900906@example.invalid"
  "b4_enrol_b=b4.900907@example.invalid"
  "b4_enrol_c=b4.900908@example.invalid"
  "b4_enrol_d=b4.900909@example.invalid"
  "rp_coord=rp.901401@example.invalid"
  "rb_coord=rb.901501@example.invalid"
  "rc_coord=rc.901901@example.invalid"
)

parity() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }
php_sql() { parity exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" tsr_synth'; }
test_sql() { docker compose -p "$TSR_TEST_PROJECT" -f docker-compose.dev.yml exec -T db psql -v ON_ERROR_STOP=1 -q -t -A -U tsr -d tsr > /dev/null; }

case "$SIDE" in
  test)
    export TSR_EMULATOR_PORT="$TSR_TEST_EMULATOR_PORT"
    "$ROOT/tools/require-synthetic-stack.sh" "$TSR_TEST_PROJECT"
    test_sql < db/synthetic/classes-bulk-cleanup.sql
    test_sql < db/synthetic/classes-fixtures.sql
    test_sql < db/synthetic/classes-write-fixtures.sql
    test_sql < db/synthetic/classes-enrol-fixtures.sql
    test_sql < db/synthetic/classes-b2c-fixtures.sql
    test_sql < db/synthetic/classes-bulk-fixtures.sql
    test_sql < db/synthetic/classes-conduction-fixtures.sql
    test_sql < db/synthetic/classes-b4a-fixtures.sql
    test_sql < db/synthetic/classes-b5a-fixtures.sql
    test_sql < db/synthetic/classes-b5b-fixtures.sql
    test_sql < db/synthetic/classes-b5c-fixtures.sql
    MINT="tools/dev-auth/mint-token.sh"
    BASE="$TSR_TEST_BASE_URL"
    VARS="$TSR_TEST_VARS_DIR/classes.vars" ;;
  parity)
    parity_lock
    php_sql < tools/parity-php/classes-bulk-cleanup.sql
    php_sql < tools/parity-php/classes-fixtures.sql
    php_sql < tools/parity-php/classes-write-fixtures.sql
    php_sql < tools/parity-php/classes-enrol-fixtures.sql
    php_sql < tools/parity-php/classes-b2c-fixtures.sql
    php_sql < tools/parity-php/classes-bulk-fixtures.sql
    php_sql < tools/parity-php/classes-conduction-fixtures.sql
    php_sql < tools/parity-php/classes-b4a-fixtures.sql
    php_sql < tools/parity-php/classes-b5a-fixtures.sql
    php_sql < tools/parity-php/classes-b5b-fixtures.sql
    php_sql < tools/parity-php/classes-b5c-fixtures.sql
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
trap 'rm -f "$TMP"; parity_unlock' EXIT
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
