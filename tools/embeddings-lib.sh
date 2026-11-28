#!/usr/bin/env bash
# Sourced by tools/embeddings-check.sh and tools/embed-lecture-fixture.sh, after tools/stack-env.sh. The embedding container of the selected synthetic TEST stack
# (the default test stack, or a lane: TSR_STACK=n with TSR_LANE_EMBEDDINGS=1 at `up`). The container has no published port, so a request is made by its own Python.

embeddings_container() {
  EMBEDDINGS_CONTAINER="$(docker compose -p "$TSR_TEST_PROJECT" -f docker-compose.dev.yml ps -q embeddings 2> /dev/null | head -n 1)"
  if [ -z "$EMBEDDINGS_CONTAINER" ]; then
    echo "no embeddings container in $TSR_TEST_PROJECT. A lane needs: TSR_STACK=n TSR_LANE_EMBEDDINGS=1 tools/test-stack.sh up" >&2
    exit 1
  fi
  case "$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$EMBEDDINGS_CONTAINER")" in
    tsr-app-test | tsr-app-test-[1-8]) ;;
    *) echo "refusing: $EMBEDDINGS_CONTAINER is not in a synthetic test stack" >&2; exit 1 ;;
  esac
}

embeddings_wait_healthy() {
  local status=""
  for _ in $(seq 1 60); do
    status="$(docker inspect --format '{{.State.Health.Status}}' "$EMBEDDINGS_CONTAINER")"
    if [ "$status" = healthy ]; then
      echo "ok: $EMBEDDINGS_CONTAINER is healthy"
      return 0
    fi
    sleep 2
  done
  echo "FAIL: $EMBEDDINGS_CONTAINER is '$status' after 120 seconds" >&2
  exit 1
}

# embeddings_post PATH < json: POSTs the body to the service and prints its answer.
embeddings_post() {
  docker exec -i "$EMBEDDINGS_CONTAINER" python -c '
import sys, urllib.request
request = urllib.request.Request("http://127.0.0.1:8000" + sys.argv[1], data=sys.stdin.buffer.read(), headers={"Content-Type": "application/json"})
sys.stdout.buffer.write(urllib.request.urlopen(request, timeout=120).read())
' "$1"
}
