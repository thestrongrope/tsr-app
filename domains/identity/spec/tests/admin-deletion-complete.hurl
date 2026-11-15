# POST /admin/deletion-requests/{id}/complete contract: every refusal of the irreversible route, and the one completion PHP's parity stack can run (a request naming no member: nothing to delete, no Firebase call).
# Runs against any implementation. A completion with a member (Firebase, anonymising) is in admin-deletion-complete-new-api.hurl (new API: Firebase in emulator mode) and -php-only.hurl (PHP: no service account).
# Variables: base_url, auth_deletion_admin (924001), auth_deletion_plain (924002, no permission), deletion_req_0 to deletion_req_6 (fixture request ids that change every two seconds because the route's rate limit holds
# a request id for 60 seconds, even after a refusal). Fixtures: db/synthetic/deletion-fixtures.sql: 0 names no member, confirmed   1 member 924042, not confirmed   2 completed   3 cancelled
# 4 demo member 924045, confirmed   5 token 924046 with no user row, confirmed   6 the guest token 0, confirmed.

# 1. Without sign-in: 401. Without the permission: 403 before anything is looked up (a real id and an id that does not exist alike)
POST {{base_url}}/admin/deletion-requests/{{deletion_req_1}}/complete
Content-Length: 0
HTTP 401

POST {{base_url}}/admin/deletion-requests/{{deletion_req_1}}/complete
Authorization: {{auth_deletion_plain}}
Content-Length: 0
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/admin/deletion-requests/99999999/complete
Authorization: {{auth_deletion_plain}}
Content-Length: 0
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. An id that is no request: 404 (the id is read as a number, as PHP does)
POST {{base_url}}/admin/deletion-requests/99999999/complete
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 404
[Asserts]
jsonpath "$.detail" == "Deletion request not found"

POST {{base_url}}/admin/deletion-requests/abc/complete
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 404
[Asserts]
jsonpath "$.detail" == "Deletion request not found"

POST {{base_url}}/admin/deletion-requests/0/complete
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 404

# 3. The guest user (token 0) is not a member: 409 before the rate limit and before Firebase
POST {{base_url}}/admin/deletion-requests/{{deletion_req_6}}/complete
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 409
[Asserts]
jsonpath "$.detail" == "This request names no member and cannot be completed"

# 4. The model's refusals, each 409 with its own text
POST {{base_url}}/admin/deletion-requests/{{deletion_req_1}}/complete
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 409
[Asserts]
jsonpath "$.detail" == "Send the confirmation email and record it before completing this request"

POST {{base_url}}/admin/deletion-requests/{{deletion_req_2}}/complete
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 409
[Asserts]
jsonpath "$.detail" == "Deletion request {{deletion_req_2}} is already completed and cannot be completed"

POST {{base_url}}/admin/deletion-requests/{{deletion_req_3}}/complete
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 409
[Asserts]
jsonpath "$.detail" == "Deletion request {{deletion_req_3}} is already cancelled and cannot be completed"

POST {{base_url}}/admin/deletion-requests/{{deletion_req_4}}/complete
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 409
[Asserts]
jsonpath "$.detail" == "Deletion request {{deletion_req_4}} belongs to the reviewer demo cohort and cannot be completed. Completing it would delete the account an app-store reviewer signs in with. Cancel it instead, or run the cohort teardown when the review is finished."

POST {{base_url}}/admin/deletion-requests/{{deletion_req_5}}/complete
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 409
[Asserts]
jsonpath "$.detail" == "Deletion request {{deletion_req_5}} names token 924046, which has no user row. Check whether a Firebase account still exists for it before closing this request."

# 5. A refusal holds the request's key for a minute: asking again at once is the rate-limit answer, not the refusal again
POST {{base_url}}/admin/deletion-requests/{{deletion_req_1}}/complete
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 409
[Asserts]
jsonpath "$.detail" == "This request was just completed or is being completed. Wait a minute and reload."

# 6. The refusals changed nothing: the requests are as they were
GET {{base_url}}/admin/deletion-requests?status=pending
Authorization: {{auth_deletion_admin}}
HTTP 200
[Asserts]
jsonpath "$.requests[?(@.id=={{deletion_req_1}})].status" == "pending"
jsonpath "$.requests[?(@.id=={{deletion_req_4}})].status" == "pending"
jsonpath "$.requests[?(@.id=={{deletion_req_5}})].status" == "pending"

# 7. A request naming no member completes: 200, the request is completed by this administrator, the dates are set
POST {{base_url}}/admin/deletion-requests/{{deletion_req_0}}/complete
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 200
[Asserts]
jsonpath "$.request.id" == {{deletion_req_0}}
jsonpath "$.request.status" == "completed"
jsonpath "$.request.token" == null
jsonpath "$.request.handled_by" == 924001
jsonpath "$.request.completed_at" matches "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$"
jsonpath "$.request.can_complete" == false
jsonpath "$.request.confirmation" == null
jsonpath "$.request.*" count == 19

# 8. Completing it again at once: the rate-limit 409 (and a minute later, the "already completed" 409)
POST {{base_url}}/admin/deletion-requests/{{deletion_req_0}}/complete
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 409
[Asserts]
jsonpath "$.detail" == "This request was just completed or is being completed. Wait a minute and reload."

GET {{base_url}}/admin/deletion-requests?status=completed
Authorization: {{auth_deletion_admin}}
HTTP 200
[Asserts]
jsonpath "$.requests[?(@.id=={{deletion_req_0}})].status" == "completed"
