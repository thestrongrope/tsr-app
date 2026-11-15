# PHP only (the parity stack has no Firebase service account; the new API's test stack runs Firebase in emulator mode, where completion succeeds: see admin-deletion-complete-new-api.hurl).
# A completion that reaches the Firebase deleter fails with its message, 409, and leaves the request live and the member untouched: PHP deletes the Firebase account BEFORE it touches the database.
# Variables: base_url, auth_deletion_admin, deletion_req_7 (member 924047, confirmed).

POST {{base_url}}/admin/deletion-requests/{{deletion_req_7}}/complete
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 409
[Asserts]
jsonpath "$.detail" startsWith "Firebase service account not configured"

GET {{base_url}}/admin/deletion-requests?status=pending
Authorization: {{auth_deletion_admin}}
HTTP 200
[Asserts]
jsonpath "$.requests[?(@.id=={{deletion_req_7}})].status" == "pending"
jsonpath "$.requests[?(@.id=={{deletion_req_7}})].member_name" == "Dl Member 924047"
jsonpath "$.requests[?(@.id=={{deletion_req_7}})].can_complete" == true
