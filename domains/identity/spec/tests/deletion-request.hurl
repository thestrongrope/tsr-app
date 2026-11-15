# POST, GET and DELETE /me/deletion-request contract: a member raises, reads and withdraws their own account deletion request. Runs against any implementation.
# Variables: base_url, auth_deletion_flow (member 924003, nobody else uses it), auth_deletion_done (member 924007, whose request completed 5 hours ago: read only here).
# Fixtures: db/synthetic/deletion-fixtures.sql (tools/contract-deletion.sh). Every key is present in every response; absence is null.

# 1. Without sign-in: 401
GET {{base_url}}/me/deletion-request
HTTP 401
[Asserts]
jsonpath "$.detail" == "Not authenticated"

POST {{base_url}}/me/deletion-request
Content-Length: 0
HTTP 401

DELETE {{base_url}}/me/deletion-request
HTTP 401

# 2. Nothing yet: the same shape with status none and nulls
GET {{base_url}}/me/deletion-request
Authorization: {{auth_deletion_flow}}
HTTP 200
[Asserts]
jsonpath "$.id" == null
jsonpath "$.status" == "none"
jsonpath "$.requested_at" == null
jsonpath "$.expected_completion_days" == 60
jsonpath "$.message" == null
jsonpath "$.*" count == 5

# 3. Cancelling with nothing live: 404
DELETE {{base_url}}/me/deletion-request
Authorization: {{auth_deletion_flow}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "No pending deletion request"

# 4. A reason that is not text, or too long, is a 422 and writes nothing
POST {{base_url}}/me/deletion-request
Authorization: {{auth_deletion_flow}}
{"reason": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason must be text"

POST {{base_url}}/me/deletion-request
Authorization: {{auth_deletion_flow}}
{"reason": ["a"]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason must be text"

POST {{base_url}}/me/deletion-request
Authorization: {{auth_deletion_flow}}
{"reason": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason must be 500 characters or fewer"

GET {{base_url}}/me/deletion-request
Authorization: {{auth_deletion_flow}}
HTTP 200
[Asserts]
jsonpath "$.status" == "none"

# 5. The first request is 202 with every key; the pending sentence says 60 days
POST {{base_url}}/me/deletion-request
Authorization: {{auth_deletion_flow}}
{"reason": "  moving on  "}
HTTP 202
[Captures]
request_id: jsonpath "$.id"
[Asserts]
jsonpath "$.status" == "pending"
jsonpath "$.requested_at" matches "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$"
jsonpath "$.expected_completion_days" == 60
jsonpath "$.message" == "Your account will be deleted within 60 days."
jsonpath "$.*" count == 5

# 6. A second request while one is live is 200 with the same request, not a duplicate
POST {{base_url}}/me/deletion-request
Content-Length: 0
Authorization: {{auth_deletion_flow}}
HTTP 200
[Asserts]
jsonpath "$.id" == {{request_id}}
jsonpath "$.status" == "pending"

# 7. Reading shows the live request
GET {{base_url}}/me/deletion-request
Authorization: {{auth_deletion_flow}}
HTTP 200
[Asserts]
jsonpath "$.id" == {{request_id}}
jsonpath "$.status" == "pending"
jsonpath "$.message" == "Your account will be deleted within 60 days."

# 8. Withdrawing it: {status: cancelled}; then the member has the ordinary button back
DELETE {{base_url}}/me/deletion-request
Authorization: {{auth_deletion_flow}}
HTTP 200
[Asserts]
jsonpath "$.status" == "cancelled"
jsonpath "$.id" not exists

GET {{base_url}}/me/deletion-request
Authorization: {{auth_deletion_flow}}
HTTP 200
[Asserts]
jsonpath "$.status" == "none"
jsonpath "$.id" == null

DELETE {{base_url}}/me/deletion-request
Authorization: {{auth_deletion_flow}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "No pending deletion request"

# 9. After a cancellation the member may ask again (a new request, 202); withdraw it so the file can run again
POST {{base_url}}/me/deletion-request
Content-Length: 0
Authorization: {{auth_deletion_flow}}
HTTP 202
[Asserts]
jsonpath "$.id" != {{request_id}}

DELETE {{base_url}}/me/deletion-request
Authorization: {{auth_deletion_flow}}
HTTP 200

# 10. A request that was completed: cancelling is 409, and the completed request is not shown to the member
DELETE {{base_url}}/me/deletion-request
Authorization: {{auth_deletion_done}}
HTTP 409
[Asserts]
jsonpath "$.detail" == "This account has already been deleted and cannot be restored"

GET {{base_url}}/me/deletion-request
Authorization: {{auth_deletion_done}}
HTTP 200
[Asserts]
jsonpath "$.status" == "none"
