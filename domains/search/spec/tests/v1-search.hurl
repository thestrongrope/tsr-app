# GET /api/v1/search contract: the published articles that match q, in the answer shape of today's website (shared/api/WebsiteV1.cs).
# Public: no sign-in. Data: the 12 published synthetic articles of db/synthetic/content, indexed in Elasticsearch by the library-search-feed worker (no article body is indexed).
# Needs a stack that runs Elasticsearch with content-refresh and library-search-feed: the default test stack, or a lane started with TSR_LANE_WORKERS=library-search-feed (tools/test-stack.sh).
# The database fallback (Elasticsearch down) is v1-search-fallback.hurl; the 429 is v1-search-rate-limit.hurl, which uses up the bucket for a minute and runs last.
# Cases: TC-SRCH-R1-01, R2-01, R3-01, R4-01, R5-01, R15-01 of docs/specs/website-port/search-port-plan.md.
# Variable: base_url. Every request below comes from one client, so the whole file stays under 60 requests a minute.

# 1. TC-SRCH-R1-01: a title word; the answer shape, the headers, the first result
GET {{base_url}}/api/v1/search?q=zorvath
HTTP 200
[Asserts]
header "Content-Type" == "application/json"
header "Cache-Control" == "public, max-age=60"
header "ETag" matches /^"[0-9a-f]{32}"$/
header "Vary" == "Accept-Encoding"
header "Access-Control-Allow-Origin" == "*"
header "X-Content-Type-Options" == "nosniff"
jsonpath "$.success" == true
jsonpath "$.meta.version" == "1.0"
jsonpath "$.meta.cache.maxAge" == 60
jsonpath "$.data.query" == "zorvath"
jsonpath "$.data.searchEngine" == "elasticsearch"
jsonpath "$.data.took" isInteger
jsonpath "$.data.results[0].slug" == "the-zorvath-timetable"
jsonpath "$.data.results[0].title" == "The Zorvath Timetable"
jsonpath "$.data.results[0].id" == 0
jsonpath "$.data.results[0].readingTime" == 1
jsonpath "$.data.results[0].score" > 0
jsonpath "$.data.results[0].author" exists
jsonpath "$.data.results[0].language" == "en"
jsonpath "$.data.results[0].categories" isCollection
jsonpath "$.data.results[0].tags" isCollection
jsonpath "$.data.results[0].highlights.title[0]" == "The <em>Zorvath</em> Timetable"
jsonpath "$.data.results[0].content" not exists

# 2. TC-SRCH-R2-01: q missing, empty, blank: a 400 in the website's failure shape, no cache headers
GET {{base_url}}/api/v1/search
HTTP 400
[Asserts]
header "Cache-Control" not exists
jsonpath "$.success" == false
jsonpath "$.error.code" == "VALIDATION_ERROR"
jsonpath "$.error.message" == "Missing required parameter: q"
jsonpath "$.meta.cache.maxAge" == 0

GET {{base_url}}/api/v1/search?q=
HTTP 400
[Asserts]
jsonpath "$.error.code" == "VALIDATION_ERROR"

GET {{base_url}}/api/v1/search?q=%20%20%20
HTTP 400
[Asserts]
jsonpath "$.error.message" == "Missing required parameter: q"

# 3. TC-SRCH-R3-01: limit and offset are read as the website reads them
GET {{base_url}}/api/v1/search?q=zorvath&limit=0
HTTP 200
[Asserts]
jsonpath "$.pagination.limit" == 1
jsonpath "$.pagination.offset" == 0
jsonpath "$.data.results" count == 1

GET {{base_url}}/api/v1/search?q=zorvath&limit=500
HTTP 200
[Asserts]
jsonpath "$.pagination.limit" == 100

GET {{base_url}}/api/v1/search?q=zorvath&limit=abc&offset=-3
HTTP 200
[Asserts]
jsonpath "$.pagination.limit" == 20
jsonpath "$.pagination.offset" == 0

GET {{base_url}}/api/v1/search?q=zorvath&limit=7x
HTTP 200
[Asserts]
jsonpath "$.pagination.limit" == 7

