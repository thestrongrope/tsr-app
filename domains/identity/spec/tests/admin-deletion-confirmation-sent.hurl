# POST /admin/deletion-requests/{id}/confirmation-sent contract: record that the member was sent the confirmation. Runs against any implementation.
# Variables: base_url, auth_deletion_admin (924001), auth_deletion_plain (924002, no permission). Fixtures: db/synthetic/deletion-fixtures.sql: 9740031 pending unconfirmed (member 924031), 9740032 cancelled.
# This file stamps 9740031 (the reload restores it).

# 1. Without sign-in: 401. Without the permission: 403 for a real id and one that does not exist alike
POST {{base_url}}/admin/deletion-requests/9740031/confirmation-sent
Content-Length: 0
HTTP 401

POST {{base_url}}/admin/deletion-requests/9740031/confirmation-sent
Authorization: {{auth_deletion_plain}}
Content-Length: 0
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/admin/deletion-requests/99999999/confirmation-sent
Authorization: {{auth_deletion_plain}}
Content-Length: 0
HTTP 403

# 2. An id that is no request: 404
POST {{base_url}}/admin/deletion-requests/99999999/confirmation-sent
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 404
[Asserts]
jsonpath "$.detail" == "Deletion request not found"

POST {{base_url}}/admin/deletion-requests/0/confirmation-sent
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 404

# 3. A settled request cannot take one: 409
POST {{base_url}}/admin/deletion-requests/9740032/confirmation-sent
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 409
[Asserts]
jsonpath "$.detail" == "This request is settled and cannot take a confirmation"

# 4. Before the stamp the confirmation text is on offer and the request cannot be completed
GET {{base_url}}/admin/deletion-requests?status=pending
Authorization: {{auth_deletion_admin}}
HTTP 200
[Asserts]
jsonpath "$.requests[?(@.id==9740031)].confirmation.to" == "dl.924031@example.invalid"
jsonpath "$.requests[?(@.id==9740031)].can_complete" == false

# 5. Stamping: 200; the text goes away, the request can be completed, the operator is recorded
POST {{base_url}}/admin/deletion-requests/9740031/confirmation-sent
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 200
[Captures]
first_stamp: jsonpath "$.request.confirmation_sent_at"
[Asserts]
jsonpath "$.request.id" == 9740031
jsonpath "$.request.status" == "pending"
jsonpath "$.request.confirmation_sent_at" matches "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$"
jsonpath "$.request.confirmation" == null
jsonpath "$.request.can_complete" == true
jsonpath "$.request.handled_by" == 924001
jsonpath "$.request.handled_by_name" == "Dl Member 924001"
jsonpath "$.request.*" count == 19
jsonpath "$.status" not exists

# 6. A second send answers 200 and keeps the first time
POST {{base_url}}/admin/deletion-requests/9740031/confirmation-sent
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 200
[Asserts]
jsonpath "$.request.confirmation_sent_at" == {{first_stamp}}
jsonpath "$.request.can_complete" == true
