#!/usr/bin/env bash
# Load test runner for a LANE stack (TSR_STACK=n, synthetic data only; never dev, never the default test stack).
# k6 (grafana/k6 image) runs inside the lane's Docker network against the gateway, so no host port is in the path.
# Usage: TSR_STACK=n tools/load/run.sh <command>
#   limits                       recreate the lane's api container with 2 CPUs and 512 MB (build/test-n/load.override.yml);
#                                LOAD_LIMITS=off: with no limit; LOAD_LOG_LEVEL=Warning: the logging control
# LOAD_VUS picks the user levels of `routes` and `mixed`, LOAD_ROUTES the routes, LOAD_LABEL_PREFIX marks a control run's files.
#   content                      load the synthetic Library content once (one tick of the content-refresh worker)
#   callers                      give some synthetic members of the lane an admin role and write build/test-n/load-callers.json
#   one MODE ROUTE VUS LABEL     one k6 run (MODE route|mixed|heavy), with docker stats sampled beside it
#   routes REP                   scenario 1: every route at 1, 10 and 50 users (60 s after a 15 s warm-up); REP picks the route order
#   mixed REP                    scenario 2: the app-opening mix at 10, 50 and 100 users, 3 minutes each
#   heavy                        scenario 3: xlsx, PDF, MIS report and one write at 1 and 5 users, 20 requests each
#   cold                         restart the api container three times: seconds to the first 200, first signed-in request, idle memory
#   soak                         scenario 4: the mix at 20 users for 15 minutes, memory and connections sampled
# With LOAD_TARGET=php the `one`, `routes` and `mixed` commands run against the shared PHP parity stack instead, under its lock.
# Results: docs/specs/load-test/raw/<label>.json (k6), <label>.stats.tsv (docker stats). No token is written anywhere:
# load.js signs the callers in at the stack's own Auth emulator and keeps the tokens in memory.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
case "${TSR_STACK:-}" in [1-8]) ;; *) echo "load: set TSR_STACK to a lane, an integer from 1 to 8" >&2; exit 1 ;; esac
# shellcheck disable=SC1091
. tools/stack-env.sh
# shellcheck disable=SC1091
. tools/parity-lock.sh

RAW="docs/specs/load-test/raw"
OVERRIDE="$TSR_TEST_VARS_DIR/load.override.yml"
CALLERS="$TSR_TEST_VARS_DIR/load-callers.json"
TARGET="${LOAD_TARGET:-new}"
ROUTE_LIST="me permissions classes_coordinator classes_super class_detail this_week notifications search registrations articles article"
STATS_INTERVAL_SECONDS=2
# The local-only placeholder that guards in-memory emulator accounts: read from tools/dev-auth/mint-token.sh, its one home.
EMULATOR_PASSWORD="$(sed -n 's/^PASSWORD="\(.*\)"$/\1/p' tools/dev-auth/mint-token.sh)"
[ -n "$EMULATOR_PASSWORD" ] || { echo "load: no emulator placeholder found in tools/dev-auth/mint-token.sh" >&2; exit 1; }

case "$TARGET" in
  new)
    NETWORK="${TSR_TEST_PROJECT}_default"; BASE="http://gateway:8080"; PROJECT_ID="demo-tsr-app"
    WATCH="$TSR_TEST_PROJECT-api-1 $TSR_TEST_PROJECT-db-1 $TSR_TEST_PROJECT-gateway-1 $TSR_TEST_PROJECT-firebase-emulator-1 $TSR_TEST_PROJECT-gotenberg-1 $TSR_TEST_PROJECT-elasticsearch-1"
    PREFIX="${LOAD_LABEL_PREFIX:-}" ;;
  php)
    NETWORK="tsr-parity_parity"; BASE="http://api"; PROJECT_ID="demo-tsr-local"
    WATCH="tsr-parity-api-1 tsr-parity-db-1 tsr-parity-firebase-emulator-1"
    CALLERS="build/parity-php/load-callers.json"
    # The parity emulator's local-only placeholder (tools/parity-php/mint-token.sh reads the same line); never printed.
    EMULATOR_PASSWORD="$(sed -n 's/^PARITY_EMULATOR_PASSWORD=//p' tools/parity-php/parity.env)"
    PREFIX="${LOAD_LABEL_PREFIX:-}php-" ;;
  *) echo "load: LOAD_TARGET must be new or php" >&2; exit 1 ;;
