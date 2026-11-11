#!/usr/bin/env bash
# MariaDB -> PostgreSQL data load (task S2). Run it yourself against the real database; see README.md.
#
# Source and target are reached through two client COMMANDS you give in the environment (so the same script works with
# a host client, `docker exec -i <container> mariadb ...`, or `kubectl exec`). Passwords are NEVER arguments: the mariadb
# client reads MYSQL_PWD and psql reads PGPASSWORD from the environment (with docker exec, pass the NAME: `-e MYSQL_PWD`).
#   TSR_SRC_CLIENT   the mariadb client command, with host, user and database, e.g. "mariadb -h db -u reader tsr"
#   TSR_DST_CLIENT   the psql client command, with host, user and database, e.g. "psql -h localhost -U tsr -d tsr"
# Flags:
#   --truncate       empty the (non-seed) target tables first; without it the load refuses a non-empty target. It first prints the
#                    target (client command, database, row total) and needs a typed confirmation (the database name) or
#                    --yes-truncate <database name>; with no terminal and no --yes-truncate it refuses
#   --yes-truncate DB  the confirmation for --truncate; DB must equal the target's current database name
#   --retry D1,D2    after a run that left "DOMAIN FAILED": load only the failed domains (names as printed, e.g. 30-membership) from the
#                    kept staging schema, then report again. No export, no truncate. Fix the cause first.
#   --keep-staging   keep schema "staging" afterwards (default: dropped)
#   --source-tz ZONE zone of the MariaDB `datetime` columns (a PostgreSQL zone name; default UTC; `timestamp` columns are always UTC)
#   --report-dir DIR where the report file goes (default build/data-load)
# The report (stdout and the saved file) starts with the source zone and ends with RESULT: "LOAD INCOMPLETE" when a domain failed, a target
# table was not loaded or any row was rejected. A failed domain keeps schema staging (it holds source data) so it can be retried.
# Exit status: 0 loaded (rejected rows and orphans are reported in RESULT, not an exit status); 1 refused, or a domain failed, or a table was not loaded.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
TRUNCATE=0; KEEP=0; SOURCE_TZ=UTC; TZ_GIVEN=0; REPORT_DIR="$ROOT/build/data-load"; YES_TRUNCATE=""; RETRY=""

die() { echo "load.sh: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --truncate) TRUNCATE=1 ;;
    --keep-staging) KEEP=1 ;;
    --yes-truncate) [ $# -ge 2 ] || die "--yes-truncate needs the database name"; YES_TRUNCATE="$2"; shift ;;
    --retry) [ $# -ge 2 ] || die "--retry needs a domain name, such as 30-membership"; RETRY="$2"; shift ;;
    --source-tz) [ $# -ge 2 ] || die "--source-tz needs a value"; SOURCE_TZ="$2"; TZ_GIVEN=1; shift ;;
    --report-dir) [ $# -ge 2 ] || die "--report-dir needs a value"; REPORT_DIR="$2"; shift ;;
    -h|--help) sed -n '2,/^set -euo/{/^set -euo/!p;}' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
  shift
done
[ -n "${TSR_SRC_CLIENT:-}" ] || die "set TSR_SRC_CLIENT (the mariadb client command)"
[ -n "${TSR_DST_CLIENT:-}" ] || die "set TSR_DST_CLIENT (the psql client command)"
[[ "$SOURCE_TZ" =~ ^[A-Za-z0-9_/+-]+$ ]] || die "--source-tz must be a zone name such as UTC or Asia/Kolkata"
[ -z "$YES_TRUNCATE" ] || [ "$TRUNCATE" = "1" ] || die "--yes-truncate only goes with --truncate"
[ -z "$RETRY" ] || { [ "$TRUNCATE" = "0" ] && [ -z "$YES_TRUNCATE" ]; } || die "--retry does not truncate: it loads the failed domains into their (rolled back, empty) tables"
[ -z "$RETRY" ] || [[ "$RETRY" =~ ^[0-9a-z,_-]+$ ]] || die "--retry takes domain names such as 30-membership, separated by commas"

IFS=' ' read -r -a SRC <<< "$TSR_SRC_CLIENT"
IFS=' ' read -r -a DST <<< "$TSR_DST_CLIENT"

