#!/usr/bin/env bash
# TC-SRCH-Q5-01 (the check half): the embedding service of a synthetic TEST stack is healthy and answers POST /embed with 384 numbers.
# Usage: [TSR_STACK=n] tools/embeddings-check.sh
#   A lane has no embedding container unless it was started with TSR_LANE_EMBEDDINGS=1 (tools/test-stack.sh); the default test stack runs it. Never the dev stack.
# The container has no published port and no curl: the request is made by the container's own Python, through `docker exec`, to 127.0.0.1:8000.
# Checks: the container becomes healthy (up to 120 s); /embed gives 384 numbers for each text, in query and in passage mode, for English, Hindi and Arabic text;
# the vectors have unit length (the model's output is normalised); the image has no curl; the service names the model BAAI/bge-small-en-v1.5.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck disable=SC1091
. tools/stack-env.sh
# shellcheck disable=SC1091
. tools/embeddings-lib.sh

embeddings_container
embeddings_wait_healthy

body='{"texts":["a quiet reading hour","सुबह की पढ़ाई की योजना","تنظيم وقت الدراسة"],"mode":"MODE"}'
for mode in query passage; do
  answer="$(printf '%s' "${body/MODE/$mode}" | embeddings_post /embed)"
  echo "$answer" | jq -e --arg mode "$mode" '
    .dim == 384 and .count == 3 and .mode == $mode and .model == "BAAI/bge-small-en-v1.5"
    and (.vectors | length == 3)
    and ([.vectors[] | length == 384] | all)
    and ([.vectors[] | (map(. * .) | add | sqrt) | (. - 1 | fabs) < 0.001] | all)' > /dev/null \
    || { echo "FAIL: /embed in $mode mode did not give 3 unit vectors of 384 numbers" >&2; exit 1; }
  echo "ok: /embed ($mode): 3 vectors of 384 numbers, unit length"
done

if docker exec "$EMBEDDINGS_CONTAINER" sh -c 'command -v curl' > /dev/null 2>&1; then
  echo "FAIL: the image has curl; the health check was written for an image without it" >&2
  exit 1
fi
echo "ok: the image has no curl (the health check is Python)"
