#!/usr/bin/env bash
# The synthetic TEST stack: docker-compose.dev.yml run as its own compose project (tsr-app-test), so contract tests
# have a database that never holds real data. It shares nothing with the dev stack (tsr-app-dev): containers,
# network and volumes are prefixed by the project name, and the three published ports differ.
#   gateway http://localhost:8089, database localhost:5434, Auth emulator localhost:19100 (all 127.0.0.1 only); the internal-only gotenberg PDF renderer has no host port
# Usage: tools/test-stack.sh up | down | remove | status
#   up      build and start (migrate and seed run once); waits for the API through the gateway
#   down    stop and delete the containers, KEEP the volume
#   remove  stop and delete the containers AND the volume (a clean database next time)
# Only the tsr-app-test project is touched; every command carries -p tsr-app-test.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

stack() { docker compose -p tsr-app-test -f docker-compose.dev.yml -f docker-compose.test.yml "$@"; }

case "${1:?usage: test-stack.sh up|down|remove|status}" in
  up)
    stack up -d --build
    for _ in $(seq 1 60); do
      if curl -fsS --max-time 3 -o /dev/null http://localhost:8089/health; then echo "test stack up on :8089"; exit 0; fi
      sleep 2
    done
    echo "test stack did not answer on :8089 within 2 minutes" >&2; exit 1 ;;
  down) stack down ;;
  remove) stack down -v ;;
  status) stack ps ;;
  *) echo "usage: test-stack.sh up|down|remove|status" >&2; exit 1 ;;
esac
