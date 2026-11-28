#!/usr/bin/env bash
# Builds the S2 data-load SOURCE: a scratch database `tsr_synth_s2` inside the parity stack's synthetic MariaDB.
#   1. copies tsr_synth (the generated synthetic data; the generator builds from the stale schema.sql);
#   2. brings the schema forward: applies the four additive migrations of 2026_11_08 and 2026_11_10 (scheduled notifications, the calendar). Schema task S1 showed the dump equals
#      a full forward replay of tsr-account's migrations except for exactly these two tables. The other migrations are
#      NOT replayed: the data ones (demo cohort, collation and profile-text rewrites) are not safe to run over generated
#      rows (one of them ran for minutes on the 236,000 quiz answers).
#   3. adds the invented rows in s2-fixtures.sql (tokens 960001 and up) and the members the Hurl contract files sign in as
#      (s2-contract-fixtures.sql and membership-fixtures.sql, tokens 900001 and up), so a loaded database can answer them.
# Usage: tools/parity-php/s2-source.sh        (parity db up: tools/parity-php/README.md)
# Only the tsr-parity compose project is touched; the database name is fixed. Prints no secret.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
MIGRATIONS=build/parity-php/src/migrations
# The tables production has and the generated data lacks, each added by one additive migration.
ADDED="2026_11_08_class_scheduled_notifications.sql 2026_11_08_class_scheduled_notification_runs.sql 2026_11_10_class_scheduled_events.sql 2026_11_10_member_event_settings.sql"
DB=tsr_synth_s2

parity() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }
# max_statement_time bounds every statement (seconds). The root password is read inside the container.
sql() { parity exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" --init-command="SET max_statement_time=600" "$@"' sh "$@"; }

for f in $ADDED; do
  [ -f "$MIGRATIONS/$f" ] || { echo "missing $MIGRATIONS/$f (see tools/parity-php/README.md: refresh the PHP source)" >&2; exit 1; }
done

echo "drop database if exists $DB; create database $DB character set utf8mb4 collate utf8mb4_unicode_520_ci;" | sql
parity exec -T db sh -c 'mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" --single-transaction --skip-comments tsr_synth' | sql "$DB"
for f in $ADDED; do
  sql "$DB" < "$MIGRATIONS/$f"
done
sql "$DB" < tools/parity-php/s2-fixtures.sql
sql "$DB" < tools/parity-php/s2-contract-fixtures.sql
sql "$DB" < tools/parity-php/membership-fixtures.sql
echo "select count(*) from users" | sql "$DB" -N -B | sed "s/^/scratch source $DB ready, users: /"
