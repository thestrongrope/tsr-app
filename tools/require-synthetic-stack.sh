#!/usr/bin/env bash
# Usage: tools/require-synthetic-stack.sh <compose project>   (tsr-app-dev or tsr-app-test)
# Refuses (exit 1) unless that stack's PostgreSQL holds only synthetic members. It runs the one read-only count of
# tools/data-load/test/require-synthetic.sh (the single rule). Every contract script calls it before any write.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${1:?usage: require-synthetic-stack.sh <compose project>}"
case "$PROJECT" in tsr-app-dev|tsr-app-test) ;; *) echo "require-synthetic-stack: unknown project $PROJECT" >&2; exit 1 ;; esac
TSR_DST_CLIENT="docker compose -p $PROJECT -f $ROOT/docker-compose.dev.yml exec -T db psql -U tsr -d tsr" \
  "$ROOT/tools/data-load/test/require-synthetic.sh"
