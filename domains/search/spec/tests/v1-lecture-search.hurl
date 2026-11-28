# GET /api/v1/lectures/search contract, with the meaning layer ON: the keyword ranking and the meaning ranking fused, searchEngine "elasticsearch+semantic".
# Public: no sign-in. Data: the 12 invented lectures of db/synthetic/lectures (its README.md maps each to a case), indexed by the library-search-feed worker; the vectors come from the embedding container.
# Needs a stack with Elasticsearch, the embedding service and TSR_LECTURES_SEMANTIC_WEIGHT above 0: the default test stack, or a lane started with TSR_STACK=n TSR_LANE_WORKERS=library-search-feed TSR_LANE_EMBEDDINGS=1 (tools/test-stack.sh).
# Without the embedding service the same route answers from keywords only: v1-lecture-search-keywords.hurl. The 429 is v1-lecture-search-rate-limit.hurl, which uses up the bucket for a minute and runs last.
# Cases: TC-SRCH-R7-01, R7-02, R7-03, R8-01, R9-01, R10-01, R10-03, R13-01, R15-01 of docs/specs/website-port/search-port-plan.md.
# Variable: base_url. Every request below comes from one client, so the file stays under 60 requests a minute.

# 1. TC-SRCH-R7-01: a phrase that is a chapter title and not the title; the answer shape, the headers, the matched chapters with their highlights
GET {{base_url}}/api/v1/lectures/search?q=first%20hour%20of%20the%20morning
HTTP 200
[Asserts]
header "Content-Type" == "application/json"
header "Cache-Control" == "public, max-age=60"
header "ETag" matches /^"[0-9a-f]{32}"$/
header "Vary" == "Accept-Encoding"
header "Access-Control-Allow-Origin" == "*"
jsonpath "$.success" == true
jsonpath "$.meta.cache.maxAge" == 60
jsonpath "$.data.query" == "first hour of the morning"
jsonpath "$.data.searchEngine" == "elasticsearch+semantic"
jsonpath "$.data.took" isInteger
jsonpath "$.data.total" <= 100
jsonpath "$.pagination.total" isInteger
jsonpath "$.data.results[0].slug" == "SYNTHLEC001"
jsonpath "$.data.results[0].title" == "Planning a Quiet Reading Hour"
jsonpath "$.data.results[0].url" == "https://www.youtube.com/watch?v=SYNTHLEC001"
jsonpath "$.data.results[0].language" == "en"
jsonpath "$.data.results[0].durationSec" == 840
jsonpath "$.data.results[0].thumbnail" == "https://i.ytimg.com/vi/SYNTHLEC001/mqdefault.jpg"
jsonpath "$.data.results[0].chapters" count == 3
jsonpath "$.data.results[0].matchedChapters" count == 3
jsonpath "$.data.results[0].matchedChapters[0].start_sec" == 210
jsonpath "$.data.results[0].matchedChapters[0].title" == "Choosing the first hour of the morning"
jsonpath "$.data.results[0].matchedChapters[0].url" == "https://www.youtube.com/watch?v=SYNTHLEC001&t=210s"
jsonpath "$.data.results[0].matchedChapters[0].highlight.title[0]" contains "<em>first</em>"
jsonpath "$.data.results[0].highlights.content" isCollection
jsonpath "$.data.results[0].score" > 0

# 2. TC-SRCH-R7-03: a misspelt word that one transcript holds is found by the fuzzy stage
GET {{base_url}}/api/v1/lectures/search?q=quelmbri
HTTP 200
[Asserts]
jsonpath "$.data.results[0].slug" == "SYNTHLEC002"

# 3. TC-SRCH-R7-02: a word that only one lecture holds (fewer than 3 hits, so the fuzzy body is sent too)
GET {{base_url}}/api/v1/lectures/search?q=zorvath
HTTP 200
[Asserts]
jsonpath "$.data.results[0].slug" == "SYNTHLEC003"

# 4. TC-SRCH-R10-01: a concept that no keyword of the lecture names is found by meaning
GET {{base_url}}/api/v1/lectures/search?q=grief
HTTP 200
[Asserts]
jsonpath "$.data.searchEngine" == "elasticsearch+semantic"
jsonpath "$.data.results[0].slug" == "SYNTHLEC004"
jsonpath "$.data.results[0].matchedChapters" count == 0
jsonpath "$.data.total" <= 100

# 5. TC-SRCH-R10-03: the lecture without a vector was indexed without error and is found by its keywords (Hindi: "anushasan")
GET {{base_url}}/api/v1/lectures/search?q=%E0%A4%85%E0%A4%A8%E0%A5%81%E0%A4%B6%E0%A4%BE%E0%A4%B8%E0%A4%A8
HTTP 200
[Asserts]
jsonpath "$.data.results[0].slug" == "SYNTHLEC009"

