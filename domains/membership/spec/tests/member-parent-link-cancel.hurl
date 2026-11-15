# DELETE /members/{child_token}/parent-links/{id} contract: cancel an unused invite. Variables: base_url and auth_<alias>.
# Fixtures: child 901115 has 951231 and 951232 (live, by 901104), 951233 (expired, by 901104), 951234 (already revoked), 951235 (live, by 901104). 901104 is a super admin and the creator; 901105 is a super admin who is not.

# 1. Without sign-in: 401
DELETE {{base_url}}/members/901115/parent-links/951231
HTTP 401

# 2. The creator cancels: 204
DELETE {{base_url}}/members/901115/parent-links/951231
Authorization: {{auth_b4b_cancel_admin}}
HTTP 204

# 3. It is gone: cancelling it again is 404
DELETE {{base_url}}/members/901115/parent-links/951231
Authorization: {{auth_b4b_cancel_admin}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Invite not found"

# 4. Someone who manages parents for the child's gender cancels another creator's invite: 204
DELETE {{base_url}}/members/901115/parent-links/951232
Authorization: {{auth_b4b_cancel_manager}}
HTTP 204

# 5. An expired invite can still be cancelled (PHP does not check the expiry)
DELETE {{base_url}}/members/901115/parent-links/951233
Authorization: {{auth_b4b_cancel_admin}}
HTTP 204

# 6. An invite already revoked is 404
DELETE {{base_url}}/members/901115/parent-links/951234
Authorization: {{auth_b4b_cancel_admin}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Invite not found"

# 7. An invite of another child, or an unknown id: 404
DELETE {{base_url}}/members/901111/parent-links/951235
Authorization: {{auth_b4b_cancel_admin}}
HTTP 404

DELETE {{base_url}}/members/901115/parent-links/999999999
Authorization: {{auth_b4b_cancel_admin}}
HTTP 404

# 8. A member with no staff permission: 403; a token of 0: 404 first
DELETE {{base_url}}/members/901115/parent-links/951235
Authorization: {{auth_b4b_plain}}
HTTP 403

DELETE {{base_url}}/members/0/parent-links/951235
Authorization: {{auth_b4b_plain}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Student not found"

# 9. The one invite nobody cancelled is still the creator's only live invite
GET {{base_url}}/members/901115/parent-links
Authorization: {{auth_b4b_cancel_admin}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].id" == 951235
