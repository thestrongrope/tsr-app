# GET /members/{child_token}/parent-links contract: the caller's own unused, unexpired invites for a child, newest first. Variables: base_url and auth_<alias>.
# Fixtures: child 901113 has 951221 (live, by 901101), 951222 (expired, by 901101), 951223 (live, by 901104), 951224 (no expiry, by 901105). Nothing here changes a row.

# 1. Without sign-in: 401
GET {{base_url}}/members/901113/parent-links
HTTP 401

# 2. A creator sees only their own live invite (the expired one and another creator's are left out), without the code
GET {{base_url}}/members/901113/parent-links
Authorization: {{auth_b4b_invite_admin}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].id" == 951221
jsonpath "$[0].created_at" == "2026-01-10 09:00:00"
jsonpath "$[0].expires_at" matches /^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/
jsonpath "$[0].code" not exists

# 3. An invite with no expiry never expires and shows an empty expires_at (PHP casts null to a string)
GET {{base_url}}/members/901113/parent-links
Authorization: {{auth_b4b_cancel_manager}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].id" == 951224
jsonpath "$[0].expires_at" == ""

# 4. A staff member who created none gets an empty list
GET {{base_url}}/members/901113/parent-links
Authorization: {{auth_b4b_direct_admin}}
HTTP 200
[Asserts]
body == "[]"

# 5. A member with no staff permission: 403; a token of 0: 404 first; an unknown child, for staff: 404
GET {{base_url}}/members/901113/parent-links
Authorization: {{auth_b4b_plain}}
HTTP 403

GET {{base_url}}/members/0/parent-links
Authorization: {{auth_b4b_plain}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Student not found"

GET {{base_url}}/members/999999999/parent-links
Authorization: {{auth_b4b_invite_admin}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Student not found"
