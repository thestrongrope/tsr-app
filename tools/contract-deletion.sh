#!/usr/bin/env bash
# Run the "deletion" lane's Hurl contract files (account deletion: domains/identity/spec/tests/deletion-*.hurl, admin-deletion-*.hurl, debug-token.hurl) against one side.
# Usage: tools/contract-deletion.sh test|parity [--prepare] [extra hurl args]
#   test    the new API on the synthetic TEST stack (TSR_STACK=n for lane n: http://localhost:810n; tools/test-stack.sh up); never run against the dev stack (real data)
#   parity  the PHP API on the shared parity stack (http://127.0.0.1:18091, tools/parity-php/README.md; synthetic data only; takes the parity lock)
#   --prepare  do the preparation below and stop
# Preparation: loads ONLY this lane's fixtures (db/synthetic/deletion-fixtures.sql for the new API, tools/parity-php/deletion-fixtures.sql for PHP; header of either), after replacing __BASE__ by a number that changes
# every minute (the completion route's rate limit is per request id and lasts 60 seconds, so a rerun inside a minute must not reuse the ids; the fixtures reset every row of the lane's id block first), signs the
# fixture members in at that side's Auth emulator and writes the variables the files read (auth_deletion_<alias>, deletion_base) to <vars folder>/deletion.vars (new API) or build/parity-php/deletion.vars (PHP).
# Files named *-new-api.hurl run on the new API only (PHP cannot run them, or gets them wrong); files named *-php-only.hurl run on PHP only (the new API's test stack has Firebase in emulator mode, where a completion
# really succeeds, while PHP's parity stack has no service account). Only the tsr-app-test* and tsr-parity compose projects are touched. Needs docker, curl, jq, hurl. Prints no secret.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIDE="${1:?usage: contract-deletion.sh test|parity [--prepare] [hurl args]}"
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

FILES=(domains/identity/spec/tests/deletion-request.hurl domains/identity/spec/tests/deletion-gate.hurl domains/identity/spec/tests/admin-deletion-*.hurl domains/identity/spec/tests/debug-token.hurl)

# alias=email: the fixture members the files sign in as (Hurl variable auth_deletion_<alias>); tokens are in db/synthetic/deletion-fixtures.sql.
MEMBERS=(
  "admin=dl.924001@example.invalid"
  "plain=dl.924002@example.invalid"
  "flow=dl.924003@example.invalid"
  "gate=dl.924005@example.invalid"
  "done=dl.924007@example.invalid"
)

# A number that changes every 2 seconds (cycle of 160 seconds) and stays inside this lane's id block (9740100 to 9740900, steps of 10).
BASE=$((9740100 + (($(date +%s) / 2) % 80) * 10))

parity() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }
php_sql() { sed "s/__BASE__/$BASE/g" "$1" | parity exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" tsr_synth'; }
test_sql() { sed "s/__BASE__/$BASE/g" "$1" | docker compose -p "$TSR_TEST_PROJECT" -f docker-compose.dev.yml exec -T db psql -v ON_ERROR_STOP=1 -q -t -A -U tsr -d tsr > /dev/null; }

KEPT=()
case "$SIDE" in
  test)
    export TSR_EMULATOR_PORT="$TSR_TEST_EMULATOR_PORT"
    "$ROOT/tools/require-synthetic-stack.sh" "$TSR_TEST_PROJECT"
    test_sql db/synthetic/deletion-fixtures.sql
    for f in "${FILES[@]}"; do case "$f" in *-php-only.hurl) ;; *) KEPT+=("$f") ;; esac; done
    MINT="tools/dev-auth/mint-token.sh"
    BASE_URL="$TSR_TEST_BASE_URL"
    VARS="$TSR_TEST_VARS_DIR/deletion.vars" ;;
  parity)
    parity_lock
    php_sql tools/parity-php/deletion-fixtures.sql
    for f in "${FILES[@]}"; do case "$f" in *-new-api.hurl) ;; *) KEPT+=("$f") ;; esac; done
    MINT="tools/parity-php/mint-token.sh"
    BASE_URL="http://127.0.0.1:18091"
    VARS="build/parity-php/deletion.vars" ;;
  *) echo "side must be test or parity" >&2; exit 1 ;;
esac
FILES=("${KEPT[@]}")

mkdir -p "$(dirname "$VARS")"
umask 077
printf "deletion_base=%s\n" "$BASE" > "$VARS"
for n in 0 1 2 3 4 5 6 7 8; do printf "deletion_req_%s=%s\n" "$n" "$((BASE + n))" >> "$VARS"; done
TMP="$(mktemp)"
trap 'rm -f "$TMP"; parity_unlock' EXIT
for entry in "${MEMBERS[@]}"; do
  alias="${entry%%=*}"
  email="${entry#*=}"
  "$MINT" "$email" "$TMP" > /dev/null
  printf 'auth_deletion_%s=%s\n' "$alias" "$(sed -n 's/^auth_value=//p' "$TMP")" >> "$VARS"
done
echo "deletion fixtures loaded on $SIDE (base $BASE); variables in $VARS"

if [ "$PREPARE_ONLY" = 1 ]; then
  exit 0
fi

hurl --test --variable "base_url=$BASE_URL" --variables-file "$VARS" "$@" "${FILES[@]}"