esac

compose() { docker compose -p "$TSR_TEST_PROJECT" -f docker-compose.dev.yml -f "$TSR_TEST_VARS_DIR/compose.override.yml" -f "$OVERRIDE" "$@"; }
psql_lane() { docker exec -i "$TSR_TEST_PROJECT-db-1" psql -U tsr -d tsr -X -q -At -v ON_ERROR_STOP=1 "$@"; }

sample_stats() {
  local out="$1"
  while true; do
    # shellcheck disable=SC2086
    docker stats --no-stream --format "$(date -u +%H:%M:%S)	{{.Name}}	{{.CPUPerc}}	{{.MemUsage}}" $WATCH >> "$out" 2> /dev/null || true
    sleep "$STATS_INTERVAL_SECONDS"
  done
}

# The API container's CPU quota counters (cgroup v2), before and after a run: how often the 2 CPU limit stopped it.
throttle_counters() {
  if [ "$TARGET" != new ]; then return; fi
  docker exec "$TSR_TEST_PROJECT-api-1" sh -c 'grep -E "^(nr_periods|nr_throttled|throttled_usec|usage_usec)" /sys/fs/cgroup/cpu.stat' 2> /dev/null | tr '\n' ' ' >> "$1" || true
  echo >> "$1"
}

# One k6 run. The stats sampler is a background job of this shell and is always stopped, also when k6 fails.
run_one() {
  local mode="$1" route="$2" vus="$3" label="$PREFIX$4" duration="${5:-60}" sampler status=0
  [ -f "$CALLERS" ] || { echo "load: $CALLERS is missing; run: tools/load/run.sh callers" >&2; exit 1; }
  mkdir -p "$RAW"
  : > "$RAW/$label.stats.tsv"
  # The PHP parity stack is shared: the lock is held for one run only, so another worktree's contract run waits a minute or two at most.
  if [ "$TARGET" = php ]; then parity_lock; fi
  sample_stats "$RAW/$label.stats.tsv" &
  sampler=$!
  throttle_counters "$RAW/$label.cpustat"
  docker run --rm --network "$NETWORK" --user "$(id -u):$(id -g)" \
    -v "$ROOT/tools/load:/scripts:ro" -v "$ROOT/$CALLERS:/data/callers.json:ro" -v "$ROOT/$RAW:/out" \
    -e BASE_URL="$BASE" -e EMULATOR_URL="http://firebase-emulator:9099" -e PROJECT="$PROJECT_ID" -e PASSWORD="$EMULATOR_PASSWORD" \
    -e CALLERS=/data/callers.json -e MODE="$mode" -e ROUTE="$route" -e VUS="$vus" -e DURATION="$duration" \
    -e WARMUP="${LOAD_WARMUP:-15}" -e ITERATIONS="${LOAD_ITERATIONS:-20}" -e OUT="/out/$label.json" \
    grafana/k6 run --quiet --no-usage-report /scripts/load.js || status=$?
  throttle_counters "$RAW/$label.cpustat"
  kill "$sampler" 2> /dev/null || true
  wait "$sampler" 2> /dev/null || true
  if [ "$TARGET" = php ]; then parity_unlock; fi
  [ "$status" = 0 ] || echo "load: k6 exited $status for $label" >&2
  echo "$(date -u +%H:%M:%S) $label load=$(uptime | sed 's/.*load averages*: //')" >> "$RAW/${PREFIX}runs.log"
}

