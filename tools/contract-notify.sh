#!/usr/bin/env bash
# Run the notify lane's Hurl contract files (domains/notifications/spec/tests/notify-*.hurl) against one side.
# Usage: tools/contract-notify.sh test|parity [--prepare] [extra hurl args]
#   test    the new API on the synthetic TEST stack (TSR_STACK=n picks lane n: http://localhost:810n; tools/test-stack.sh up); never the dev stack (real data)
#   parity  the PHP API on the parity stack (http://127.0.0.1:18091, tools/parity-php/README.md; synthetic data only), inside the parity lock
#   --prepare  do the preparation below and stop
# Preparation: loads db/synthetic/notify-fixtures.sql (new API) or tools/parity-php/notify-fixtures.sql (PHP): members 926001 to 926999, classes 98601 to 98606, other rows 9760000 and up (header of the file).
# It first deletes every row of the block (including those an earlier run created), so a file can be run again. Then it signs each fixture member in at that side's Auth emulator and writes
# <vars folder>/notify.vars (new API) or build/parity-php/notify.vars (PHP) with auth_nf_<alias>=Bearer ...
# Nothing here pushes: the new API stack has no Google credential and the parity PHP has none either (docs/specs/initial-build/test-notify-notes.md). Files named *-new-api.hurl run on the new API only
# (the parity database has no class_scheduled_notifications table, and PHP's rate limiter keeps its state in files that a script cannot reset).
# The rate limits are 10 class notifications and 20 scheduled creates an hour per member on either side, and the files use one or two of each per run: do not run a side more than four times an hour.
# Only the tsr-app-test-<n> and tsr-parity compose projects are touched. Needs docker, curl, jq, hurl. Prints no secret.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIDE="${1:?usage: contract-notify.sh test|parity [--prepare] [hurl args]}"
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

FILES=(domains/notifications/spec/tests/notify-*.hurl)

# alias=token: the fixture members the files sign in as (Hurl variable auth_nf_<alias>); emails are nf.<token>@example.invalid.
MEMBERS=(
  "member=926001" "dev=926011" "displacer=926012" "victim=926013"
  "inbox=926021" "inbox_other=926022" "read=926023" "read_victim=926024" "readall=926025" "readall_other=926026"
  "super=926101" "gents=926102"
  "teacher1=926031" "teacher2=926032" "teacher3=926033" "teacher4=926034" "teacher5=926035" "teacher6=926036"
  "student1=926041" "student5=926045"
)

parity() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }
php_sql() { parity exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" tsr_synth'; }
test_sql() { docker compose -p "$TSR_TEST_PROJECT" -f docker-compose.dev.yml exec -T db psql -v ON_ERROR_STOP=1 -q -t -A -U tsr -d tsr > /dev/null; }

case "$SIDE" in
  test)
    export TSR_EMULATOR_PORT="$TSR_TEST_EMULATOR_PORT"
    "$ROOT/tools/require-synthetic-stack.sh" "$TSR_TEST_PROJECT"
    test_sql < db/synthetic/notify-fixtures.sql
    MINT="tools/dev-auth/mint-token.sh"
    BASE="$TSR_TEST_BASE_URL"
    VARS="$TSR_TEST_VARS_DIR/notify.vars" ;;
  parity)
    parity_lock
    php_sql < tools/parity-php/notify-fixtures.sql
    KEPT=()
    for f in "${FILES[@]}"; do case "$f" in *-new-api.hurl) ;; *) KEPT+=("$f") ;; esac; done
    FILES=("${KEPT[@]}")
    MINT="tools/parity-php/mint-token.sh"
    BASE="http://127.0.0.1:18091"
    VARS="build/parity-php/notify.vars" ;;
  *) echo "side must be test or parity" >&2; exit 1 ;;
esac

mkdir -p "$(dirname "$VARS")"
umask 077
: > "$VARS"
TMP="$(mktemp)"
trap 'rm -f "$TMP"; parity_unlock' EXIT
for entry in "${MEMBERS[@]}"; do
  alias="${entry%%=*}"
  token="${entry#*=}"
  "$MINT" "nf.${token}@example.invalid" "$TMP" > /dev/null
  printf 'auth_nf_%s=%s\n' "$alias" "$(sed -n 's/^auth_value=//p' "$TMP")" >> "$VARS"
done
echo "notify fixtures loaded on $SIDE; tokens in $VARS"

if [ "$PREPARE_ONLY" = 1 ]; then
  exit 0
fi

hurl --test --variable "base_url=$BASE" --variables-file "$VARS" "$@" "${FILES[@]}"
