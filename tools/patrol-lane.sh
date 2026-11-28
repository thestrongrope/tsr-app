#!/usr/bin/env bash
# Runs the Patrol journeys of hosts/app against the NEW API on a lane stack: the reviewer journeys
# (hosts/app/integration_test/journeys) or, with the -personas commands, the persona journeys (hosts/app/integration_test/personas).
# Usage: TSR_STACK=n tools/patrol-lane.sh up | reset | run [journey files, relative to hosts/app]
#        TSR_STACK=n tools/patrol-lane.sh up-personas | reset-personas | run-personas [persona journey files...]
#   up     starts lane n (tools/test-stack.sh up), gives its API tsr-account's real app-version catalog (the synthetic
#          contract catalog demands a build the app does not have, so the app would show its update gate), and builds
#          the cohort source.
#   reset  puts the lane's database back to the reviewer demo cohort and nothing else, and makes sure the reviewer can
#          sign in at the lane's Auth emulator. The runner calls it before every journey.
#   run    calls tools/patrol/run.sh, pointed at the lane (it resets before each journey).
#   The -personas commands do the same for the six personas: the reset adds tsr-account's persona fixture
#   (scripts/persona-cohort-teardown.sql, the reviewer cohort, scripts/persona-cohort.sql) and the run calls
#   tools/patrol/run.sh personas. Use a lane of their own (lane 4 by convention), so a persona run and a reviewer run never
#   reset each other; they also have a scratch database each, so both can run at once.
#   The persona lane also runs its own Elasticsearch with the search-feed worker (TSR_LANE_WORKERS=search-feed: the search
#   journeys need an index; no sending worker), and its reset loads the place rows the location journey reads
#   (db/synthetic/patrol-geo.sql) and has the worker rebuild the index from the rows just seeded.
#
# The cohort is defined ONCE, in tsr-account (migrations/2026_09_06_reviewer_demo_cohort.sql, MariaDB). It is applied to a
# scratch database in the synthetic parity MariaDB (`tsr_patrol`, or `tsr_patrol_personas` for the persona commands; schema
# and reference tables copied from `tsr_synth_s2`), and tools/data-load moves it into the lane's PostgreSQL. Never apply the
# cohort file to `tsr_synth`: it deletes every @demo.invalid member, which is nearly all of the generated data there.
#
# A lane only (TSR_STACK=1..8): the reset TRUNCATES the target, so the default test stack (the Hurl fixtures) and dev are refused.
# Needs: the parity stack's db up with `tsr_synth_s2` built (tools/parity-php/README.md, tools/parity-php/s2-source.sh), a
# tsr-account checkout (TSR_ACCOUNT_DIR, default ~/Projects/tsr-account), docker, curl, jq; `run` also needs adb and patrol_cli.
# Sign-in goes through the lane's Auth emulator with a local placeholder password (the reviewer: the one of
# tools/dev-auth/mint-token.sh; the personas: PERSONA_PASSWORD below, on accounts created with the fixed synthetic ids the
# fixture rows carry as firebase_uid): no real Firebase account and no secret is used. Prints no secret and no row value.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
case "${TSR_STACK:-}" in [1-8]) ;; *) echo "patrol-lane: set TSR_STACK to a lane, an integer from 1 to 8" >&2; exit 1 ;; esac
# shellcheck disable=SC1091
. tools/stack-env.sh