# Repetition 2 walks the routes in reverse and repetition 3 starts in the middle, so no route always runs first or hottest.
ordered_routes() {
  local rep="$1" routes="${LOAD_ROUTES:-$ROUTE_LIST}"
  case "$rep" in
    2) echo "$routes" | tr ' ' '\n' | tail -r | tr '\n' ' ' ;;
    3) echo "$routes" | awk '{ h = int(NF / 2); for (i = h + 1; i <= NF; i++) printf "%s ", $i; for (i = 1; i <= h; i++) printf "%s ", $i }' ;;
    *) echo "$routes" ;;
  esac
}

cmd_limits() {
  # LOAD_LIMITS=off writes no limit: only for the comparison with the PHP parity container, which has none and may not be changed.
  if [ "${LOAD_LIMITS:-on}" = off ]; then
    printf '# Generated by tools/load/run.sh: no limits (the comparison with PHP).\nservices:\n  api:\n    labels:\n      tsr.load: unlimited\n' > "$OVERRIDE"
  else
    cat > "$OVERRIDE" <<YML
# Generated by tools/load/run.sh: the load test gives the API the limits the 9 Nov benchmark used.
services:
  api:
    cpus: 2.0
    mem_limit: 512m
    memswap_limit: 512m
YML
  fi
  # Only for the logging control run: the timed runs keep the API's own logging (no setting at all).
  if [ -n "${LOAD_LOG_LEVEL:-}" ]; then
    case "$LOAD_LOG_LEVEL" in Warning|Information) ;; *) echo "load: LOAD_LOG_LEVEL must be Warning or Information" >&2; exit 1 ;; esac
    printf '    environment:\n      Logging__LogLevel__Default: "%s"\n' "$LOAD_LOG_LEVEL" >> "$OVERRIDE"
  fi
  compose up -d --no-deps api
  # nginx keeps the address of the API container it started with.
  compose restart gateway > /dev/null
  for _ in $(seq 1 60); do
    if curl -fsS --max-time 3 -o /dev/null "$TSR_TEST_BASE_URL/health" 2> /dev/null; then
      docker inspect "$TSR_TEST_PROJECT-api-1" --format 'lane api recreated: nanocpus={{.HostConfig.NanoCpus}} memory={{.HostConfig.Memory}}'
      return
    fi
    sleep 1
  done
  echo "load: the lane's API did not answer within a minute" >&2; exit 1
}

cmd_callers() {
  export TSR_DST_CLIENT="docker exec -i $TSR_TEST_PROJECT-db-1 psql -U tsr -d tsr"
  tools/data-load/test/require-synthetic.sh
  psql_lane -f - < tools/load/callers.sql > "$CALLERS"
  jq -r '"callers written: " + ([.callers[].role] | group_by(.) | map(.[0] + " " + (length | tostring)) | join(", "))' "$CALLERS"
}

# A lane runs one worker (here search-feed), so the Library's content is loaded by ONE tick of content-refresh in a
# throwaway container: it reads the synthetic files mounted at /var/tsr/content, sends nothing outward, and is removed.
cmd_content() {
  local name="$TSR_TEST_PROJECT-content-once" total=0
  docker rm -f "$name" > /dev/null 2>&1 || true
  compose run -d --no-deps --name "$name" -e TSR_WORKERS=content-refresh -e TSR_CONTENT_DIR=/var/tsr/content workers > /dev/null
  for _ in $(seq 1 30); do
    total="$(curl -fsS --max-time 3 "$TSR_TEST_BASE_URL/api/v1/articles" | jq '.pagination.total')"
    if [ "$total" != 0 ]; then break; fi
    sleep 2
  done
  docker rm -f "$name" > /dev/null
  [ "$total" != 0 ] || { echo "load: the content refresh loaded no article within a minute" >&2; exit 1; }
  echo "lane $TSR_STACK has $total published articles"
}

cmd_routes() {
  local rep="$1" route vus
  for vus in ${LOAD_VUS:-1 10 50}; do
    for route in $(ordered_routes "$rep"); do run_one route "$route" "$vus" "route-$route-v$vus-r$rep"; done
  done
}

