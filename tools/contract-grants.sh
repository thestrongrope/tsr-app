#!/usr/bin/env bash
# Run the grants lane's Hurl contract files (the ten /admin/permissions and /admin/class-access routes of access) against one side.
# Usage: tools/contract-grants.sh test|parity [--prepare] [extra hurl args]
#   test    the new API on the synthetic TEST stack (TSR_STACK=n picks lane n: tools/test-stack.sh up); never the dev stack (real data)
#   parity  the PHP API on the parity stack (http://127.0.0.1:18091, tools/parity-php/README.md; synthetic data only), inside the parity lock
#   --prepare  do the preparation below and stop
# Preparation: the synthetic guard (test side), then the fixture pair (db/synthetic/grants-fixtures.sql, tools/parity-php/grants-fixtures.sql: members 925001 to 925084, classes 98501 to 98506,
# rows 9750001 and up; the header says who is who), which first deletes every grant and rule a run created for those tokens, then one token per signed-in fixture member in
# <vars folder>/grants.vars (test) or build/parity-php/grants.vars (parity) as auth_grants_<token>=Bearer ... Files named *-new-api.hurl hold cases PHP gets wrong; they run on the new API only.
# No two files change the same member (Hurl runs files in parallel). Only the tsr-app-test and tsr-parity compose projects are touched. Needs docker, curl, jq, hurl. Prints no secret.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIDE="${1:?usage: contract-grants.sh test|parity [--prepare] [hurl args]}"
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

FILES=(domains/access/spec/tests/admin-permission-*.hurl domains/access/spec/tests/class-access-*.hurl)
TOKENS=(925001 925002 925003 925004 925005 925006 925007 925008 925009 925010 925011 925012 925021 925022 925023 925024
  925041 925042 925043 925044 925045 925046 925047 925048 925049 925050 925051 925052)

parity() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }
php_sql() { parity exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" tsr_synth'; }
test_sql() { docker compose -p "$TSR_TEST_PROJECT" -f docker-compose.dev.yml exec -T db psql -v ON_ERROR_STOP=1 -q -t -A -U tsr -d tsr > /dev/null; }

case "$SIDE" in
  test)
    export TSR_EMULATOR_PORT="$TSR_TEST_EMULATOR_PORT"
    "$ROOT/tools/require-synthetic-stack.sh" "$TSR_TEST_PROJECT"
    test_sql < db/synthetic/grants-fixtures.sql
    MINT="tools/dev-auth/mint-token.sh"
    BASE="$TSR_TEST_BASE_URL"
    VARS="$TSR_TEST_VARS_DIR/grants.vars" ;;
  parity)
    parity_lock
    php_sql < tools/parity-php/grants-fixtures.sql
    KEPT=()
    for f in "${FILES[@]}"; do case "$f" in *-new-api.hurl) ;; *) KEPT+=("$f") ;; esac; done
    FILES=("${KEPT[@]}")
    MINT="tools/parity-php/mint-token.sh"
    BASE="http://127.0.0.1:18091"
    VARS="build/parity-php/grants.vars" ;;
  *) echo "side must be test or parity" >&2; exit 1 ;;
esac

mkdir -p "$(dirname "$VARS")"
umask 077
: > "$VARS"
TMP="$(mktemp)"
trap 'rm -f "$TMP"; parity_unlock' EXIT
for token in "${TOKENS[@]}"; do
  "$MINT" "gr.$token@example.invalid" "$TMP" > /dev/null
  printf 'auth_grants_%s=%s\n' "$token" "$(sed -n 's/^auth_value=//p' "$TMP")" >> "$VARS"
done
echo "grants fixtures loaded on $SIDE; tokens in $VARS"

if [ "$PREPARE_ONLY" = 1 ]; then
  exit 0
fi

hurl --test --variable "base_url=$BASE" --variables-file "$VARS" "$@" "${FILES[@]}"
