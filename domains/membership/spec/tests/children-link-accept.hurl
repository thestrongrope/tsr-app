# POST /me/children/link/{code} contract: one file per slice, runs against any implementation.
# Variables: base_url and auth_<alias>. Synthetic members only. It consumes invites: tools/membership-contract.sh resets them first.
# Fixtures: accept.parent (900231) accepts the live invites c101, c102, c103 (made by the child, the child, accept.parent) of accept.child (900241),
# c104 of accept.child.removed (900242, whom accept.parent was once linked to until the child ended it), c105 of 900207 (a token two members hold).

# 1. Without sign-in: 401
POST {{base_url}}/me/children/link/c1c1c1c1c1c1c1c1c1c1c1c1c1c1c101
Content-Type: application/json
{"relationship": "father"}
HTTP 401

# 2. A body that is not JSON: 422, before the code is looked up
POST {{base_url}}/me/children/link/no-such-code
Authorization: {{auth_accept_parent}}
Content-Type: application/json
`not json`
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

# 3. Unknown code 404; an expired invite 410 (before the relationship is looked at)
POST {{base_url}}/me/children/link/no-such-code
Authorization: {{auth_accept_parent}}
Content-Type: application/json
{"relationship": "father"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Invite not found"

POST {{base_url}}/me/children/link/0f8e7d6c5b4a39281706f5e4d3c2b1a0
Authorization: {{auth_accept_parent}}
Content-Type: application/json
{"relationship": "nonsense"}
HTTP 410
[Asserts]
jsonpath "$.detail" == "This link has expired or has already been used"

# 4. Every 422 carries the one text: a bad or missing relationship, the child accepting their own invite, the invite's maker accepting it,
#    a child whose token two members hold, a caller whose token two members hold
POST {{base_url}}/me/children/link/c1c1c1c1c1c1c1c1c1c1c1c1c1c1c101
Authorization: {{auth_accept_parent}}
Content-Type: application/json
{"relationship": "uncle"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid relationship or self-link not allowed"

POST {{base_url}}/me/children/link/c1c1c1c1c1c1c1c1c1c1c1c1c1c1c101
Authorization: {{auth_accept_parent}}
Content-Type: application/json
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid relationship or self-link not allowed"

POST {{base_url}}/me/children/link/c1c1c1c1c1c1c1c1c1c1c1c1c1c1c101
Authorization: {{auth_accept_child}}
Content-Type: application/json
{"relationship": "father"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid relationship or self-link not allowed"

POST {{base_url}}/me/children/link/c1c1c1c1c1c1c1c1c1c1c1c1c1c1c103
Authorization: {{auth_accept_parent}}
Content-Type: application/json
{"relationship": "father"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid relationship or self-link not allowed"

POST {{base_url}}/me/children/link/c1c1c1c1c1c1c1c1c1c1c1c1c1c1c105
Authorization: {{auth_accept_parent}}
Content-Type: application/json
{"relationship": "father"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid relationship or self-link not allowed"

POST {{base_url}}/me/children/link/c1c1c1c1c1c1c1c1c1c1c1c1c1c1c102
Authorization: {{auth_shared_one}}
Content-Type: application/json
{"relationship": "father"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid relationship or self-link not allowed"

# 5. A parent the child ended returns only through an admin's invite: 403
POST {{base_url}}/me/children/link/c1c1c1c1c1c1c1c1c1c1c1c1c1c1c104
Authorization: {{auth_accept_parent}}
Content-Type: application/json
{"relationship": "father"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This person was removed by the child; ask an admin for a new link"

# 6. A live invite is accepted: the relationship is trimmed and lower-cased, and the answer is exactly three fields
POST {{base_url}}/me/children/link/c1c1c1c1c1c1c1c1c1c1c1c1c1c1c101
Authorization: {{auth_accept_parent}}
Content-Type: application/json
{"relationship": "  Father "}
HTTP 200
[Asserts]
jsonpath "$.child_token" == 900241
jsonpath "$.relationship" == "father"
jsonpath "$.status" == "active"

# 7. The link now exists for both sides, shown as made by an invite link
GET {{base_url}}/me/children/links
Authorization: {{auth_accept_parent}}
HTTP 200
[Asserts]
jsonpath "$[?(@.child_token==900241)].status" == "active"
jsonpath "$[?(@.child_token==900241)].source" == "link"
jsonpath "$[?(@.child_token==900241)].created_by_name" == "Invite link"
jsonpath "$[?(@.child_token==900241)].child_name" == "Synthetic Accept Child"

GET {{base_url}}/me/parents
Authorization: {{auth_accept_child}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].parent_name" == "Synthetic Accept Parent"

# 8. The same invite again is used (410); a second invite for a pair that is already linked is a 409
POST {{base_url}}/me/children/link/c1c1c1c1c1c1c1c1c1c1c1c1c1c1c101
Authorization: {{auth_accept_parent}}
Content-Type: application/json
{"relationship": "father"}
HTTP 410
[Asserts]
jsonpath "$.detail" == "This link has expired or has already been used"

POST {{base_url}}/me/children/link/c1c1c1c1c1c1c1c1c1c1c1c1c1c1c102
Authorization: {{auth_accept_parent}}
Content-Type: application/json
{"relationship": "mother"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "An active link already exists for this parent and child"