USAGE="usage: TSR_STACK=n tools/patrol-lane.sh up|reset|run [journey] (or up-personas|reset-personas|run-personas [journeys])"
COMMAND="${1:?$USAGE}"
ACCOUNT_DIR="${TSR_ACCOUNT_DIR:-$HOME/Projects/tsr-account}"
COHORT="$ACCOUNT_DIR/migrations/2026_09_06_reviewer_demo_cohort.sql"
CATALOG="$ACCOUNT_DIR/web/data/app_versions.json"
PERSONA_TEARDOWN="$ACCOUNT_DIR/scripts/persona-cohort-teardown.sql"
PERSONA_SEED="$ACCOUNT_DIR/scripts/persona-cohort.sql"
REVIEWER=appreview@demo.invalid
# The six personas that sign in: persona.<name>@demo.invalid, emulator account id (and firebase_uid) patrol-persona-<name>.
PERSONAS="member coord gentsadmin ladiesadmin superadmin finance"
# Local-only placeholder; it guards accounts of an in-memory emulator on 127.0.0.1.
PERSONA_PASSWORD="patrol-persona-local-only"
EMULATOR="http://127.0.0.1:$TSR_TEST_EMULATOR_PORT/identitytoolkit.googleapis.com/v1"
# The persona commands have a scratch database of their own, so they never collide with a reviewer run on another lane.
PERSONA_MODE=0
SOURCE_DB=tsr_patrol
case "$COMMAND" in *-personas|enrol-token|link-token) PERSONA_MODE=1; SOURCE_DB=tsr_patrol_personas ;; esac
# Tables with no member data that the cohort and the app's screens read (levels, syllabus, standard MCQs, lookups).
REFERENCE_TABLES="class_levels genders languages lookups permissions role_permissions interest_options syllabus topics subjects standard_mcqs standard_mcq_questions guides holy_quran tags age_ranges book_chapters"
VARS="$TSR_TEST_VARS_DIR/patrol-reviewer.vars"
PATROL_GEO="db/synthetic/patrol-geo.sql"
FEED_WAIT_SECONDS=90

MYSQL_PWD="$(sed -n 's/^PARITY_DB_ROOT_PASSWORD=//p' tools/parity-php/parity.env)"; export MYSQL_PWD
maria() { docker exec -i -e MYSQL_PWD tsr-parity-db-1 mariadb -uroot --init-command="SET max_statement_time=600" "$@"; }
maria_dump() { docker exec -i -e MYSQL_PWD tsr-parity-db-1 mariadb-dump -uroot --single-transaction --skip-comments "$@"; }

require_files() {
  [ -f "$COHORT" ] || { echo "patrol-lane: cohort file not found: $COHORT (set TSR_ACCOUNT_DIR)" >&2; exit 1; }
  [ -f "$CATALOG" ] || { echo "patrol-lane: app-version catalog not found: $CATALOG (set TSR_ACCOUNT_DIR)" >&2; exit 1; }
  [ "$PERSONA_MODE" = 0 ] && return
  [ -f "$PERSONA_TEARDOWN" ] || { echo "patrol-lane: persona teardown not found: $PERSONA_TEARDOWN (set TSR_ACCOUNT_DIR)" >&2; exit 1; }
  [ -f "$PERSONA_SEED" ] || { echo "patrol-lane: persona fixture not found: $PERSONA_SEED (set TSR_ACCOUNT_DIR)" >&2; exit 1; }
}

build_source() {
  echo "drop database if exists $SOURCE_DB; create database $SOURCE_DB character set utf8mb4 collate utf8mb4_unicode_520_ci;" | maria
  # The copied triggers run as the PHP user, which needs rights on the new database.
  echo "grant all privileges on \`$SOURCE_DB\`.* to 'tsr_user'@'%';" | maria
  maria_dump --no-data tsr_synth_s2 | maria "$SOURCE_DB"
  # shellcheck disable=SC2086
  maria_dump --no-create-info tsr_synth_s2 $REFERENCE_TABLES | maria "$SOURCE_DB"
}

# The persona fixture, in the order tsr-account's scripts/patrol-personas.sh applies it on PHP: its teardown first (the cohort reset
# deletes @demo.invalid users but not the persona classes or rule), then the cohort, then the personas with their uids.
seed_personas() {
  local name
  maria "$SOURCE_DB" < "$PERSONA_TEARDOWN" > /dev/null
  maria "$SOURCE_DB" < "$COHORT" > /dev/null
  {
    for name in $PERSONAS; do printf "SET @uid_%s := 'patrol-persona-%s';\n" "$name" "$name"; done
    cat "$PERSONA_SEED"
  } | maria "$SOURCE_DB" > /dev/null
}

