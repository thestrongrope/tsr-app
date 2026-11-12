#!/usr/bin/env bash
# Run access's Hurl contract files (domains/access/spec/tests/*.hurl) against one side.
# Usage: tools/access-contract.sh dev|test|parity [extra hurl args]
#   dev     the new API on the dev stack (http://localhost:8088; the fixture members are in db/synthetic/seed.sql)
#   test    the new API on the synthetic TEST stack (http://localhost:8089, or TSR_STACK=n for lane n; tools/test-stack.sh up); never run dev against real data
#   parity  the PHP API on the parity stack (http://127.0.0.1:18091, tools/parity-php/README.md; synthetic data only)
# The fixture members (one per role, a guest, one with named grants) must exist identically on both sides. On the
# parity side this script creates them in PHP's synthetic database, then checks they have NO class relationship at all
# (no class taught, no enrolment, no class_access, no rule): the new API has no classes yet, so a fixture that touches
# a class could never match. The files sign each fixture member in at that side's Auth emulator themselves.
# Only the tsr-app-dev, tsr-app-test and tsr-parity compose projects are touched. Needs docker, curl, jq, hurl. Prints no secret.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIDE="${1:?usage: access-contract.sh dev|test|parity [hurl args]}"
shift || true
cd "$ROOT"
# shellcheck disable=SC1091
. tools/stack-env.sh
# shellcheck disable=SC1091
. tools/parity-lock.sh

FIXTURES="domains/access/spec/tests/fixtures.vars"
FILES=(domains/access/spec/tests/*.hurl)

parity() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }
php_sql() { parity exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" tsr_synth -N -B'; }

parity_fixtures() {
  # PHP's reference seed can lag its migrations; PHP's own idempotent migration brings the catalog level.
  php_sql < "${TSR_PARITY_SRC:-build/parity-php/src}"/migrations/2026_10_22_quiz_reset_permission.sql
  php_sql <<'SQL'
INSERT INTO users (token, email, roleid, provider, createdon)
SELECT v.token, v.email, 0, 'firebase', NOW() FROM (
  SELECT 900101 AS token, 'perm.member@example.invalid' AS email UNION ALL
  SELECT 900102, 'perm.superadmin@example.invalid' UNION ALL
  SELECT 900103, 'perm.gentsadmin@example.invalid' UNION ALL
  SELECT 900104, 'perm.ladiesadmin@example.invalid' UNION ALL
  SELECT 900105, 'perm.coordinator@example.invalid' UNION ALL
  SELECT 900106, 'perm.finance@example.invalid' UNION ALL
  SELECT 900107, 'perm.teacherrole@example.invalid' UNION ALL
  SELECT 900108, 'perm.granted@example.invalid' UNION ALL
  SELECT 0, 'guest@example.invalid') v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.email = v.email);
UPDATE users SET roleid = CASE token WHEN 900102 THEN 1 WHEN 900103 THEN 3 WHEN 900104 THEN 4
  WHEN 900105 THEN 5 WHEN 900106 THEN 7 WHEN 900107 THEN 6 ELSE 0 END
WHERE token BETWEEN 900101 AND 900108;
INSERT INTO user_permissions (user_id, permission, reason, revoked_at)
SELECT u.id, v.permission, 'synthetic fixture', v.revoked_at FROM (
  SELECT 'standard-mcqs:update:all' AS permission, NULL AS revoked_at UNION ALL
  SELECT 'api-docs:read:all', NULL UNION ALL
  SELECT 'summary-report:read:all', '2026-01-01 00:00:00') v
JOIN users u ON u.token = 900108
WHERE NOT EXISTS (SELECT 1 FROM user_permissions g WHERE g.user_id = u.id AND g.permission = v.permission);
SQL
  local touching
  touching="$(php_sql <<'SQL'
SELECT (SELECT COUNT(*) FROM classes WHERE teacher BETWEEN 900101 AND 900108)
     + (SELECT COUNT(*) FROM class_students WHERE token_no BETWEEN 900101 AND 900108)
     + (SELECT COUNT(*) FROM class_access WHERE token BETWEEN 900101 AND 900108)
     + (SELECT COUNT(*) FROM class_access_rules WHERE token BETWEEN 900101 AND 900108);
SQL
)"
  [ "$touching" = "0" ] || { echo "a fixture member touches a class ($touching rows): the contract needs none" >&2; exit 1; }
}

case "$SIDE" in
  dev|test)
    if [ "$SIDE" = test ]; then PROJECT="$TSR_TEST_PROJECT"; PORT="$TSR_TEST_GATEWAY_PORT"; VARS_DIR="$TSR_TEST_VARS_DIR"; export TSR_EMULATOR_PORT="$TSR_TEST_EMULATOR_PORT"
    else PROJECT=tsr-app-dev; PORT=8088; VARS_DIR=build/dev; export TSR_EMULATOR_PORT=19099; fi
    "$ROOT/tools/require-synthetic-stack.sh" "$PROJECT"
    tools/dev-auth/mint-token.sh member.gents@example.invalid "$VARS_DIR"/token.vars
    BASE="http://localhost:$PORT"; VARS="$VARS_DIR/token.vars" ;;
  parity)
    parity_lock
    parity_fixtures
    tools/parity-php/mint-token.sh member.gents@example.invalid build/parity-php/token.vars
    BASE="http://127.0.0.1:18091"; VARS="build/parity-php/token.vars" ;;
  *) echo "side must be dev, test or parity" >&2; exit 1 ;;
esac

hurl --test --variable "base_url=$BASE" --variables-file "$VARS" --variables-file "$FIXTURES" "$@" "${FILES[@]}"
