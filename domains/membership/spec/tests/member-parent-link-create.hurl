# POST /members/{child_token}/parent-links contract: a one-time invite made by staff in reach (parents:add) or by the child (parents:manage).
# Variables: base_url and auth_<alias>. Every POST carries an empty JSON body: through the gateway a POST with no Content-Length at all is answered 400 before the API sees it (also on routes built earlier). Fixtures: children 901111 (no invites), 901112 (5 live invites), 901114 (a student acting for themselves). The invite code is never asserted, only its shape.

# 1. Without sign-in: 401
POST {{base_url}}/members/901111/parent-links
Content-Type: application/json
{}
HTTP 401

# 2. Staff in reach create an invite: 201 with a 32-character code, link and url the same, and an expiry
POST {{base_url}}/members/901111/parent-links
Authorization: {{auth_b4b_invite_admin}}
Content-Type: application/json
{}
HTTP 201
[Captures]
invite_link: jsonpath "$.link"
[Asserts]
jsonpath "$.code" matches /^[0-9a-f]{32}$/
jsonpath "$.link" matches /\/link\/[0-9a-f]{32}$/
jsonpath "$.url" == {{invite_link}}
jsonpath "$.expires_at" matches /^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/

# 3. It is one of the creator's unused invites, and the answer never carries the code
GET {{base_url}}/members/901111/parent-links
Authorization: {{auth_b4b_invite_admin}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].id" isInteger
jsonpath "$[0].code" not exists

# 4. A student creates for themselves
POST {{base_url}}/members/901114/parent-links
Authorization: {{auth_b4b_self_child}}
Content-Type: application/json
{}
HTTP 201
[Asserts]
jsonpath "$.code" matches /^[0-9a-f]{32}$/

# 5. A member with no staff permission, for another child: 403
POST {{base_url}}/members/901111/parent-links
Authorization: {{auth_b4b_plain}}
Content-Type: application/json
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 6. A token of 0 is a missing student before any permission is asked: 404, for staff and for a member with no permission alike
POST {{base_url}}/members/0/parent-links
Authorization: {{auth_b4b_plain}}
Content-Type: application/json
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Student not found"

# 7. An unknown child, for staff: 404
POST {{base_url}}/members/999999999/parent-links
Authorization: {{auth_b4b_invite_admin}}
Content-Type: application/json
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Student not found"

# 8. A token held by two members is not one registered member: 404
POST {{base_url}}/members/901153/parent-links
Authorization: {{auth_b4b_invite_admin}}
Content-Type: application/json
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Student not found"

# 9. A child with five live invites cannot have another: 422
POST {{base_url}}/members/901112/parent-links
Authorization: {{auth_b4b_invite_admin}}
Content-Type: application/json
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "At most 5 pending invites allowed"
