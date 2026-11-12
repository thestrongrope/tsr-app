# GET /search contract that holds with or without an index: sign-in, the numeric gender check (400), q and kinds (422), and what a caller with no way in to a kind gets (no group, never "unavailable").
# What the answer is WITHOUT an index (every kind a caller may search is in `unavailable`) is in search-php-only.hurl: the PHP parity stack has no Elasticsearch.
# What it is WITH one is in search-new-api.hurl: the default test stack runs Elasticsearch and the search-feed worker. The re-check of each hit is proved with a fake index in db/tests/TestEdgeSearchTests.cs.
# Variables: base_url, auth_edge_search (super admin), auth_edge_gents (gents admin), auth_edge_plain (no role), auth_edge_nogender (no gender stored).
# 1. Without sign-in: 401
GET {{base_url}}/search?q=edge
HTTP 401

# 2. A stored gender that is not a number is 400, before the permission and the text are looked at
GET {{base_url}}/search?q=edge
Authorization: {{auth_edge_nogender}}
HTTP 400
[Asserts]
jsonpath "$.detail" == "User gender not set; update profile first"

GET {{base_url}}/search
Authorization: {{auth_edge_nogender}}
HTTP 400

# 3. q: trimmed, 2 to 100 characters
GET {{base_url}}/search?q=e
Authorization: {{auth_edge_search}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "q must be at least 2 characters"

GET {{base_url}}/search
Authorization: {{auth_edge_search}}
HTTP 422

GET {{base_url}}/search?q=%20%20e%20%20
Authorization: {{auth_edge_search}}
HTTP 422

GET {{base_url}}/search?q=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
Authorization: {{auth_edge_search}}
HTTP 422
[Asserts]
jsonpath "$.detail" matches /100/

# 4. kinds: a comma list of class, teacher, guide, student, subscriber; anything else is 422
GET {{base_url}}/search?q=edge&kinds=nope
Authorization: {{auth_edge_search}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "kinds must be a list of class, teacher, guide, student, subscriber"

GET {{base_url}}/search?q=edge&kinds=class,nope
Authorization: {{auth_edge_search}}
HTTP 422

GET {{base_url}}/search?q=edge&kinds=Class
Authorization: {{auth_edge_search}}
HTTP 422

# 6. A kind list that is only "0" or "," is an empty answer, not a 422
GET {{base_url}}/search?q=edge&kinds=0
Authorization: {{auth_edge_search}}
HTTP 200
[Asserts]
jsonpath "$.groups" count == 0
jsonpath "$.unavailable" count == 0

GET {{base_url}}/search?q=edge&kinds=,
Authorization: {{auth_edge_search}}
HTTP 200
[Asserts]
jsonpath "$.unavailable" count == 0

# 8. A gents admin has no way in to subscribers (super admin only): asking for that kind alone is an empty answer, never unavailable
GET {{base_url}}/search?q=edge&kinds=subscriber
Authorization: {{auth_edge_gents}}
HTTP 200
[Asserts]
jsonpath "$.unavailable" count == 0

# 9. A plain member with no class has no way in to any kind: nothing is asked, nothing is unavailable
GET {{base_url}}/search?q=edge
Authorization: {{auth_edge_plain}}
HTTP 200
[Asserts]
jsonpath "$.groups" count == 0
jsonpath "$.unavailable" count == 0