cmd_mixed() {
  local rep="$1" vus
  for vus in ${LOAD_VUS:-10 50 100}; do run_one mixed mixed "$vus" "mixed-v$vus-r$rep" "${LOAD_MIXED_SECONDS:-180}"; done
}

cmd_heavy() {
  local route vus
  for vus in 1 5; do
    for route in xlsx pdf mis write; do run_one heavy "$route" "$vus" "heavy-$route-v$vus"; done
  done
}

now_ms() { perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000'; }

# Restart to the first 200 of GET /health through the gateway (polled every 20 ms, at most 60 s), then the first three
# public requests that read the database, then the memory 12 seconds later with no further traffic.
cmd_cold() {
  local out="$RAW/cold.tsv" try start first n
  : > "$out"
  for try in 1 2 3; do
    start="$(now_ms)"
    docker restart "$TSR_TEST_PROJECT-api-1" > /dev/null
    first=""
    for _ in $(seq 1 3000); do
      if curl -fsS --max-time 1 -o /dev/null "$TSR_TEST_BASE_URL/health" 2> /dev/null; then first="$(now_ms)"; break; fi
      sleep 0.02
    done
    [ -n "$first" ] || { echo "load: no 200 within a minute of the restart" >&2; exit 1; }
    printf 'try %s\trestart to first 200 (includes docker stopping the old process): %s ms\n' "$try" "$((first - start))" >> "$out"
    for n in 1 2 3; do
      printf 'try %s\tdatabase request %s: %s s\n' "$try" "$n" "$(curl -sS --max-time 30 -o /dev/null -w '%{time_total}' "$TSR_TEST_BASE_URL/api/v1/articles")" >> "$out"
    done
    sleep 12
    printf 'try %s\tmemory 12 s later: %s\n' "$try" "$(docker stats --no-stream --format '{{.MemUsage}}' "$TSR_TEST_PROJECT-api-1")" >> "$out"
  done
  cat "$out"
}

# API memory and the database connections of the API's role at the start, every 3 minutes and at the end.
soak_probe() {
  local out="$1" connections memory
  connections="$(psql_lane -c "select count(*) || ' total, ' || count(*) filter (where state = 'active') || ' active' from pg_stat_activity where usename = 'tsr_app'")"
  memory="$(docker stats --no-stream --format '{{.MemUsage}}' "$TSR_TEST_PROJECT-api-1")"
  echo "$(date -u +%H:%M:%S)	api memory $memory	connections $connections" >> "$out"
}

cmd_soak() {
  local out="$RAW/soak.probe.tsv" minute
  : > "$out"
  soak_probe "$out"
  run_one mixed mixed 20 "soak-v20" 900 &
  for minute in 3 6 9 12 15; do sleep 180; soak_probe "$out"; echo "soak minute $minute"; done
  wait
  soak_probe "$out"
}

COMMAND="${1:?usage: TSR_STACK=n tools/load/run.sh limits|content|callers|one|routes|mixed|heavy|cold|soak}"
if [ "$TARGET" = php ]; then
  case "$COMMAND" in one|routes|mixed) ;; *) echo "load: LOAD_TARGET=php supports one, routes and mixed only" >&2; exit 1 ;; esac
fi
case "$COMMAND" in
  limits) cmd_limits ;;
  callers) cmd_callers ;;
  content) cmd_content ;;
  one) run_one "${2:?mode}" "${3:?route}" "${4:?vus}" "${5:?label}" "${6:-60}" ;;
  routes) cmd_routes "${2:?repetition 1, 2 or 3}" ;;
  mixed) cmd_mixed "${2:?repetition}" ;;
  heavy) cmd_heavy ;;
  cold) cmd_cold ;;
  soak) cmd_soak ;;
  *) echo "load: unknown command $COMMAND" >&2; exit 1 ;;
esac