# Every external call is bounded: connect timeouts, a statement time limit on both sides.
SRC_OPTS=(--connect-timeout=20 --default-character-set=utf8mb4 --batch --skip-column-names --raw
          "--init-command=SET time_zone='+00:00', max_statement_time=3600")
DST_OPTS=(-X -q -v ON_ERROR_STOP=1 -v VERBOSITY=terse)
make_prelude() { PRELUDE="set client_min_messages = warning; set client_encoding = 'UTF8'; set statement_timeout = '60min'; set lock_timeout = '30s'; set staging.source_tz = '$SOURCE_TZ';"; }
make_prelude

src_sql() { "${SRC[@]}" "${SRC_OPTS[@]}"; }                       # SQL on stdin
dst_sql() { { echo "$PRELUDE"; cat; } | PGCONNECT_TIMEOUT=20 "${DST[@]}" "${DST_OPTS[@]}" -f -; }
dst_value() { echo "$1" | PGCONNECT_TIMEOUT=20 "${DST[@]}" "${DST_OPTS[@]}" -At -f -; }

# --- preflight: both clients exist and connect; the target holds the migrated schemas; the zone is known.
echo "select 1" | src_sql >/dev/null || die "cannot run the source client (is the mariadb client there, and MYSQL_PWD set?)"
[ "$(dst_value 'select 1')" = "1" ] || die "cannot run the target client (is psql there, and PGPASSWORD set?)"
[ "$(dst_value "select count(*) from pg_timezone_names where name = '$SOURCE_TZ'")" = "1" ] || die "unknown zone: $SOURCE_TZ"
[ "$(dst_value "select count(*) from pg_namespace where nspname in ('identity','access','membership','platform','content','classes','assessment','notifications')")" = "8" ] \
  || die "the target is not migrated (run the API's --migrate first: eight domain schemas are expected)"

# tables.txt: <source table> <target table> <load|merge>. Sources are exported once; targets are checked and loaded.
TABLES="$HERE/tables.txt"
SOURCES=$(awk '!/^#/ && NF {print $1}' "$TABLES" | sort -u)
STAGING_EXISTS="$(dst_value "select count(*) from pg_namespace where nspname = 'staging'")"
DOMAIN_FILES=("$HERE"/sql/[1-8]*.sql)
TZ_NOTE=""; [ "$TZ_GIVEN" = "1" ] || TZ_NOTE=" (the default: --source-tz was not given)"

# The failed domains live in staging.run_info, so a retry knows what is left to do.
read_failed() { dst_value "select failed_domains from staging.run_info"; }
set_failed() { echo "update staging.run_info set failed_domains = '$1';" | dst_sql >/dev/null; }

confirm_truncate() { # $1 = total rows in the target tables
  local db; db="$(dst_value 'select current_database()')"
  echo "--truncate would empty the target tables:" >&2
  echo "  target client:                $TSR_DST_CLIENT" >&2
  echo "  database: $db" >&2
  echo "  rows in the target tables: $1" >&2
  if [ -n "$YES_TRUNCATE" ]; then
    [ "$YES_TRUNCATE" = "$db" ] || die "--yes-truncate '$YES_TRUNCATE' is not the target's database name; refusing to truncate"
  elif [ -t 0 ]; then
    local typed; read -r -t 120 -p "Type the database name ($db) to truncate, anything else refuses: " typed || typed=""
    [ "$typed" = "$db" ] || die "not confirmed; refusing to truncate"
  else
    die "--truncate needs a confirmation: run it from a terminal, or pass --yes-truncate $db. Refusing to truncate."
  fi
}

if [ -n "$RETRY" ]; then
  [ "$STAGING_EXISTS" = "1" ] || die "--retry needs the staging schema of the failed run (none found: nothing to retry; run the load again)"
  STAGED_TZ="$(dst_value 'select source_tz from staging.run_info')"
  [ -n "$STAGED_TZ" ] || die "staging has no run information; drop it and run the load again"
  [ "$TZ_GIVEN" = "0" ] || [ "$SOURCE_TZ" = "$STAGED_TZ" ] || die "--source-tz $SOURCE_TZ differs from the first run's $STAGED_TZ; a retry must use the same zone"
  SOURCE_TZ="$STAGED_TZ"; TZ_NOTE=" (taken from the first run)"; make_prelude
  FAILED_NOW="$(read_failed)"
  for d in ${RETRY//,/ }; do
    case " ${FAILED_NOW//,/ } " in *" $d "*) ;; *) die "$d did not fail in the first run (failed: ${FAILED_NOW:-none}); nothing to retry" ;; esac
  done