# 6. TC-SRCH-R9-01: a language keeps only that language, in the keyword part and the meaning part alike
GET {{base_url}}/api/v1/lectures/search?q=patience&language=hi
HTTP 200
[Asserts]
jsonpath "$.data.searchEngine" == "elasticsearch+semantic"
jsonpath "$.data.results" count == 5
jsonpath "$.data.results[*].slug" contains "SYNTHLEC007"
jsonpath "$.data.results[*].slug" contains "SYNTHLEC010"
jsonpath "$.data.results[*].language" not contains "en"
jsonpath "$.data.results[*].language" not contains "ar"

GET {{base_url}}/api/v1/lectures/search?q=patience&language=en
HTTP 200
[Asserts]
jsonpath "$.data.results" count == 5
jsonpath "$.data.results[*].slug" contains "SYNTHLEC001"
jsonpath "$.data.results[*].slug" contains "SYNTHLEC005"
jsonpath "$.data.results[*].language" not contains "hi"
jsonpath "$.data.results[*].language" not contains "ar"

# 7. TC-SRCH-R8-01: no q, and a blank q, list every lecture newest first, with query empty and a total of every lecture
GET {{base_url}}/api/v1/lectures/search
HTTP 200
[Asserts]
jsonpath "$.data.query" == ""
jsonpath "$.data.searchEngine" == "elasticsearch"
jsonpath "$.data.total" == 12
jsonpath "$.pagination.total" == 12
jsonpath "$.pagination.hasMore" == false
jsonpath "$.data.results" count == 12
jsonpath "$.data.results[0].slug" == "SYNTHLEC011"
jsonpath "$.data.results[1].slug" == "SYNTHLEC001"
jsonpath "$.data.results[11].slug" == "SYNTHLEC012"
jsonpath "$.data.results[0].score" == 0
jsonpath "$.data.results[0].matchedChapters" count == 0
jsonpath "$.data.results[0].highlights" not exists

GET {{base_url}}/api/v1/lectures/search?q=%20&language=en
HTTP 200
[Asserts]
jsonpath "$.data.query" == ""
jsonpath "$.data.total" == 5

# 8. TC-SRCH-R13-01: pagination.total is data.total; hasMore is true exactly when offset plus the results on this page is below it
GET {{base_url}}/api/v1/lectures/search?limit=5&offset=10
HTTP 200
[Asserts]
jsonpath "$.data.results" count == 2
jsonpath "$.data.total" == 12
jsonpath "$.pagination.total" == 12
jsonpath "$.pagination.limit" == 5
jsonpath "$.pagination.offset" == 10
jsonpath "$.pagination.hasMore" == false

GET {{base_url}}/api/v1/lectures/search?limit=5
HTTP 200
[Asserts]
jsonpath "$.data.results" count == 5
jsonpath "$.pagination.hasMore" == true

GET {{base_url}}/api/v1/lectures/search?limit=0
HTTP 200
[Asserts]
jsonpath "$.pagination.limit" == 1

GET {{base_url}}/api/v1/lectures/search?limit=500&offset=-3
HTTP 200
[Asserts]
jsonpath "$.pagination.limit" == 100
jsonpath "$.pagination.offset" == 0

# 9. The bounds the website does not have: a page past the engine's 10000-result window and a text of more than 200 characters are a 400 before any search
GET {{base_url}}/api/v1/lectures/search?offset=10000
HTTP 400
[Asserts]
header "Cache-Control" not exists
jsonpath "$.success" == false
jsonpath "$.error.code" == "VALIDATION_ERROR"
jsonpath "$.error.message" == "Result window too large: offset plus limit must not exceed 10000"

GET {{base_url}}/api/v1/lectures/search?q=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
HTTP 400
[Asserts]
jsonpath "$.error.message" == "Query too long: at most 200 characters"

# 10. TC-SRCH-R15-01: a 200 is still a 200 when its own ETag comes back: this route never answers 304
GET {{base_url}}/api/v1/lectures/search?q=grief
HTTP 200
[Captures]
etag: header "ETag"

GET {{base_url}}/api/v1/lectures/search?q=grief
If-None-Match: {{etag}}
HTTP 200
[Asserts]
header "Cache-Control" == "public, max-age=60"
jsonpath "$.data.results[0].slug" == "SYNTHLEC004"

# 11. The caller's text is a value: query syntax finds nothing and breaks nothing
GET {{base_url}}/api/v1/lectures/search?q=*:*&language=hi
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.data.results" count == 5
jsonpath "$.data.results[*].slug" contains "SYNTHLEC006"
jsonpath "$.data.results[*].slug" contains "SYNTHLEC007"
jsonpath "$.data.results[*].slug" contains "SYNTHLEC008"
jsonpath "$.data.results[*].slug" contains "SYNTHLEC009"
jsonpath "$.data.results[*].slug" contains "SYNTHLEC010"
jsonpath "$.data.results[*].language" not contains "en"
jsonpath "$.data.results[*].language" not contains "ar"
