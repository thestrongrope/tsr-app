#!/usr/bin/env bash
# Run the Library read contract files (domains/content/spec/tests/v1-*.hurl: the public /api/v1/ routes the app reads from today's website) against the new API.
# Files (every v1-*.hurl there is picked up by name): v1-articles (the list), v1-article (one article), v1-categories, v1-tags,
# v1-publications, v1-videos (the latest videos: a test stack has no channel id, so it calls no feed and the list is empty).
# Usage: tools/contract-website.sh test [--prepare] [extra hurl args]
#   test       the new API on the synthetic TEST stack (TSR_STACK=n picks lane n: http://localhost:810n); never the dev stack
#   --prepare  do the preparation below and stop
# Preparation: nothing is loaded here. The stack's content-refresh worker copies the synthetic content files (db/synthetic/content, 12 published articles)
# when it starts; this script only waits, up to 60 seconds, until GET /api/v1/articles?limit=1 reports pagination.total 12.
# The default test stack runs that worker (docker-compose.test.yml); a lane must be started with TSR_LANE_WORKERS=content-refresh (tools/test-stack.sh).
# There is no parity side: today's website is compared by tools/website-parity.cs, over its own content.
# The routes are public and only read: no token, no fixture SQL, and nothing is written. Needs curl, jq, hurl.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIDE="${1:?usage: contract-website.sh test [--prepare] [hurl args]}"
shift || true
cd "$ROOT"
# shellcheck disable=SC1091
. tools/stack-env.sh

if [ "$SIDE" != "test" ]; then
  echo "side must be test" >&2
  exit 1
fi

PREPARE_ONLY=0
if [ "${1:-}" = "--prepare" ]; then
  PREPARE_ONLY=1
  shift
fi

EXPECTED_ARTICLES=12
FILES=(domains/content/spec/tests/v1-*.hurl)

total=""
for _ in $(seq 1 30); do
  total="$(curl -fsS --max-time 3 "$TSR_TEST_BASE_URL/api/v1/articles?limit=1" 2> /dev/null | jq -r '.pagination.total' 2> /dev/null || true)"
  if [ "$total" = "$EXPECTED_ARTICLES" ]; then break; fi
  sleep 2
done
if [ "$total" != "$EXPECTED_ARTICLES" ]; then
  echo "the synthetic content is not loaded on $TSR_TEST_BASE_URL: expected $EXPECTED_ARTICLES published articles, got '${total:-no answer}' after 60 seconds." >&2
  echo "Is the content-refresh worker running? (a lane: TSR_STACK=n TSR_LANE_WORKERS=content-refresh tools/test-stack.sh up)" >&2
  exit 1
fi
echo "synthetic content loaded on $TSR_TEST_BASE_URL: $EXPECTED_ARTICLES published articles"

if [ "$PREPARE_ONLY" = 1 ]; then
  exit 0
fi

hurl --test --variable "base_url=$TSR_TEST_BASE_URL" "$@" "${FILES[@]}"