else
  [ "$STAGING_EXISTS" = "0" ] || die "schema staging exists (an earlier run stopped half way, or kept it): drop it ('drop schema staging cascade'), or finish that run with --retry"
  # --- target must be empty (seed tables, mode merge, may hold the migration's rows)
  NONEMPTY=""; TOTAL_ROWS=0
  while read -r _ dst mode; do
    [ "$mode" = "load" ] || continue
    n="$(dst_value "select count(*) from $dst")"
    if [ "$n" != "0" ]; then NONEMPTY="$NONEMPTY $dst($n)"; TOTAL_ROWS=$((TOTAL_ROWS + n)); fi
  done < <(awk '!/^#/ && NF' "$TABLES")
  if [ -n "$NONEMPTY" ]; then
    [ "$TRUNCATE" = "1" ] || die "target tables are not empty:$NONEMPTY . Use --truncate to empty them first."
    confirm_truncate "$TOTAL_ROWS"
    LIST=$(awk '!/^#/ && NF && $3 == "load" {print $2}' "$TABLES" | paste -sd, -)
    echo "truncating the non-seed target tables"
    echo "truncate table $LIST restart identity;" | dst_sql
  fi
fi

mkdir -p "$REPORT_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT="$REPORT_DIR/report-$STAMP.txt"
FAILED=0
KEEP_STAGING="$KEEP"

cleanup() {
  if [ "$KEEP_STAGING" = "0" ]; then echo "drop schema if exists staging cascade;" | dst_sql >/dev/null 2>&1 || echo "load.sh: could not drop schema staging" >&2; fi
}
trap cleanup EXIT

if [ -z "$RETRY" ]; then
  dst_sql < "$HERE/sql/00-engine.sql" >/dev/null
  echo "insert into staging.run_info (source_tz) values ('$SOURCE_TZ');" | dst_sql >/dev/null
  # --- 1 and 2: export every source table as PostgreSQL COPY text and stream it into staging (no file holds row data)
  for t in $SOURCES; do
    [[ "$t" =~ ^[a-z_0-9]+$ ]] || die "bad table name in tables.txt: $t"
    cols="$(printf "select column_name, data_type from information_schema.columns where table_schema = database() and table_name = '%s' order by ordinal_position" "$t" | src_sql)"
    [ -n "$cols" ] || die "source table $t does not exist (is the source migrated up to date?)"
    names=""; defs=""; exprs=""; meta=""
    while IFS=$'\t' read -r name dtype; do
      [[ "$name" =~ ^[A-Za-z0-9_]+$ ]] || die "column name with an unexpected character in $t"
      names="$names${names:+, }\"$name\""
      defs="$defs\"$name\" text, "
      meta="$meta insert into staging.source_columns values ('$t', '$name', '$dtype');"
      if [ "$dtype" = "bit" ]; then v="CAST(\`$name\`+0 AS CHAR)"; else v="CAST(\`$name\` AS CHAR)"; fi
      # COPY text: backslash, tab, newline and carriage return escaped; NULL is \N; an empty string stays empty.
      v="REPLACE(REPLACE(REPLACE(REPLACE($v, CHAR(92), CONCAT(CHAR(92),CHAR(92))), CHAR(9), CONCAT(CHAR(92),'t')), CHAR(10), CONCAT(CHAR(92),'n')), CHAR(13), CONCAT(CHAR(92),'r'))"
      exprs="$exprs${exprs:+, }IFNULL($v, CONCAT(CHAR(92),'N'))"
    done <<< "$cols"
    src_count="$(printf 'select count(*) from `%s`' "$t" | src_sql)"
    [[ "$src_count" =~ ^[0-9]+$ ]] || die "could not count source table $t"
    {
      echo "create table staging.\"$t\" ($defs _rn bigint generated always as identity);$meta"
      echo "insert into staging.source_counts values ('$t', $src_count);"
      echo "\\copy staging.\"$t\" ($names) from stdin"
      printf 'select CONCAT_WS(CHAR(9), %s) from `%s`' "$exprs" "$t" | src_sql
      echo '\.'
    } | dst_sql
    staged="$(dst_value "select count(*) from staging.\"$t\"")"
    [ "$staged" = "$src_count" ] || die "table $t: $src_count rows in the source, $staged staged (was the source being written to?)"
    echo "exported $t: $src_count rows"
  done
