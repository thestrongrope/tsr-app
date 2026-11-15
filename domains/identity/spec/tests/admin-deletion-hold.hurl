# POST /admin/deletion-requests/{id}/hold contract: hold a request for prize delivery, with a note the member reads. Runs against any implementation.
# Variables: base_url, auth_deletion_admin (924001), auth_deletion_plain (924002, no permission). Fixtures: db/synthetic/deletion-fixtures.sql: 9740021 pending (member 924021, zip 411021), 9740022 completed.
# This file changes 9740021 (the reload restores it).

# 1. Without sign-in: 401. Without the permission: 403 for a real id and an id that does not exist alike
POST {{base_url}}/admin/deletion-requests/9740021/hold
Content-Length: 0
HTTP 401

POST {{base_url}}/admin/deletion-requests/9740021/hold
Authorization: {{auth_deletion_plain}}
Content-Length: 0
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/admin/deletion-requests/99999999/hold
Authorization: {{auth_deletion_plain}}
Content-Length: 0
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. An id that is no request: 404
POST {{base_url}}/admin/deletion-requests/99999999/hold
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 404
[Asserts]
jsonpath "$.detail" == "Deletion request not found"

POST {{base_url}}/admin/deletion-requests/abc/hold
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 404
[Asserts]
jsonpath "$.detail" == "Deletion request not found"

# 3. A note that is not text or too long: 422, and nothing changes
POST {{base_url}}/admin/deletion-requests/9740021/hold
Authorization: {{auth_deletion_admin}}
{"note": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "note must be text"

POST {{base_url}}/admin/deletion-requests/9740021/hold
Authorization: {{auth_deletion_admin}}
{"note": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "note must be 500 characters or fewer"

# 4. A request that is settled: 409
POST {{base_url}}/admin/deletion-requests/9740022/hold
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 409
[Asserts]
jsonpath "$.detail" == "This request is no longer live"

# 5. Holding: 200, the status, the trimmed note, who handled it, the member's postal code and mobile (held requests show them)
POST {{base_url}}/admin/deletion-requests/9740021/hold
Authorization: {{auth_deletion_admin}}
{"note": "  Prize is being sent  "}
HTTP 200
[Asserts]
jsonpath "$.request.id" == 9740021
jsonpath "$.request.status" == "awaiting_prize_delivery"
jsonpath "$.request.operator_note" == "Prize is being sent"
jsonpath "$.request.handled_by" == 924001
jsonpath "$.request.handled_by_name" == "Dl Member 924001"
jsonpath "$.request.member_zip" == "411021"
jsonpath "$.request.member_mobile" == "+91000924021"
jsonpath "$.request.*" count == 19
jsonpath "$.status" not exists

# 6. The member now sees the note as the message (the member reads it through their own routes: not signed in as them here, the admin list shows the same state)
GET {{base_url}}/admin/deletion-requests?status=awaiting_prize_delivery
Authorization: {{auth_deletion_admin}}
HTTP 200
[Asserts]
jsonpath "$.requests[?(@.id==9740021)].operator_note" == "Prize is being sent"

# 7. Holding again is allowed and replaces the note; a blank note clears it
POST {{base_url}}/admin/deletion-requests/9740021/hold
Authorization: {{auth_deletion_admin}}
{"note": "Second note"}
HTTP 200
[Asserts]
jsonpath "$.request.operator_note" == "Second note"
jsonpath "$.request.status" == "awaiting_prize_delivery"

POST {{base_url}}/admin/deletion-requests/9740021/hold
Authorization: {{auth_deletion_admin}}
{"note": "   "}
HTTP 200
[Asserts]
jsonpath "$.request.operator_note" == null

POST {{base_url}}/admin/deletion-requests/9740021/hold
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 200
[Asserts]
jsonpath "$.request.operator_note" == null
