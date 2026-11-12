# New API only: a completion that names a member. The test stack runs Firebase in emulator mode (deleting is a no-op), so the whole database part of the completion runs; PHP's parity stack has no service
# account and cannot run it (admin-deletion-complete-php-only.hurl). What a completion erases row by row is proved by db/tests/TestDeletionTests.cs; here: over HTTP, the answer and what the queue then shows.
# Variables: base_url, auth_deletion_admin, deletion_req_8 (member 924048, confirmed, with a device, a feedback and queued messages).

GET {{base_url}}/admin/deletion-requests?status=pending
Authorization: {{auth_deletion_admin}}
HTTP 200
[Asserts]
jsonpath "$.requests[?(@.id=={{deletion_req_8}})].member_name" == "Dl Member 924048"
jsonpath "$.requests[?(@.id=={{deletion_req_8}})].can_complete" == true

POST {{base_url}}/admin/deletion-requests/{{deletion_req_8}}/complete
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 200
[Asserts]
jsonpath "$.request.id" == {{deletion_req_8}}
jsonpath "$.request.status" == "completed"
jsonpath "$.request.token" == 924048
jsonpath "$.request.handled_by" == 924001
jsonpath "$.request.completed_at" matches "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$"
jsonpath "$.request.member_name" == "Deleted member"
jsonpath "$.request.contact_email" == "deleted-924048@deleted.invalid"
jsonpath "$.request.can_complete" == false

# The member's profile is anonymised: the queue shows the placeholder name and address, not what the member gave
GET {{base_url}}/admin/deletion-requests?status=completed
Authorization: {{auth_deletion_admin}}
HTTP 200
[Asserts]
jsonpath "$.requests[?(@.id=={{deletion_req_8}})].member_name" == "Deleted member"
jsonpath "$.requests[?(@.id=={{deletion_req_8}})].contact_email" == "deleted-924048@deleted.invalid"
jsonpath "$.requests[?(@.id=={{deletion_req_8}})].member_zip" == null
jsonpath "$.requests[?(@.id=={{deletion_req_8}})].member_mobile" == null

# Completing it again: the rate-limit answer inside a minute
POST {{base_url}}/admin/deletion-requests/{{deletion_req_8}}/complete
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 409
[Asserts]
jsonpath "$.detail" == "This request was just completed or is being completed. Wait a minute and reload."
