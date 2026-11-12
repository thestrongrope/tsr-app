# GET /search contract up to the index: sign-in, the numeric gender check (400), q and kinds (422), what a caller with no way in to a kind gets (no group), and the "index cannot be reached" answer.
# Neither test stack has Elasticsearch (PHP: ELASTICSEARCH_URL is not set; the new API: TSR_ELASTICSEARCH_URL is not set), so every kind a caller may search is in `unavailable` and the others are left out.
# What the index returns and what the re-check keeps is proved on the new API with a fake index in db/tests/TestEdgeSearchTests.cs. Runs against any implementation.
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

# 5. The text and the kinds are values, never query syntax: nothing breaks, the answer is the unavailable one
GET {{base_url}}/search?q=*%3A*%20OR%20%22x%22%20AND%20(a)%5B1%5D%5C
Authorization: {{auth_edge_search}}
HTTP 200
[Asserts]
jsonpath "$.groups" count == 0
jsonpath "$.unavailable" count == 5

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

# 10. A NUL at either end of q is trimmed, as PHP trim does: that text is "ab"
GET {{base_url}}/search?q=ab%00
Authorization: {{auth_edge_search}}
HTTP 200
[Asserts]
jsonpath "$.unavailable" count == 5
