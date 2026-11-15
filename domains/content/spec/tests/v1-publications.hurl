# GET /api/v1/publications contract: the publications of the publications page in file order, with links relative to the website, in the answer shape of today's website.
# Public: no sign-in. Data: the synthetic content files of db/synthetic/content (its README.md maps them to these cases): 4 entries, 3 with a link.
# Cases: TC-LIB-R1-01, R15-01, R19-01 of docs/specs/website-port/f1-plan-draft.md.
# Variable: base_url. Run through tools/contract-website.sh test, which first waits for the content to be loaded.

# 1. TC-LIB-R1-01, R15-01, R19-01: no sign-in; 3 in file order (the entry with neither link is dropped); relative links that name no host
GET {{base_url}}/api/v1/publications
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
jsonpath "$.pagination.total" == 3
jsonpath "$.pagination.limit" == 3
jsonpath "$.pagination.offset" == 0
jsonpath "$.pagination.hasMore" == false
jsonpath "$.data" count == 3
jsonpath "$.data[0].title" == "A Pocket Guide to Margin Notes"
jsonpath "$.data[0].summary" == "A short invented booklet on writing notes beside a text."
jsonpath "$.data[0].type" == "PDF"
jsonpath "$.data[0].size" == "1 MB"
jsonpath "$.data[0].updated" == "Jun 26, 2025"
jsonpath "$.data[0].language" == "English"
jsonpath "$.data[0].file" == "/downloads/sample-publications/a-pocket-guide-to-margin-notes.pdf"
# A field the file lacks is left out, not null.
jsonpath "$.data[0].readOnlineUrl" not exists
jsonpath "$.data[0].downloadOnly" == true
jsonpath "$.data[0].*" count == 8
jsonpath "$.data[1].title" == "ہفتہ وار منصوبہ کی کتاب"
jsonpath "$.data[1].language" == "Urdu"
jsonpath "$.data[1].file" == "/downloads/sample-publications/weekly-plan-booklet.pdf"
jsonpath "$.data[1].readOnlineUrl" == "/weekly-plan-booklet"
jsonpath "$.data[1].downloadOnly" == false
jsonpath "$.data[1].*" count == 9
jsonpath "$.data[2].title" == "Revision Cycles Handbook"
jsonpath "$.data[2].type" == "Web"
jsonpath "$.data[2].file" not exists
jsonpath "$.data[2].readOnlineUrl" == "/revision-cycles-handbook"
jsonpath "$.data[2].*" count == 8
jsonpath "$.data[*].title" not contains "A Booklet With No Link"
# Every link there is starts with one "/" and names no host.
jsonpath "$.data[*].file" count == 2
jsonpath "$.data[0].file" matches /^\/[^\/:]+(\/[^\/:]+)*$/
jsonpath "$.data[1].file" matches /^\/[^\/:]+(\/[^\/:]+)*$/
jsonpath "$.data[1].readOnlineUrl" matches /^\/[^\/:]+$/
jsonpath "$.data[2].readOnlineUrl" matches /^\/[^\/:]+$/
# The kinds.
jsonpath "$.data[1].title" isString
jsonpath "$.data[1].summary" isString
jsonpath "$.data[1].type" isString
jsonpath "$.data[1].size" isString
jsonpath "$.data[1].updated" isString
jsonpath "$.data[1].language" isString
jsonpath "$.data[1].file" isString
jsonpath "$.data[1].readOnlineUrl" isString
jsonpath "$.data[1].downloadOnly" isBoolean

# 2. One language, the whole word in any case
GET {{base_url}}/api/v1/publications
[Query]
language: english
HTTP 200
[Asserts]
jsonpath "$.data" count == 2
jsonpath "$.data[0].title" == "A Pocket Guide to Margin Notes"
jsonpath "$.data[1].title" == "Revision Cycles Handbook"
jsonpath "$.pagination.total" == 2
jsonpath "$.pagination.limit" == 2
jsonpath "$.pagination.hasMore" == false

# 3. Part of a language matches nothing: still 200, an empty list
GET {{base_url}}/api/v1/publications
[Query]
language: Eng
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.data" count == 0
jsonpath "$.pagination.total" == 0
jsonpath "$.pagination.limit" == 0

# 4. Other options are ignored: there is no paging
GET {{base_url}}/api/v1/publications
[Query]
limit: 1
offset: 2
HTTP 200
[Asserts]
jsonpath "$.data" count == 3
header "ETag" == "{{etag}}"

# 5. Not changed since the ETag of request 1: 304 with no body
GET {{base_url}}/api/v1/publications
If-None-Match: {{etag}}
HTTP 304
[Asserts]
bytes count == 0

# 6. Another ETag gets the whole answer
GET {{base_url}}/api/v1/publications
If-None-Match: "0123456789abcdef0123456789abcdef"
HTTP 200
[Asserts]
jsonpath "$.data" count == 3