# Emulator accounts live in memory: this creates each persona's when it is missing, with the id its row carries, and
# proves the sign-in answers that id (an account left with another id would sign in as nobody).
ensure_persona_accounts() {
  local name body got
  for name in $PERSONAS; do
    body="$(jq -n --arg id "patrol-persona-$name" --arg e "persona.$name@demo.invalid" --arg p "$PERSONA_PASSWORD" \
      '{localId:$id,email:$e,password:$p,emailVerified:true,returnSecureToken:true}')"
    # An existing account answers 400, which is fine: the sign-in below is the check.
    printf '%s' "$body" | curl -sS --max-time 10 -o /dev/null -X POST "$EMULATOR/projects/demo-tsr-app/accounts" \
      -H 'Authorization: Bearer owner' -H 'Content-Type: application/json' --data-binary @-
    got="$(printf '%s' "$body" | jq 'del(.localId)' | curl -sS --max-time 10 -X POST "$EMULATOR/accounts:signInWithPassword?key=local" \
      -H 'Content-Type: application/json' --data-binary @- | jq -r '.localId // empty')"
    [ "$got" = "patrol-persona-$name" ] \
      || { echo "patrol-lane: persona $name cannot sign in at the lane's Auth emulator with its fixed id" >&2; exit 1; }
  done
}

# India and the three postal codes the location journey types; the load leaves the geo tables alone, so they keep the seed's rows too.
load_patrol_geo() {
  { echo "set search_path = platform, public;"; cat "$PATROL_GEO"; } \
    | docker exec -i "$TSR_TEST_PROJECT-db-1" psql -X -q -v ON_ERROR_STOP=1 -U tsr -d tsr > /dev/null
}

# The search-feed worker reconciles the whole index when it starts (then every 10 minutes): start it again and wait for its line,
# so the index holds exactly the rows just seeded (as tools/contract-edge.sh does on the default test stack).
refresh_search_index() {
  local workers="$TSR_TEST_PROJECT-workers-1" since fed=0
  docker inspect "$workers" > /dev/null 2>&1 \
    || { echo "patrol-lane: lane $TSR_STACK has no workers container; run: TSR_STACK=$TSR_STACK tools/patrol-lane.sh up-personas" >&2; exit 1; }
  since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  docker restart "$workers" > /dev/null
  for _ in $(seq 1 "$FEED_WAIT_SECONDS"); do
    if docker logs --since "$since" "$workers" 2>&1 | grep -q "Search feed: upserted"; then fed=1; break; fi
    sleep 1
  done
  [ "$fed" = 1 ] || { echo "patrol-lane: the search-feed worker did not rebuild the index within $FEED_WAIT_SECONDS seconds" >&2; exit 1; }
}

case "$COMMAND" in
  up|up-personas)
    require_files
    # Only the persona lane gets Elasticsearch and the search-feed worker (its four search journeys need an index).
    if [ "$PERSONA_MODE" = 1 ]; then TSR_LANE_WORKERS=search-feed tools/test-stack.sh up; else tools/test-stack.sh up; fi
    PATROL_OVERRIDE="$TSR_TEST_VARS_DIR/patrol.override.yml"
    cat > "$PATROL_OVERRIDE" <<YML
# Generated by tools/patrol-lane.sh: the Patrol lane reads tsr-account's app-version catalog, not the synthetic contract one.
services:
  api:
    # A public web base, so the links the API builds from it exist (a class's joinUrl: without it the app hides Share Join Link).
    environment:
      TSR_PUBLIC_WEB_BASE: https://patrol.example.invalid
    volumes: !override
      - $CATALOG:/etc/tsr/app_versions.json:ro
