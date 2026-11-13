# GET /api/v1/taxonomies/categories contract: the category tree with each category's count of published articles, in the answer shape of today's website.
# Public: no sign-in. Data: the synthetic content files of db/synthetic/content (its README.md maps them to these cases): 3 parents, 4 children.
# Cases: TC-LIB-R1-01, R13-01, R19-01 of docs/specs/website-port/f1-plan-draft.md.
# Variable: base_url. Run through tools/contract-website.sh test, which first waits for the content to be loaded.

# 1. TC-LIB-R1-01, R13-01, R19-01: no sign-in; 3 parents in order, each with its children and its own count
GET {{base_url}}/api/v1/taxonomies/categories
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
jsonpath "$.data" count == 3
jsonpath "$.data[0].slug" == "foundations"
jsonpath "$.data[0].title" == "Foundations"
jsonpath "$.data[0].description" == "Basic ideas every student starts with"
jsonpath "$.data[0].order" == 1
jsonpath "$.data[0].parent" not exists
jsonpath "$.data[0].articleCount" == 2
jsonpath "$.data[0].subcategories" count == 1
jsonpath "$.data[0].subcategories[0].slug" == "core-terms"
jsonpath "$.data[0].subcategories[0].title" == "Core Terms"
jsonpath "$.data[0].subcategories[0].order" == 4
jsonpath "$.data[0].subcategories[0].parent" == "foundations"
jsonpath "$.data[0].subcategories[0].articleCount" == 2
jsonpath "$.data[0].subcategories[0].description" not exists
jsonpath "$.data[0].subcategories[0].subcategories" not exists
# A parent's count is of the articles filed under its own slug, not its children's: 3, never 7. The two drafts filed here and under its children are not counted.
jsonpath "$.data[1].slug" == "practice"
jsonpath "$.data[1].order" == 2
jsonpath "$.data[1].articleCount" == 3
jsonpath "$.data[1].subcategories" count == 2
jsonpath "$.data[1].subcategories[0].slug" == "note-taking"
jsonpath "$.data[1].subcategories[0].articleCount" == 2
jsonpath "$.data[1].subcategories[1].slug" == "revision-plans"
jsonpath "$.data[1].subcategories[1].articleCount" == 2
jsonpath "$.data[2].slug" == "history"
jsonpath "$.data[2].order" == 3
jsonpath "$.data[2].articleCount" == 2
jsonpath "$.data[2].subcategories" count == 1
jsonpath "$.data[2].subcategories[0].slug" == "early-schools"
jsonpath "$.data[2].subcategories[0].articleCount" == 2
# The fields the app reads, and their kinds.
jsonpath "$.data[*].slug" count == 3
jsonpath "$.data[*].title" count == 3
jsonpath "$.data[*].order" count == 3
jsonpath "$.data[*].articleCount" count == 3
jsonpath "$.data[*].subcategories" count == 3
jsonpath "$.data[1].slug" isString
jsonpath "$.data[1].title" isString
jsonpath "$.data[1].description" isString
jsonpath "$.data[1].order" isInteger
jsonpath "$.data[1].articleCount" isInteger
jsonpath "$.data[1].subcategories" isCollection
jsonpath "$.data[1].subcategories[0].slug" isString
jsonpath "$.data[1].subcategories[0].parent" isString
jsonpath "$.data[1].subcategories[0].articleCount" isInteger

# 2. TC-LIB-R13-01: flat: all 7 in order, a child naming its parent, no nesting
GET {{base_url}}/api/v1/taxonomies/categories
[Query]
hierarchical: false
HTTP 200
[Asserts]
jsonpath "$.data" count == 7
jsonpath "$.data[0].slug" == "foundations"
jsonpath "$.data[1].slug" == "practice"
jsonpath "$.data[2].slug" == "history"
jsonpath "$.data[3].slug" == "core-terms"
jsonpath "$.data[4].slug" == "note-taking"
jsonpath "$.data[5].slug" == "revision-plans"
jsonpath "$.data[6].slug" == "early-schools"
jsonpath "$.data[6].order" == 7
jsonpath "$.data[6].parent" == "history"
jsonpath "$.data[6].articleCount" == 2
jsonpath "$.data[1].articleCount" == 3
jsonpath "$.data[1].parent" not exists
jsonpath "$.data[*].subcategories" not exists
header "ETag" != "{{etag}}"

# 3. Only the exact text "false" switches the tree off: another case leaves it on
GET {{base_url}}/api/v1/taxonomies/categories
[Query]
hierarchical: FALSE
HTTP 200
[Asserts]
jsonpath "$.data" count == 3
header "ETag" == "{{etag}}"

# 4. Nor does 0, nor an empty value
GET {{base_url}}/api/v1/taxonomies/categories?hierarchical=0&includeArticleCounts=
HTTP 200
[Asserts]
jsonpath "$.data" count == 3
jsonpath "$.data[1].articleCount" == 3
header "ETag" == "{{etag}}"

# 5. Without counts: every count is 0 and still sent, the children's too
GET {{base_url}}/api/v1/taxonomies/categories
[Query]
includeArticleCounts: false
HTTP 200
[Asserts]
jsonpath "$.data" count == 3
jsonpath "$.data[*].articleCount" count == 3
jsonpath "$.data[?(@.articleCount == 0)]" count == 3
jsonpath "$.data[1].subcategories" count == 2
jsonpath "$.data[1].subcategories[0].articleCount" == 0
jsonpath "$.data[1].subcategories[1].articleCount" == 0
header "ETag" != "{{etag}}"

# 6. Counts stay on for any other value
GET {{base_url}}/api/v1/taxonomies/categories
[Query]
includeArticleCounts: no
HTTP 200
[Asserts]
jsonpath "$.data[1].articleCount" == 3
header "ETag" == "{{etag}}"

# 7. Both options off
GET {{base_url}}/api/v1/taxonomies/categories
[Query]
hierarchical: false
includeArticleCounts: false
HTTP 200
[Asserts]
jsonpath "$.data" count == 7
jsonpath "$.data[?(@.articleCount == 0)]" count == 7

# 8. Options the route does not use are ignored
GET {{base_url}}/api/v1/taxonomies/categories
[Query]
limit: 1
nonsense: 1
HTTP 200
[Asserts]
jsonpath "$.data" count == 3
header "ETag" == "{{etag}}"

# 9. Not changed since the ETag of request 1: 304 with no body
GET {{base_url}}/api/v1/taxonomies/categories
If-None-Match: {{etag}}
HTTP 304
[Asserts]
bytes count == 0

# 10. The tree's ETag does not match the flat list
GET {{base_url}}/api/v1/taxonomies/categories
If-None-Match: {{etag}}
[Query]
hierarchical: false
HTTP 200
[Asserts]
jsonpath "$.data" count == 7

# 11. There is no Last-Modified on this route, so a date alone never gives a 304
GET {{base_url}}/api/v1/taxonomies/categories
If-Modified-Since: Sun, 01 Jan 2040 00:00:00 GMT
HTTP 200
[Asserts]
jsonpath "$.data" count == 3
