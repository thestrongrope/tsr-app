#!/usr/bin/env bash
# Bring the local DEV stack (project tsr-app-dev, gateway https://gateway.tsr-app-dev.orb.local, an OrbStack name) up to this checkout's code. Use this instead of a plain
# `docker compose up` once the dev database holds real member data, because it NEVER runs the seed service (seed.sql inserts
# synthetic members and resets fixture rows; the root CLAUDE.md forbids that on real data).
#
# Usage: tools/dev-stack.sh up | status
#   up      starts db, the auth emulator, gotenberg and elasticsearch; runs the migrate job (migrations only add); rebuilds the API and
#           the workers container; restarts the gateway. The only worker switched on is search-feed, which sends nothing outward:
#           it copies names from the database into the stack's own Elasticsearch. push-drain and class-schedules stay off: the
#           database holds real device tokens.
#   status  lists the stack's containers.
set -euo pipefail
cd "$(dirname "$0")/.."

export COMPOSE_PROFILES=workers
export TSR_WORKERS=search-feed
export TSR_ELASTICSEARCH_URL=http://elasticsearch:9200
dc() { docker compose -f docker-compose.dev.yml "$@"; }

case "${1:?usage: dev-stack.sh up|status}" in
  up)
    dc up -d --wait db firebase-emulator gotenberg elasticsearch
    dc run --rm --build migrate
    # --no-deps: the API and the workers name the seed service as a dependency, and seed must not run here.
    dc up -d --build --no-deps api workers
    # nginx keeps the address of the API container it started with: start it again after a rebuild.
    dc up -d --no-deps gateway
    dc restart gateway > /dev/null
    for _ in $(seq 1 60); do
      if curl -fsS --max-time 3 -o /dev/null https://gateway.tsr-app-dev.orb.local/health; then echo "dev stack up on https://gateway.tsr-app-dev.orb.local (no seed was run)"; exit 0; fi
      sleep 2
    done
    echo "the dev stack did not answer on https://gateway.tsr-app-dev.orb.local within 2 minutes" >&2; exit 1 ;;
  status) dc ps ;;
  *) echo "usage: dev-stack.sh up|status" >&2; exit 1 ;;
esac