YML
    docker compose -p "$TSR_TEST_PROJECT" -f docker-compose.dev.yml -f "$TSR_TEST_VARS_DIR/compose.override.yml" -f "$PATROL_OVERRIDE" up -d --no-deps api
    # nginx keeps the address of the API container it started with.
    docker compose -p "$TSR_TEST_PROJECT" -f docker-compose.dev.yml -f "$TSR_TEST_VARS_DIR/compose.override.yml" restart gateway > /dev/null
    build_source
    echo "patrol lane $TSR_STACK is up on $TSR_TEST_BASE_URL; next: TSR_STACK=$TSR_STACK tools/patrol-lane.sh ${COMMAND/up/run}"
    ;;
  reset|reset-personas)
    require_files
    echo "select 1 from information_schema.schemata where schema_name = '$SOURCE_DB'" | maria -N -B | grep -q 1 \
      || { echo "patrol-lane: scratch source $SOURCE_DB is missing; run: TSR_STACK=$TSR_STACK tools/patrol-lane.sh ${COMMAND/reset/up}" >&2; exit 1; }
    # Re-runnable by design: it drops the cohort and rebuilds it (its dates are relative to today).
    if [ "$PERSONA_MODE" = 1 ]; then seed_personas; else maria "$SOURCE_DB" < "$COHORT" > /dev/null; fi
    export TSR_SRC_CLIENT="docker exec -i -e MYSQL_PWD tsr-parity-db-1 mariadb -uroot $SOURCE_DB"
    # docker exec, not "docker compose exec": the load calls the client some hundreds of times, and compose adds about a second to each.
    export TSR_DST_CLIENT="docker exec -i $TSR_TEST_PROJECT-db-1 psql -U tsr -d tsr"
    tools/data-load/test/require-synthetic.sh
    # A run that was interrupted leaves the staging schema behind, and the next load refuses to start while it exists.
    echo "set client_min_messages = warning; drop schema if exists staging cascade" | $TSR_DST_CLIENT -X -q -v ON_ERROR_STOP=1 > /dev/null
    tools/data-load/load.sh --truncate --yes-truncate tsr | grep '^RESULT'
    # Emulator accounts live in memory: this creates the reviewer's when it is missing, and proves the sign-in works.
    TSR_EMULATOR_PORT="$TSR_TEST_EMULATOR_PORT" tools/dev-auth/mint-token.sh "$REVIEWER" "$VARS" > /dev/null
    if [ "$PERSONA_MODE" = 0 ]; then echo "patrol lane $TSR_STACK reset to the demo cohort"; exit 0; fi
    load_patrol_geo
    refresh_search_index
    ensure_persona_accounts
    echo "patrol lane $TSR_STACK reset to the demo cohort and the personas"
    ;;
  run)
    require_files
    [ -f "$VARS" ] || "$0" reset
    TSR_REVIEWER_PASSWORD="$(sed -n 's/^emulator_password=//p' "$VARS")"; export TSR_REVIEWER_PASSWORD
    export TSR_PATROL_API_URL="http://127.0.0.1:$TSR_TEST_GATEWAY_PORT"
    export TSR_PATROL_AUTH_EMULATOR_PORT="$TSR_TEST_EMULATOR_PORT"
    export TSR_PATROL_RESET_CMD="$ROOT/tools/patrol-lane.sh reset"
    shift
    exec tools/patrol/run.sh journeys "$@"
    ;;
  run-personas)
    require_files
    export TSR_PERSONA_PASSWORD="$PERSONA_PASSWORD"
    export TSR_PATROL_API_URL="http://127.0.0.1:$TSR_TEST_GATEWAY_PORT"
    export TSR_PATROL_AUTH_EMULATOR_PORT="$TSR_TEST_EMULATOR_PORT"
    # The whole per-journey setup: teardown, cohort, personas, load into the lane, emulator accounts.
    export TSR_PATROL_RESET_CMD="$ROOT/tools/patrol-lane.sh reset-personas"
    export TSR_PATROL_ENROL_TOKEN_CMD="$ROOT/tools/patrol-lane.sh enrol-token"
    export TSR_PATROL_LINK_TOKEN_CMD="$ROOT/tools/patrol-lane.sh link-token"
    shift
    exec tools/patrol/run.sh personas "$@"
    ;;
  enrol-token)
    # For tools/patrol/run.sh only (it hands the number to the enrol-by-token journey): the invented registrant's token.
    echo "select token from users where email = 'persona-reg.gentsplace@demo.invalid'" | maria -N -B "$SOURCE_DB"
    ;;
  link-token)
    # For tools/patrol/run.sh only: the token of the member the link-student journey links to; nothing when the fixture has none.
    echo "select token from users where email = 'persona-link.member@demo.invalid'" | maria -N -B "$SOURCE_DB"
    ;;
  *) echo "$USAGE" >&2; exit 1 ;;
esac
