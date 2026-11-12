# GET /search with NO index configured: every kind the caller may search is in `unavailable`, the others are left out. PHP only: the parity stack has no Elasticsearch
# (ELASTICSEARCH_URL is not set). The new API answers the same way when TSR_ELASTICSEARCH_URL is not set (unit tests of UnconfiguredSearchIndex, db/tests/TestEdgeSearchTests.cs),
# but its default test stack has an index, so these cases do not run there.
# Variables: base_url, auth_edge_search (super admin), auth_edge_gents (gents admin).

# 5. The text and the kinds are values, never query syntax: nothing breaks, the answer is the unavailable one
GET {{base_url}}/search?q=*%3A*%20OR%20%22x%22%20AND%20(a)%5B1%5D%5C
Authorization: {{auth_edge_search}}
HTTP 200
[Asserts]
jsonpath "$.groups" count == 0
jsonpath "$.unavailable" count == 5

# 7. A super admin may search every kind: with no index all five are unavailable, none is an empty group
GET {{base_url}}/search?q=edge
Authorization: {{auth_edge_search}}
HTTP 200
[Asserts]
header "Content-Type" startsWith "application/json"
jsonpath "$.groups" count == 0
jsonpath "$.unavailable" count == 5
jsonpath "$.unavailable[0]" == "class"
jsonpath "$.unavailable[1]" == "teacher"
jsonpath "$.unavailable[2]" == "guide"
jsonpath "$.unavailable[3]" == "student"
jsonpath "$.unavailable[4]" == "subscriber"

GET {{base_url}}/search?q=edge&kinds=class,teacher
Authorization: {{auth_edge_search}}
HTTP 200
[Asserts]
jsonpath "$.unavailable" count == 2

# 8. A gents admin has no way in to subscribers (super admin only): the kind is left out, not unavailable
GET {{base_url}}/search?q=edge
Authorization: {{auth_edge_gents}}
HTTP 200
[Asserts]
jsonpath "$.groups" count == 0
jsonpath "$.unavailable" count == 4
jsonpath "$.unavailable" not contains "subscriber"

# 10. A NUL at either end of q is trimmed, as PHP trim does: that text is "ab"
GET {{base_url}}/search?q=ab%00
Authorization: {{auth_edge_search}}
HTTP 200
[Asserts]
jsonpath "$.unavailable" count == 5