# 3b. A page that ends past Elasticsearch's 10000-result window, and a text of more than 200 characters, are refused before any search
GET {{base_url}}/api/v1/search?q=zorvath&offset=10000
HTTP 400
[Asserts]
header "Cache-Control" not exists
jsonpath "$.error.code" == "VALIDATION_ERROR"
jsonpath "$.error.message" == "Result window too large: offset plus limit must not exceed 10000"

GET {{base_url}}/api/v1/search?q=zorvath&limit=100&offset=9901
HTTP 400
[Asserts]
jsonpath "$.error.message" == "Result window too large: offset plus limit must not exceed 10000"

GET {{base_url}}/api/v1/search?q=zorvath&limit=100&offset=9900
HTTP 200

GET {{base_url}}/api/v1/search?q=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
HTTP 400
[Asserts]
jsonpath "$.error.message" == "Query too long: at most 200 characters"

# 4. TC-SRCH-R4-01: a category keeps only that category's articles
GET {{base_url}}/api/v1/search?q=margin%20notes&category=note-taking
HTTP 200
[Asserts]
jsonpath "$.data.results" count == 2
jsonpath "$.data.results[0].slug" == "a-first-look-at-margin-notes"
jsonpath "$.data.results[1].slug" == "building-a-weekly-summary-page"
jsonpath "$.data.results[0].categories" contains "note-taking"
jsonpath "$.data.results[1].categories" contains "note-taking"

GET {{base_url}}/api/v1/search?q=margin%20notes&category=no-such-category
HTTP 200
[Asserts]
jsonpath "$.data.results" count == 0
jsonpath "$.pagination.hasMore" == false

# 5. TC-SRCH-R5-01: four articles match "margin notes". pagination.total is the number of results on THIS page and hasMore is true exactly when that number equals limit (the website's rule, kept).
GET {{base_url}}/api/v1/search?q=margin%20notes&limit=2
HTTP 200
[Asserts]
jsonpath "$.pagination.total" == 2
jsonpath "$.pagination.hasMore" == true

GET {{base_url}}/api/v1/search?q=margin%20notes&limit=5
HTTP 200
[Asserts]
jsonpath "$.pagination.total" == 4
jsonpath "$.pagination.hasMore" == false

# The quirk: a page that is exactly full says hasMore although nothing follows.
GET {{base_url}}/api/v1/search?q=margin%20notes&limit=4
HTTP 200
[Asserts]
jsonpath "$.pagination.total" == 4
jsonpath "$.pagination.hasMore" == true

GET {{base_url}}/api/v1/search?q=margin%20notes&limit=2&offset=2
HTTP 200
[Asserts]
jsonpath "$.pagination.offset" == 2
jsonpath "$.data.results" count == 2

# 6. The website's quirk kept: a text of stopwords leaves the concept clause empty, and an empty must matches every article.
GET {{base_url}}/api/v1/search?q=of%20the&limit=100
HTTP 200
[Asserts]
jsonpath "$.data.results" count == 12

# 7. TC-SRCH-R15-01: a 200 sends its validators, and is still a 200 when the same ETag comes back: this route never answers 304
GET {{base_url}}/api/v1/search?q=zorvath
HTTP 200
[Captures]
etag: header "ETag"

GET {{base_url}}/api/v1/search?q=zorvath
If-None-Match: {{etag}}
HTTP 200
[Asserts]
header "Cache-Control" == "public, max-age=60"
jsonpath "$.data.results[0].slug" == "the-zorvath-timetable"

# 8. The caller's text is a value: query syntax finds nothing and breaks nothing
GET {{base_url}}/api/v1/search?q=*:*
HTTP 200
[Asserts]
jsonpath "$.data.results" count == 0

GET {{base_url}}/api/v1/search?q=%22%7D%20%2C%20%7B%22match_all%22%3A%20%7B%7D%7D%20
HTTP 200
[Asserts]
jsonpath "$.data.searchEngine" == "elasticsearch"
jsonpath "$.data.results" count == 0
