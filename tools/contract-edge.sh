#!/usr/bin/env bash
# Run the edge lane's Hurl contract files (WhatsApp proxy, holy-quran, admin access log, search) against one side.
# Usage: [TSR_STACK=n] tools/contract-edge.sh test|parity [--prepare] [extra hurl args]
#   test    the new API on the synthetic TEST stack (http://localhost:8089, or TSR_STACK=n for lane n; tools/test-stack.sh up); never the dev stack (real data)
#   parity  the PHP API on the parity stack (http://127.0.0.1:18091; synthetic data only; its network holds no notifier and no Elasticsearch, so both answer "unreachable" or "not configured")
#   --prepare  load the fixtures, sign the members in, and stop
# Preparation: loads ONLY the edge fixtures (db/synthetic/edge-fixtures.sql for the new API, tools/parity-php/edge-fixtures.sql for PHP, inside the parity lock; tokens 927002 to 927012,
# 927100, 927101; header of the PHP file), signs each fixture member in at that side's Auth emulator and writes <vars folder>/edge.vars (build/parity-php/edge.vars for PHP): auth_edge_<alias>=Bearer ...
# The access-log rows and the rows the files cause (relink, logout) are reset on every run. The link change limit is 6 a minute per member: do not run one side twice within a minute.
# Files named *-new-api.hurl hold what only the new API does; they run on the new API only. Needs docker, curl, jq, hurl. Prints no secret.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIDE="${1:?usage: contract-edge.sh test|parity [--prepare] [hurl args]}"
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

FILES=(
  domains/notifications/spec/tests/whatsapp-guards.hurl
  domains/notifications/spec/tests/whatsapp-notifier-down.hurl
  domains/notifications/spec/tests/whatsapp-link-change-new-api.hurl
  domains/notifications/spec/tests/whatsapp-new-api.hurl
  domains/content/spec/tests/holy-quran.hurl
  domains/platform/spec/tests/admin-access-log.hurl
  domains/platform/spec/tests/admin-access-log-download.hurl
  domains/search/spec/tests/search.hurl
  domains/search/spec/tests/search-new-api.hurl
  domains/search/spec/tests/search-php-only.hurl
)

# alias=email: the fixture members (Hurl variable auth_edge_<alias>); the tokens are in db/synthetic/edge-fixtures.sql.
MEMBERS=(
  "gents=edge.927002@example.invalid"
  "plain=edge.927003@example.invalid"
  "wa_down=edge.927004@example.invalid"
  "wa_change=edge.927005@example.invalid"
  "log=edge.927006@example.invalid"
  "download=edge.927007@example.invalid"
  "wa_new=edge.927008@example.invalid"
  "nogender=edge.927009@example.invalid"
  "search=edge.927012@example.invalid"
)

parity() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }
php_sql() { parity exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" tsr_synth'; }
test_sql() { docker compose -p "$TSR_TEST_PROJECT" -f docker-compose.dev.yml exec -T db psql -v ON_ERROR_STOP=1 -q -t -A -U tsr -d tsr > /dev/null; }

case "$SIDE" in
  test)
    export TSR_EMULATOR_PORT="$TSR_TEST_EMULATOR_PORT"
    "$ROOT/tools/require-synthetic-stack.sh" "$TSR_TEST_PROJECT"
    test_sql < db/synthetic/edge-fixtures.sql
    # Files named *-php-only.hurl pin what only PHP's stack does (no search index); they run on PHP only.
    KEPT=()
    for f in "${FILES[@]}"; do case "$f" in *-php-only.hurl) ;; *) KEPT+=("$f") ;; esac; done
    FILES=("${KEPT[@]}")
    # The search cases need the fixtures in the index: the search-feed worker rebuilds it when it starts, so start it again and wait for its line.
    # A lane stack (TSR_STACK=n) has no workers container and no Elasticsearch: search-new-api.hurl cannot pass there.
    WORKERS="$(docker compose -p "$TSR_TEST_PROJECT" -f docker-compose.dev.yml --profile workers ps -q workers 2>/dev/null || true)"
    if [ -n "$WORKERS" ]; then
      SINCE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      docker restart "$WORKERS" > /dev/null
      FED=0
      for _ in $(seq 1 60); do
        if docker logs --since "$SINCE" "$WORKERS" 2>&1 | grep -q "Search feed: upserted"; then FED=1; break; fi
        sleep 1
      done
      if [ "$FED" != 1 ]; then echo "the search-feed worker did not rebuild the index within 60 seconds" >&2; exit 1; fi
    fi
    MINT="tools/dev-auth/mint-token.sh"
    BASE="$TSR_TEST_BASE_URL"
    VARS="$TSR_TEST_VARS_DIR/edge.vars" ;;
  parity)
    parity_lock
    php_sql < tools/parity-php/edge-fixtures.sql
    KEPT=()
    for f in "${FILES[@]}"; do case "$f" in *-new-api.hurl) ;; *) KEPT+=("$f") ;; esac; done
    FILES=("${KEPT[@]}")
    MINT="tools/parity-php/mint-token.sh"
    BASE="http://127.0.0.1:18091"
    VARS="build/parity-php/edge.vars" ;;
  *) echo "side must be test or parity" >&2; exit 1 ;;
esac

mkdir -p "$(dirname "$VARS")"
umask 077
: > "$VARS"
TMP="$(mktemp)"
trap 'rm -f "$TMP"; parity_unlock' EXIT
for entry in "${MEMBERS[@]}"; do
  alias="${entry%%=*}"
  email="${entry#*=}"
  "$MINT" "$email" "$TMP" > /dev/null
  printf 'auth_edge_%s=%s\n' "$alias" "$(sed -n 's/^auth_value=//p' "$TMP")" >> "$VARS"
done
echo "edge fixtures loaded on $SIDE; tokens in $VARS"

if [ "$PREPARE_ONLY" = 1 ]; then
  exit 0
fi

hurl --test --variable "base_url=$BASE" --variables-file "$VARS" "$@" "${FILES[@]}"
