#!/usr/bin/env bash
# Load the membership fixtures (tools/parity-php/membership-fixtures.sql) into the PHP parity stack's synthetic MariaDB, then
# check that no fixture member touches a class: the new API has no classes yet, so a fixture that did (an enrolment would
# lock a gender in PHP) could never match. The same rows are in db/synthetic/seed.sql for the new API's dev stack.
# Usage: tools/parity-php/membership-fixtures.sh        (parity stack up: tools/parity-php/README.md)
# Only the tsr-parity compose project is touched. Needs docker. Prints no secret.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

parity() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }
php_sql() { parity exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" tsr_synth -N -B'; }

php_sql < tools/parity-php/membership-fixtures.sql

touching="$(php_sql <<'SQL'
SELECT (SELECT COUNT(*) FROM classes WHERE teacher BETWEEN 900201 AND 900299)
     + (SELECT COUNT(*) FROM class_students WHERE token_no BETWEEN 900201 AND 900299)
     + (SELECT COUNT(*) FROM class_access WHERE token BETWEEN 900201 AND 900299)
     + (SELECT COUNT(*) FROM class_access_rules WHERE token BETWEEN 900201 AND 900299);
SQL
)"
[ "$touching" = "0" ] || { echo "a membership fixture touches a class ($touching rows): the contract needs none" >&2; exit 1; }
echo "membership fixtures loaded on the parity stack"
