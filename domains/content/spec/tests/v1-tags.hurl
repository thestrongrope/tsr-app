# GET /api/v1/taxonomies/tags contract: every tag of the published articles with its count, most used first, in the answer shape of today's website.
# Public: no sign-in. Data: the synthetic content files of db/synthetic/content (its README.md maps them to these cases): 9 tags.
# Cases: TC-LIB-R1-01, R14-01, R19-01 of docs/specs/website-port/f1-plan-draft.md.
# Variable: base_url. Run through tools/contract-website.sh test, which first waits for the content to be loaded.

# 1. TC-LIB-R1-01, R14-01, R19-01: no sign-in; name, slug and count; most used first, equal counts in the order first met walking the articles newest first
GET {{base_url}}/api/v1/taxonomies/tags
HTTP 200
[Captures]
etag: header "ETag"
[Asserts]
header "Content-Type" == "application/json"
header "Cache-Control" == "public, max-age=3600, stale-while-revalidate=86400"
header "ETag" matches /^"[0-9a-f]{32}"$/
header "Last-Modified" not exists
header "Access-Control-Allow-Origin" == "*"
header "X-Content-Type-Options" == "nosniff"
jsonpath "$.success" == true
jsonpath "$.meta.timestamp" matches /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/
jsonpath "$.meta.version" == "1.0"
jsonpath "$.meta.cache.maxAge" == 3600
jsonpath "$.pagination" not exists
jsonpath "$.data" count == 9
# The two drafts carry "Study Skills", "Night Reading" and "Imam Ali (a.s.)": counted, these would be 8, 3 and 3.
jsonpath "$.data[0].name" == "Study Skills"
jsonpath "$.data[0].slug" == "study-skills"
jsonpath "$.data[0].articleCount" == 7
# Three tags are used twice. Their order is not the alphabet's: it is where each is first met, newest article first.
jsonpath "$.data[1].name" == "Night Reading"
jsonpath "$.data[1].slug" == "night-reading"
jsonpath "$.data[1].articleCount" == 2
jsonpath "$.data[2].name" == "Imam Ali (a.s.)"
jsonpath "$.data[2].slug" == "imam-ali-as"
jsonpath "$.data[2].articleCount" == 2
jsonpath "$.data[3].name" == "Summaries"
jsonpath "$.data[3].articleCount" == 2
jsonpath "$.data[4].name" == "Planning"
jsonpath "$.data[5].name" == "Timetables"
jsonpath "$.data[6].name" == "Zorvath Method"
jsonpath "$.data[6].slug" == "zorvath-method"
jsonpath "$.data[7].name" == "History"
jsonpath "$.data[8].name" == "Glossary"
jsonpath "$.data[8].slug" == "glossary"
jsonpath "$.data[8].articleCount" == 1
# Counts never rise down the list: 1 of 7, 3 of 2, 5 of 1, in that order.
jsonpath "$.data[?(@.articleCount == 1)]" count == 5
jsonpath "$.data[4].articleCount" == 1
jsonpath "$.data[5].articleCount" == 1
jsonpath "$.data[6].articleCount" == 1
jsonpath "$.data[7].articleCount" == 1
# The fields on every tag, and their kinds.
jsonpath "$.data[*].name" count == 9
jsonpath "$.data[*].slug" count == 9
jsonpath "$.data[*].articleCount" count == 9
jsonpath "$.data[2].name" isString
jsonpath "$.data[2].slug" isString
jsonpath "$.data[2].articleCount" isInteger
jsonpath "$.data[2].*" count == 3

# 2. Options are ignored: this route has none
GET {{base_url}}/api/v1/taxonomies/tags
[Query]
limit: 1
sort: name
HTTP 200
[Asserts]
jsonpath "$.data" count == 9
header "ETag" == "{{etag}}"

# 3. Not changed since the ETag of request 1: 304 with no body
GET {{base_url}}/api/v1/taxonomies/tags
If-None-Match: {{etag}}
HTTP 304
[Asserts]
bytes count == 0

# 4. Another ETag gets the whole answer
GET {{base_url}}/api/v1/taxonomies/tags
If-None-Match: "0123456789abcdef0123456789abcdef"
HTTP 200
[Asserts]
jsonpath "$.data" count == 9
header "ETag" == "{{etag}}"

# 5. There is no Last-Modified on this route, so a date alone never gives a 304
GET {{base_url}}/api/v1/taxonomies/tags
If-Modified-Since: Sun, 01 Jan 2040 00:00:00 GMT
HTTP 200
[Asserts]
jsonpath "$.data" count == 9
