#!/usr/bin/env bash
# Run the sign-in contract (domains/identity/spec/tests/link-account.hurl) against one side.
# Usage: tools/identity-contract.sh dev|test|parity [extra hurl args]
#   dev     the new API on the dev stack (http://localhost:8088, docker-compose.dev.yml must be up)
#   test    the new API on the synthetic TEST stack (http://localhost:8089, or TSR_STACK=n for lane n; tools/test-stack.sh up); never run dev against real data
#   parity  the PHP API on the parity stack (http://127.0.0.1:18091, tools/parity-php/README.md; synthetic data only)
# Steps: refresh the synthetic fixtures (the "deleted a moment ago" row is time-bound: 2 hours),
# sign a member in at that side's Auth emulator (mint-token.sh), run Hurl. Needs docker, curl, jq, hurl.
# Only the tsr-app-dev, tsr-app-test and tsr-parity compose projects are touched. Nothing is printed that is a secret.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIDE="${1:?usage: identity-contract.sh dev|test|parity [hurl args]}"
shift || true
cd "$ROOT"
# shellcheck disable=SC1091
. tools/stack-env.sh
# shellcheck disable=SC1091
. tools/parity-lock.sh

FIXTURES="domains/identity/spec/tests/fixtures.vars"
FILE="domains/identity/spec/tests/link-account.hurl"

dev_fixtures() {
  docker compose -p "${PROJECT:-tsr-app-dev}" -f docker-compose.dev.yml exec -T db \
    psql -v ON_ERROR_STOP=1 -q -U tsr -d tsr \
    -c "update identity.account_deletion_requests set completed_at = now() where status = 'completed' and contact_email = 'deleted.recently@example.invalid'"
}

parity() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }

parity_fixtures() {
  parity exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" tsr_synth' <<'SQL'
INSERT INTO users (token, email, roleid, provider, createdon)
SELECT v.token, v.email, 0, 'firebase', NOW() FROM (
  SELECT 900001 AS token, 'member.gents@example.invalid' AS email UNION ALL
  SELECT 0, 'guest@example.invalid' UNION ALL
  SELECT 900011, 'deletion.pending@example.invalid' UNION ALL
  SELECT 900012, 'unverified.target@example.invalid' UNION ALL
  SELECT 900013, 'link.target@example.invalid') v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.email = v.email);
INSERT INTO account_deletion_requests (token, status, source, contact_email, requested_at)
SELECT 900011, 'pending', 'app', 'deletion.pending@example.invalid', UTC_TIMESTAMP() FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM account_deletion_requests WHERE token = 900011);
INSERT INTO account_deletion_requests (token, status, source, contact_email, requested_at, completed_at)
SELECT NULL, 'completed', 'app', 'deleted.recently@example.invalid', UTC_TIMESTAMP(), UTC_TIMESTAMP() FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM account_deletion_requests WHERE status = 'completed' AND contact_email = 'deleted.recently@example.invalid');
UPDATE account_deletion_requests SET completed_at = UTC_TIMESTAMP()
WHERE status = 'completed' AND contact_email = 'deleted.recently@example.invalid';
SQL
}

case "$SIDE" in
  dev|test)
    if [ "$SIDE" = test ]; then PROJECT="$TSR_TEST_PROJECT"; PORT="$TSR_TEST_GATEWAY_PORT"; VARS_DIR="$TSR_TEST_VARS_DIR"; export TSR_EMULATOR_PORT="$TSR_TEST_EMULATOR_PORT"
    else PROJECT=tsr-app-dev; PORT=8088; VARS_DIR=build/dev; export TSR_EMULATOR_PORT=19099; fi
    "$ROOT/tools/require-synthetic-stack.sh" "$PROJECT"
    dev_fixtures
    tools/dev-auth/mint-token.sh member.gents@example.invalid "$VARS_DIR"/token.vars
    BASE="http://localhost:$PORT"; VARS="$VARS_DIR/token.vars" ;;
  parity)
    parity_lock
    parity_fixtures
    tools/parity-php/mint-token.sh member.gents@example.invalid build/parity-php/token.vars
    BASE="http://127.0.0.1:18091"; VARS="build/parity-php/token.vars" ;;
  *) echo "side must be dev, test or parity" >&2; exit 1 ;;
esac

hurl --test --variable "base_url=$BASE" --variables-file "$VARS" --variables-file "$FIXTURES" "$@" "$FILE"
