# What only the new API does on GET /search: a NUL byte inside q is 422 (PHP answers 200 and puts every kind in `unavailable`: the text goes to the index). New API only.
# Variables: base_url, auth_edge_search (super admin).

GET {{base_url}}/search?q=ab%00cd
Authorization: {{auth_edge_search}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "q must not contain NUL characters"

# The cases below need the index: the default test stack runs Elasticsearch and the search-feed worker, and tools/contract-edge.sh has the worker rebuild the index after it loads
# the fixtures (a lane stack, TSR_STACK=n, has no Elasticsearch and cannot run this file). Fixtures: db/synthetic/edge-fixtures.sql, members named "Edge Member <token>".
# Also needs auth_edge_gents (gents admin).

# A super admin finds the fixture members by the start of a name: no kind is unavailable, every kind has a group, and the people are subscribers (none is enrolled)
GET {{base_url}}/search?q=edge
Authorization: {{auth_edge_search}}
HTTP 200
[Asserts]
jsonpath "$.unavailable" count == 0
jsonpath "$.groups" count == 5
jsonpath "$.groups[0].kind" == "class"
jsonpath "$.groups[4].kind" == "subscriber"
jsonpath "$.groups[4].count" >= 5
jsonpath "$.groups[4].results[0].title" startsWith "Edge Member 927"
jsonpath "$.groups[3].kind" == "student"
jsonpath "$.groups[3].count" == 0

# The text is matched from the start of a word, without regard to case, and a text nothing starts with finds nothing
GET {{base_url}}/search?q=EDGE%20mem&kinds=subscriber
Authorization: {{auth_edge_search}}
HTTP 200
[Asserts]
jsonpath "$.groups[0].count" >= 5

GET {{base_url}}/search?q=zzqxv&kinds=subscriber
Authorization: {{auth_edge_search}}
HTTP 200
[Asserts]
jsonpath "$.unavailable" count == 0
jsonpath "$.groups[0].count" == 0

# A gents admin has no way in to subscribers: that kind has no group, and the same text finds none of the fixture members through another kind
GET {{base_url}}/search?q=edge
Authorization: {{auth_edge_gents}}
HTTP 200
[Asserts]
jsonpath "$.unavailable" count == 0
jsonpath "$.groups" count == 4
jsonpath "$.groups[*].kind" not contains "subscriber"
jsonpath "$.groups[*].count" not contains 1

# The text is a value, never query syntax: a real index answers 200 with nothing found
GET {{base_url}}/search?q=*%3A*%20OR%20%22x%22%20AND%20(a)%5B1%5D%5C
Authorization: {{auth_edge_search}}
HTTP 200
[Asserts]
jsonpath "$.unavailable" count == 0

# A NUL at either end of q is trimmed, as PHP trim does: that text is "ab"
GET {{base_url}}/search?q=ab%00
Authorization: {{auth_edge_search}}
HTTP 200
[Asserts]
jsonpath "$.unavailable" count == 0
