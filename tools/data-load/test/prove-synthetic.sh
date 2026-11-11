#!/usr/bin/env bash
# S2 proof on SYNTHETIC data only. DESTRUCTIVE: it drops schema staging, truncates and reloads the target.
# The target is NEVER a default: give it in TSR_DST_CLIENT (a psql client command), and it must be a throwaway, migrated,
# synthetic PostgreSQL (for example a postgres:18 container migrated with the API image's --migrate; no seed needed). It
# refuses to start unless the target has no identity.users row whose email does not end in .invalid, bulk-add placeholders of synthetic tokens aside (test/require-synthetic.sh).
# The local dev database may hold real member data: never point this at it.
# Needs: the parity stack's db up (tools/parity-php/README.md).
# It builds the scratch source (tools/parity-php/s2-source.sh), loads it, and checks counts, values, the refusal and the
# truncate, the source zone parameter, the reject path, and orphan counts against the source. Prints no secret and no row value.
# The source is fixed (the parity stack's scratch database); the target comes from the caller, with no default.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"
tools/data-load/test/require-synthetic.sh

# Local-only placeholder of the throwaway parity stack (parity.env); the target's password comes from the caller's PGPASSWORD.
MYSQL_PWD="$(sed -n 's/^PARITY_DB_ROOT_PASSWORD=//p' tools/parity-php/parity.env)"; export MYSQL_PWD
export TSR_SRC_CLIENT="docker exec -i -e MYSQL_PWD tsr-parity-db-1 mariadb -uroot tsr_synth_s2"
export TSR_DST_CLIENT
src() { $TSR_SRC_CLIENT --batch --skip-column-names "$@"; }
dst() { $TSR_DST_CLIENT -X -q -At -v ON_ERROR_STOP=1 "$@"; }
fail() { echo "PROOF FAILED: $*" >&2; exit 1; }
drop_staging() { echo "set client_min_messages = warning; drop schema if exists staging cascade" | dst >/dev/null; }

echo "--- build the scratch source"
tools/parity-php/s2-source.sh

echo "--- 1. load into the empty migrated database, keeping staging for the assertions"
drop_staging
# PROVE_TRUNCATE=1 only to repeat the proof on a database that an earlier run filled; the real proof starts empty.
DB="$(echo "select current_database()" | dst)"
tools/data-load/load.sh --keep-staging ${PROVE_TRUNCATE:+--truncate --yes-truncate "$DB"}

echo "--- 2. counts: every table's loaded count equals its source count"
bad=0
while read -r s t mode; do
  if [ "$s" = "users" ] && [ "$t" = "access.user_roles" ]; then want="$(echo "select count(*) from users where roleid <> 0" | src)"
  else want="$(echo "select count(*) from \`$s\`" | src)"; fi
  got="$(echo "select count(*) from $t" | dst)"
  if [ "$mode" = "merge" ]; then ok=$([ "$got" -ge "$want" ] && echo yes || echo no); else ok=$([ "$got" = "$want" ] && echo yes || echo no); fi
  printf '%-56s source %9s  target %9s  %s\n' "$t" "$want" "$got" "$([ $ok = yes ] && echo OK || echo MISMATCH)"
  [ $ok = yes ] || bad=$((bad+1))
done < <(awk '!/^#/ && NF' tools/data-load/tables.txt)
[ "$bad" = 0 ] || fail "$bad table(s) differ"

echo "--- 3. values per type class, and the reject path"
dst -f - < tools/data-load/test/assert.sql 2>&1 | sed 's/^psql:[^ ]* //' 
dst -f - < tools/data-load/test/reject.sql 2>&1 | sed 's/^psql:[^ ]* //'

echo "--- 4. orphan counts equal on both sides"
check_orphans() { # child table, column, parent table, parent column, target-side reason prefix
  want="$(echo "select count(*) from \`$1\` c where c.\`$2\` is not null and not exists (select 1 from \`$3\` p where p.\`$4\` = c.\`$2\`)" | src)"
  got="$(echo "select row_count from staging.report_detail where kind = 'orphan' and target_table = '$5' and reason = '$2 -> $6'" | dst)"
  printf '%-40s %-12s source %6s  report %6s\n' "$1" "$2" "$want" "$got"
  [ "$want" = "$got" ] || fail "orphan count differs for $1.$2"
}
check_orphans class_students class_id classes id classes.class_students classes.classes.id
check_orphans class_students token_no users token classes.class_students identity.users.token
check_orphans user_devices token users token notifications.user_devices identity.users.token
check_orphans class_attendance session_id class_sessions id classes.class_attendance classes.class_sessions.id
check_orphans spot_quiz_responses token users token assessment.spot_quiz_responses identity.users.token

echo "--- 5. a second run refuses a non-empty target"
drop_staging
if tools/data-load/load.sh >/dev/null 2>&1; then fail "the load ran into a non-empty target"; fi
dst -c "select 'refused as expected; staging schema left behind: ' || count(*) from pg_namespace where nspname = 'staging'"

echo "--- 6. --truncate with --source-tz Asia/Kolkata; staging is dropped at the end"
tools/data-load/load.sh --truncate --yes-truncate "$DB" --source-tz Asia/Kolkata >/dev/null
[ "$(dst -c "select count(*) from pg_namespace where nspname = 'staging'")" = "0" ] || fail "staging was not dropped"
dst -f - < tools/data-load/test/assert-tz.sql 2>&1 | sed 's/^psql:[^ ]* //'

echo "--- 7. final state: --truncate again, UTC, same assertions"
tools/data-load/load.sh --truncate --yes-truncate "$DB" --keep-staging >/dev/null
dst -f - < tools/data-load/test/assert.sql 2>&1 | sed 's/^psql:[^ ]* //' | tail -3
drop_staging
echo "PROOF OK"
