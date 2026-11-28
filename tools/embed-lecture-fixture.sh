#!/usr/bin/env bash
# Puts the document vectors into db/synthetic/lectures/lectures.ndjson, by the running embedding container of a synthetic TEST stack, in passage mode: the same service that embeds queries
# at search time, as tsr-web's scripts/embed-lectures-data.ts does (a vector from another library or model would lie in another space).
# Usage: [TSR_STACK=n] tools/embed-lecture-fixture.sh [--out FILE]
#   Needs the embedding container: the default test stack, or a lane started with TSR_LANE_EMBEDDINGS=1 (tools/test-stack.sh). Needs jq. Never the dev stack.
#   Without --out the fixture is rewritten in place. The vectors are committed; run this again only when a lecture's text changes or the model or fastembed version changes,
#   and the guard test (domains/search/api/domain/LectureFixture.Tests.cs) says whether the result is whole. Running it twice must give the same file (compare two --out files).
# What is embedded: the title, the excerpt, the search phrases and the key points joined by ". ", as tsr-web's buildRepr level 0 does. The service truncates silently past its token limit, so each text is
# counted with the service's own tokenizer first and the run fails when one does not fit (the fixture is short; tsr-web demotes to terser texts, which a fixture never needs).
# One lecture is left without a vector on purpose (NO_VECTOR_SLUG): TC-SRCH-R10-03, indexed without error and found by keywords only.
set -euo pipefail

NO_VECTOR_SLUG="SYNTHLEC009"
TOKEN_MARGIN=8

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
FIXTURE="db/synthetic/lectures/lectures.ndjson"
OUT="$FIXTURE"
if [ "${1:-}" = "--out" ]; then
  OUT="${2:?--out needs a file}"
fi
# shellcheck disable=SC1091
. tools/stack-env.sh
# shellcheck disable=SC1091
. tools/embeddings-lib.sh

embeddings_container
embeddings_wait_healthy

# One text per lecture that gets a vector, in file order.
texts="$(jq -c --arg skip "$NO_VECTOR_SLUG" -n '
  [inputs | select(.slug != $skip)
   | ([.title, .excerpt] + .search_phrases + .key_points | map(select(length > 0)) | join(". ") | gsub("\\s+"; " ") | sub("^ "; "") | sub(" $"; ""))]' "$FIXTURE")"
count="$(echo "$texts" | jq 'length')"

limit="$(printf '{"texts":["probe"]}' | embeddings_post /tokens | jq -e 'select(.exact == true) | .max_tokens')"
budget=$((limit - TOKEN_MARGIN))
counts="$(printf '{"texts":%s}' "$texts" | embeddings_post /tokens)"
if ! echo "$counts" | jq -e --argjson budget "$budget" '.exact == true and ([.counts[] | . <= $budget] | all)' > /dev/null; then
  echo "FAIL: a lecture's text is over the model's budget of $budget tokens: $(echo "$counts" | jq -c .counts)" >&2
  exit 1
fi

answer="$(printf '{"texts":%s,"mode":"passage"}' "$texts" | embeddings_post /embed)"
echo "$answer" | jq -e --argjson count "$count" '.dim == 384 and .count == $count and .mode == "passage"' > /dev/null \
  || { echo "FAIL: the service did not answer $count vectors of 384 numbers" >&2; exit 1; }

# Write the lines again, the vector last (the website's key order); the lecture without a vector has none.
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
echo "$answer" | jq -c '.vectors' > "$tmp.vectors"
trap 'rm -f "$tmp" "$tmp.vectors"' EXIT
jq -c --arg skip "$NO_VECTOR_SLUG" --slurpfile vectors "$tmp.vectors" -n '
  [inputs] | reduce .[] as $lecture ({lines: [], next: 0};
    ($lecture | del(.embedding)) as $plain
    | if $plain.slug == $skip then .lines += [$plain]
      else .lines += [$plain + {embedding: $vectors[0][.next]}] | .next += 1 end)
  | .lines[]' "$FIXTURE" > "$tmp"

mv "$tmp" "$OUT"
echo "ok: $count lectures embedded in passage mode ($limit token limit, $budget budget), $NO_VECTOR_SLUG left without a vector: $OUT"