fi

# --- 3: transforms, one transaction per domain. A domain that fails is rolled back whole; the others still run.
FAILED_DOMAINS=""
for f in "${DOMAIN_FILES[@]}"; do
  name="$(basename "$f" .sql)"
  if [ -n "$RETRY" ]; then case ",$RETRY," in *",$name,"*) ;; *) continue ;; esac; fi
  if ! dst_sql < "$f" >/dev/null; then
    echo "DOMAIN FAILED (rolled back, none of its rows loaded): $name" >&2
    FAILED_DOMAINS="$FAILED_DOMAINS${FAILED_DOMAINS:+,}$name"
  fi
done
if [ -n "$RETRY" ]; then
  REMAINING=""
  for d in ${FAILED_NOW//,/ }; do case ",$RETRY," in *",$d,"*) ;; *) REMAINING="$REMAINING${REMAINING:+,}$d" ;; esac; done
  FAILED_DOMAINS="$REMAINING${REMAINING:+${FAILED_DOMAINS:+,}}$FAILED_DOMAINS"
fi
set_failed "$FAILED_DOMAINS"

# --- 4: orphans and the report (stdout and a file); counts only. The RESULT line is built here from what really happened.
emit_report() {
  local loaded not_loaded="" n_not=0 rej_rows rej_tables parts="" t
  echo "== Load report $STAMP (UTC)"
  echo "source zone (--source-tz): $SOURCE_TZ$TZ_NOTE"
  dst_sql < "$HERE/sql/95-report.sql"
  loaded="$(dst_value "select target_table from staging.report")"
  while read -r _ t _; do
    grep -Fxq "$t" <<< "$loaded" || { not_loaded="$not_loaded${not_loaded:+ }$t"; n_not=$((n_not + 1)); }
  done < <(awk '!/^#/ && NF' "$TABLES")
  IFS='|' read -r rej_rows rej_tables <<< "$(dst_value "select coalesce(sum(rejected_rows), 0), count(*) filter (where rejected_rows > 0) from staging.report")"
  [ -z "$FAILED_DOMAINS" ] || parts="domains failed (rolled back): $FAILED_DOMAINS"
  [ -z "$not_loaded" ] || parts="$parts${parts:+; }target tables not loaded ($n_not): $not_loaded"
  [ "${rej_rows:-0}" = "0" ] || parts="$parts${parts:+; }rows rejected (not loaded): $rej_rows in $rej_tables table(s)"
  [ "$ORPHANS_FAILED" = "0" ] || parts="$parts${parts:+; }the orphan counts could not be made"
  if [ -n "$parts" ]; then echo "RESULT: LOAD INCOMPLETE: $parts"
  else echo "RESULT: every exported row was loaded (or filtered by design / kept as a seed row)"; fi
  if [ "$KEEP_STAGING" = "1" ]; then
    echo "staging kept: schema staging holds the SOURCE DATA (real member data on a real run). Drop it when done: echo 'drop schema staging cascade' | $TSR_DST_CLIENT"
    [ -z "$FAILED_DOMAINS" ] || echo "retry the failed domain(s) after fixing the cause: load.sh --retry $FAILED_DOMAINS (same client environment; --source-tz is remembered)"
  fi
  [ -z "$FAILED_DOMAINS" ] && [ -z "$not_loaded" ]
}
[ -z "$FAILED_DOMAINS" ] || KEEP_STAGING=1
echo "delete from staging.report_detail where kind = 'orphan';" | dst_sql >/dev/null
ORPHANS_FAILED=0
dst_sql < "$HERE/sql/90-orphans.sql" >/dev/null || { ORPHANS_FAILED=1; FAILED=1; }
emit_report | tee "$REPORT" || FAILED=1
echo "report written to $REPORT"

[ "$FAILED" = "0" ] || exit 1
