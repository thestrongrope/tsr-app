# The deletion gate: a member with a live deletion request may call only an allow list of routes (health, /auth/link, /auth/debug-token, GET /me, the three /me/deletion-request routes, DELETE /devices) and is
# refused everywhere else with 403 {"detail": "Account deletion pending", "deletion_status": ...}. Runs against any implementation.
# Variables: base_url, auth_deletion_gate (member 924005 with the live request 9740005; this file cancels it and the fixture reload brings it back), auth_deletion_flow is NOT used here.
# Fixtures: db/synthetic/deletion-fixtures.sql (tools/contract-deletion.sh).

# 1. The pending member can read their request and their own profile
GET {{base_url}}/me/deletion-request
Authorization: {{auth_deletion_gate}}
HTTP 200
[Asserts]
jsonpath "$.id" == 9740005
jsonpath "$.status" == "pending"

GET {{base_url}}/me
Authorization: {{auth_deletion_gate}}
HTTP 200

# 2. Everywhere else is refused with PHP's body, whatever the method
POST {{base_url}}/feedback
Authorization: {{auth_deletion_gate}}
{"clientId": "c-deletion-gate-1", "text": "salaam"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Account deletion pending"
jsonpath "$.deletion_status" == "pending"

PATCH {{base_url}}/me
Authorization: {{auth_deletion_gate}}
{"city": "Nowhere"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Account deletion pending"
jsonpath "$.deletion_status" == "pending"

GET {{base_url}}/me/permissions
Authorization: {{auth_deletion_gate}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Account deletion pending"

GET {{base_url}}/admin/deletion-requests
Authorization: {{auth_deletion_gate}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Account deletion pending"

POST {{base_url}}/admin/deletion-requests/9740005/complete
Authorization: {{auth_deletion_gate}}
Content-Length: 0
HTTP 403
[Asserts]
jsonpath "$.detail" == "Account deletion pending"

# 3. A held request blocks the same way and carries its own status
# (not repeated here: the status word is taken from the request; admin-deletion-hold.hurl holds one)

# 4. Withdrawing the request lifts the block
DELETE {{base_url}}/me/deletion-request
Authorization: {{auth_deletion_gate}}
HTTP 200
[Asserts]
jsonpath "$.status" == "cancelled"

GET {{base_url}}/me/permissions
Authorization: {{auth_deletion_gate}}
HTTP 200
