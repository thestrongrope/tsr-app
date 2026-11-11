#!/usr/bin/env bash
# Tests of the load tool's guards and of the truth of its report. SYNTHETIC, THROWAWAY targets only.
# Needs: the target connection in TSR_DST_CLIENT (no default, on purpose), a migrated PostgreSQL that holds only synthetic rows
# (for example a throwaway postgres:18 container migrated with the API image's --migrate), and the parity MariaDB with the scratch
# source (tools/parity-php/s2-source.sh). It loads, truncates and re-loads the target; the first thing it does is refuse a target
# that holds a row whose email does not end in .invalid. Prints counts and result lines only.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"
LOAD=tools/data-load/load.sh
GUARD=tools/data-load/test/require-synthetic.sh

fail() { echo "GUARD TEST FAILED: $*" >&2; exit 1; }
ok() { echo "ok - $*"; }

MYSQL_PWD="$(sed -n 's/^PARITY_DB_ROOT_PASSWORD=//p' tools/parity-php/parity.env)"; export MYSQL_PWD
export TSR_SRC_CLIENT="docker exec -i -e MYSQL_PWD tsr-parity-db-1 mariadb -uroot tsr_synth_s2"
[ -n "${TSR_DST_CLIENT:-}" ] || fail "set TSR_DST_CLIENT to a synthetic, throwaway target (no default)"
src() { $TSR_SRC_CLIENT --batch --skip-column-names; }
dst() { $TSR_DST_CLIENT -X -q -At -v ON_ERROR_STOP=1; }
count() { echo "select count(*) from $1" | dst; }
WORK="$(mktemp -d)"
cleanup() {
  echo "drop trigger if exists guard_test on membership.member_profiles; drop trigger if exists guard_test on access.permissions;
        drop function if exists public.guard_test_fail(); delete from identity.users where email = 'guard-test@example.test';" | dst >/dev/null 2>&1 || true
  echo "delete from permissions where name = 'guard.test.reject'" | src >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

# run NAME args...: runs the load with stdin closed; stdout and stderr to $WORK/NAME.out; exit status in RC.
run() { local n="$1"; shift; RC=0; "$LOAD" --report-dir "$WORK/$n" "$@" </dev/null >"$WORK/$n.out" 2>&1 || RC=$?; }
report_of() { ls -t "$WORK/$1"/report-*.txt | head -1; }
need_loaded() { [ "$(count identity.users)" != 0 ] || { run setup; [ "$RC" = 0 ] || fail "setup load failed"; }; }

echo "--- 0. this target must be synthetic"
"$GUARD" >/dev/null || fail "the target is not synthetic; nothing was changed"
DB="$(echo "select current_database()" | dst)"

echo "--- 1. require-synthetic.sh"
( unset TSR_DST_CLIENT; "$GUARD" >"$WORK/g.out" 2>&1 ) && fail "ran without TSR_DST_CLIENT"
grep -q TSR_DST_CLIENT "$WORK/g.out" || fail "the refusal does not name TSR_DST_CLIENT"
echo "insert into identity.users (token, email) values (999999999, 'guard-test@example.test')" | dst
if "$GUARD" >"$WORK/g.out" 2>&1; then fail "accepted a target with a non-.invalid email"; fi
grep -q '1 user' "$WORK/g.out" || fail "the refusal does not give the count"
! grep -q 'example.test' "$WORK/g.out" || fail "the refusal printed an email"
if tools/data-load/test/prove-synthetic.sh >"$WORK/p.out" 2>&1; then fail "prove-synthetic.sh ran on a non-synthetic target"; fi
! grep -q 'build the scratch source' "$WORK/p.out" || fail "prove-synthetic.sh started before refusing"
echo "delete from identity.users where email = 'guard-test@example.test'" | dst
ok "refuses without a target and on a real-looking row; counts only; prove-synthetic.sh refuses first"

echo "--- 2. --truncate needs a confirmation"
need_loaded
before="$(count identity.users)"
run t1 --truncate
[ "$RC" = 1 ] || fail "--truncate without confirmation exited $RC"
[ "$(count identity.users)" = "$before" ] || fail "rows were truncated without a confirmation"
grep -q "database: $DB" "$WORK/t1.out" && grep -q 'rows in the target tables: [1-9]' "$WORK/t1.out" || fail "the refusal does not show the database and the row count"
run t2 --truncate --yes-truncate wrong-name
[ "$RC" = 1 ] || fail "--yes-truncate with a wrong name exited $RC"
[ "$(count identity.users)" = "$before" ] || fail "rows were truncated for a wrong name"
run t3 --truncate --yes-truncate "$DB"
[ "$RC" = 0 ] || fail "--yes-truncate $DB exited $RC"
[ "$(count identity.users)" = "$(echo 'select count(*) from users' | src)" ] || fail "reload after --yes-truncate differs from the source"
ok "no flag and a wrong name refuse and keep the rows; the right name truncates and loads"
need_loaded
if command -v script >/dev/null; then
  RC=0; printf 'not-the-name\n' | script -q /dev/null "$LOAD" --truncate --report-dir "$WORK/t4" >"$WORK/t4.out" 2>&1 || RC=$?
  [ "$(count identity.users)" = "$before" ] || fail "a wrong typed name truncated"
  RC=0; printf '%s\n' "$DB" | script -q /dev/null "$LOAD" --truncate --report-dir "$WORK/t5" >"$WORK/t5.out" 2>&1 || RC=$?
  [ "$(count identity.users)" = "$before" ] || fail "typing the name did not truncate and reload"
  ok "interactive: a wrong typed name refuses, the right one proceeds"
fi

echo "--- 3. source zone in the report"
run z1 --truncate --yes-truncate "$DB"
grep -Eq 'source zone.*UTC.*default' "$WORK/z1.out" || fail "stdout does not say UTC was the default"
grep -Eq 'source zone.*UTC.*default' "$(report_of z1)" || fail "the saved report does not say UTC was the default"
run z2 --truncate --yes-truncate "$DB" --source-tz Asia/Kolkata
grep -Eq 'source zone.*Asia/Kolkata' "$WORK/z2.out" && ! grep -E 'source zone' "$WORK/z2.out" | grep -q default || fail "stdout zone line wrong for an explicit zone"
grep -Eq 'source zone.*Asia/Kolkata' "$(report_of z2)" || fail "the saved report does not name the zone"
ok "the zone is at the top of stdout and of the saved file, with 'default' only when defaulted"

echo "--- 4. a failed domain is named, staging stays, RESULT says incomplete, and the domain can be retried"
echo "create function public.guard_test_fail() returns trigger language plpgsql as \$\$ begin raise sqlstate '57014' using message = 'guard test'; end \$\$;
      create trigger guard_test before insert on membership.member_profiles for each row execute function public.guard_test_fail();" | dst
run f1 --truncate --yes-truncate "$DB"
[ "$RC" = 1 ] || fail "a failed domain exited $RC"
rf="$(report_of f1)"
for f in "$WORK/f1.out" "$rf"; do
  grep -q 'RESULT: LOAD INCOMPLETE' "$f" || fail "no LOAD INCOMPLETE in $(basename "$f")"
  grep 'RESULT' "$f" | grep -q '30-membership' || fail "RESULT does not name the failed domain in $(basename "$f")"
  grep 'RESULT' "$f" | grep -q 'membership.member_profiles' || fail "RESULT does not name member_profiles in $(basename "$f")"
  ! grep -q 'RESULT: every exported row' "$f" || fail "a success RESULT in $(basename "$f")"
done
[ "$(grep -h '^RESULT' "$WORK/f1.out")" = "$(grep -h '^RESULT' "$rf")" ] || fail "stdout and saved RESULT lines differ"
grep -q 'identity.users' <(grep '^RESULT' "$rf") && fail "RESULT names identity.users, which was loaded"
[ "$(echo "select count(*) from pg_namespace where nspname = 'staging'" | dst)" = 1 ] || fail "staging was dropped after a failed domain"
grep -q 'staging' "$WORK/f1.out" && grep -q -- '--retry' "$WORK/f1.out" || fail "no reminder about staging and the retry"
echo "drop trigger guard_test on membership.member_profiles" | dst
run f2 --retry 30-membership
[ "$RC" = 0 ] || fail "the retry exited $RC"
grep -q 'RESULT: every exported row' "$WORK/f2.out" || fail "the retry did not end complete"
[ "$(count membership.member_profiles)" = "$(echo 'select count(*) from users' | src)" ] || fail "member_profiles is not complete after the retry"
[ "$(echo "select count(*) from pg_namespace where nspname = 'staging'" | dst)" = 0 ] || fail "staging was not dropped after a complete retry"
ok "failure named in stdout and file, split target named, staging kept, retry completes"

echo "--- 5. a rejected row in a merge table is rejected, not skipped"
echo "insert into permissions (name, description) values ('guard.test.reject', 'x')" | src
echo "create or replace function public.guard_test_fail() returns trigger language plpgsql as \$\$ begin if new.name = 'guard.test.reject' then raise sqlstate '23514' using message = 'guard test'; end if; return new; end \$\$;
      create trigger guard_test before insert on access.permissions for each row execute function public.guard_test_fail();" | dst
run m1 --truncate --yes-truncate "$DB"
[ "$RC" = 0 ] || fail "a rejected row changed the exit status to $RC"
rf="$(report_of m1)"
grep 'access.permissions ' "$rf" | grep -Eq 'rejected +1 ' || fail "the merge table's report line does not count the rejected row"
for f in "$WORK/m1.out" "$rf"; do grep -q 'RESULT: LOAD INCOMPLETE' "$f" || fail "no LOAD INCOMPLETE for a rejected row in $(basename "$f")"; done
echo "drop trigger guard_test on access.permissions" | dst; echo "delete from permissions where name = 'guard.test.reject'" | src
ok "merge-table rejects are counted as rejected and the RESULT says so"
run end --truncate --yes-truncate "$DB"
[ "$RC" = 0 ] && grep -q 'RESULT: every exported row' "$WORK/end.out" || fail "the clean reload does not end complete"
echo "GUARD TESTS OK"
