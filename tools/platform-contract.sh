#!/usr/bin/env bash
# Run platform's Hurl contract files (domains/platform/spec/tests/*.hurl) against one side.
# Usage: tools/platform-contract.sh dev|test|parity [extra hurl args]
#   dev     the new API on the dev stack (http://localhost:8088; docker-compose.dev.yml must be up)
#   test    the new API on the synthetic TEST stack (http://localhost:8089, or TSR_STACK=n for lane n; tools/test-stack.sh up); never run dev against real data
#   parity  the PHP API on the parity stack (http://127.0.0.1:18091, tools/parity-php/README.md; synthetic data only)
# What it prepares, so both sides answer from the same data:
#   - the geo rows: db/synthetic/geo-fixtures.sql is loaded into that side's database (it REPLACES the three geo
#     tables' content: synthetic dev and parity databases only);
#   - the member: 900002 (member.ladies@example.invalid), created on the parity side if it is missing, then signed
#     in at that side's Auth emulator. The geo files spend about 35 of a member's 60 calls a minute, and PHP keeps
#     its count for the minute, so running one side twice within a minute gets a 429. 900002 is not the member the
#     all-files command in CLAUDE.md uses (900001), so the two do not eat each other's calls.
#   - app_versions.synthetic.json is not loaded here: both stacks mount that one file (docker-compose.dev.yml,
#     tools/parity-php/compose.parity.yml). After editing it, recreate the api container on that side.
# Only the tsr-app-dev, tsr-app-test and tsr-parity compose projects are touched. Needs docker, curl, jq, hurl. Prints no secret.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIDE="${1:?usage: platform-contract.sh dev|test|parity [hurl args]}"
shift || true
cd "$ROOT"
# shellcheck disable=SC1091
. tools/stack-env.sh
# shellcheck disable=SC1091
. tools/parity-lock.sh

FIXTURES="db/synthetic/geo-fixtures.sql"
FILES=()
for f in domains/platform/spec/tests/*.hurl; do
  # A test lane's files read their own variables and run from that lane's script (tools/contract-<lane>.sh).
  grep -qE 'auth_(deletion|edge|grants|notify|quizwrites|reports2|sheets)_' "$f" || FILES+=("$f")
done
MEMBER="member.ladies@example.invalid"

parity() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }
php_sql() { parity exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" tsr_synth'; }

dev_fixtures() {
  { echo "set search_path = platform, public;"; cat "$FIXTURES"; } |
    docker compose -p "${PROJECT:-tsr-app-dev}" -f docker-compose.dev.yml exec -T db psql -v ON_ERROR_STOP=1 -q -U tsr -d tsr
}

parity_fixtures() {
  php_sql < "$FIXTURES"
  php_sql <<'SQL'
INSERT INTO users (token, email, roleid, provider, createdon)
SELECT 900002, 'member.ladies@example.invalid', 0, 'firebase', NOW() FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.email = 'member.ladies@example.invalid');
SQL
}

case "$SIDE" in
  dev|test)
    if [ "$SIDE" = test ]; then PROJECT="$TSR_TEST_PROJECT"; PORT="$TSR_TEST_GATEWAY_PORT"; VARS_DIR="$TSR_TEST_VARS_DIR"; export TSR_EMULATOR_PORT="$TSR_TEST_EMULATOR_PORT"
    else PROJECT=tsr-app-dev; PORT=8088; VARS_DIR=build/dev; export TSR_EMULATOR_PORT=19099; fi
    "$ROOT/tools/require-synthetic-stack.sh" "$PROJECT"
    dev_fixtures
    tools/dev-auth/mint-token.sh "$MEMBER" "$VARS_DIR"/platform.vars
    BASE="http://localhost:$PORT"; VARS="$VARS_DIR/platform.vars" ;;
  parity)
    parity_lock
    parity_fixtures
    tools/parity-php/mint-token.sh "$MEMBER" build/parity-php/platform.vars
    BASE="http://127.0.0.1:18091"; VARS="build/parity-php/platform.vars" ;;
  *) echo "side must be dev, test or parity" >&2; exit 1 ;;
esac

hurl --test --variable "base_url=$BASE" --variables-file "$VARS" "$@" "${FILES[@]}"
