# GET /api/v1/youtube contract: the channel's latest videos in the answer shape of today's website.
# Public: no sign-in. A test stack sets the channel to nothing (TSR_YOUTUBE_CHANNEL_ID is empty), so the API asks no feed and this file never causes a call to one:
# it proves the route, the shape, the options and the never-failing empty list (TC-LIB-R1-01, TC-LIB-R18-01 of docs/specs/website-port/f1-plan-draft.md).
# The videos' own fields, the paging and the kept list are proven over a fake feed in db/tests/LatestVideosTests.cs (TC-LIB-R16-01, R17-01).
# Variable: base_url. Run through tools/contract-website.sh test.

# 1. TC-LIB-R1-01, R18-01: no sign-in; nothing was ever read, so an empty list and not an error
GET {{base_url}}/api/v1/youtube
HTTP 200
[Asserts]
header "Content-Type" == "application/json"
header "Cache-Control" == "public, max-age=3600, stale-while-revalidate=7200"
header "ETag" matches /^"[0-9a-f]{32}"$/
header "Last-Modified" not exists
header "Access-Control-Allow-Origin" == "*"
header "X-Content-Type-Options" == "nosniff"
jsonpath "$.success" == true
jsonpath "$.meta.timestamp" matches /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/
jsonpath "$.meta.version" == "1.0"
jsonpath "$.meta.cache.maxAge" == 3600
jsonpath "$.data.videos" count == 0
jsonpath "$.data.meta.total" == 0
jsonpath "$.data.meta.channelId" == ""
jsonpath "$.data.meta.channelName" == "The Strong Rope"
jsonpath "$.data.meta.channelUrl" == "https://www.youtube.com/@TheStrongRope"
jsonpath "$.data.meta.lastUpdated" matches /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/
jsonpath "$.data.meta.cacheHit" isBoolean
jsonpath "$.data.meta.*" count == 6
jsonpath "$.pagination.total" == 0
jsonpath "$.pagination.limit" == 10
jsonpath "$.pagination.offset" == 0
jsonpath "$.pagination.hasMore" == false

# 2. The page size and the start are read and clamped: 1 to 50, from 0
GET {{base_url}}/api/v1/youtube
[Query]
limit: 5
offset: 8
HTTP 200
[Captures]
etag: header "ETag"
[Asserts]
jsonpath "$.pagination.limit" == 5
jsonpath "$.pagination.offset" == 8
jsonpath "$.data.videos" count == 0

GET {{base_url}}/api/v1/youtube
[Query]
limit: 99
offset: -3
HTTP 200
[Asserts]
jsonpath "$.pagination.limit" == 50
jsonpath "$.pagination.offset" == 0

GET {{base_url}}/api/v1/youtube
[Query]
limit: 0
offset: abc
HTTP 200
[Asserts]
jsonpath "$.pagination.limit" == 1
jsonpath "$.pagination.offset" == 0

# 3. The ETag is sent but never compared: the same request with it still gets the whole answer
GET {{base_url}}/api/v1/youtube
[Query]
limit: 5
offset: 8
If-None-Match: {{etag}}
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.pagination.limit" == 5

# 4. TC-LIB-R9-01: an option the route does not know is ignored: the page is the default one
GET {{base_url}}/api/v1/youtube
[Query]
unknownOption: 1
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.pagination.limit" == 10
jsonpath "$.pagination.offset" == 0
