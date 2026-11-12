# GET /admin/deletion-requests contract: the queue an administrator works, with the four counts. Runs against any implementation. Read only.
# Variables: base_url, auth_deletion_admin (924001, role 1), auth_deletion_plain (924002, no permission). Fixtures: db/synthetic/deletion-fixtures.sql. The queue also holds rows other files of this lane write,
# so every assertion names a fixture request by id (9740011 pending unconfirmed, 9740012 held, 9740013 cancelled, 9740014 demo member confirmed, 9740007 completed).

# 1. Without sign-in: 401. A member without deletion-requests:manage: 403, with the same body whatever they ask
GET {{base_url}}/admin/deletion-requests
HTTP 401
[Asserts]
jsonpath "$.detail" == "Not authenticated"

GET {{base_url}}/admin/deletion-requests
Authorization: {{auth_deletion_plain}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/admin/deletion-requests?status=pending
Authorization: {{auth_deletion_plain}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. The counts object always has the four keys, in this order; the queue is a list
GET {{base_url}}/admin/deletion-requests
Authorization: {{auth_deletion_admin}}
HTTP 200
[Asserts]
jsonpath "$.counts.pending" isInteger
jsonpath "$.counts.awaiting_prize_delivery" isInteger
jsonpath "$.counts.completed" isInteger
jsonpath "$.counts.cancelled" isInteger
jsonpath "$.counts.*" count == 4
jsonpath "$.requests" isCollection
jsonpath "$.*" count == 2

# 3. A pending request not yet confirmed: the confirmation text is there, completing is not possible, zip and mobile are hidden
GET {{base_url}}/admin/deletion-requests
Authorization: {{auth_deletion_admin}}
HTTP 200
[Asserts]
jsonpath "$.requests[?(@.id==9740011)].id" == 9740011
jsonpath "$.requests[?(@.id==9740011)].status" == "pending"
jsonpath "$.requests[?(@.id==9740011)].source" == "app"
jsonpath "$.requests[?(@.id==9740011)].token" == 924011
jsonpath "$.requests[?(@.id==9740011)].member_name" == "Dl Member 924011"
jsonpath "$.requests[?(@.id==9740011)].contact_email" == "dl.924011@example.invalid"
jsonpath "$.requests[?(@.id==9740011)].reason" == "leaving soon"
jsonpath "$.requests[?(@.id==9740011)].requested_at" matches "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$"
jsonpath "$.requests[?(@.id==9740011)].confirmation_sent_at" == null
jsonpath "$.requests[?(@.id==9740011)].member_zip" == null
jsonpath "$.requests[?(@.id==9740011)].member_mobile" == null
jsonpath "$.requests[?(@.id==9740011)].is_demo" == false
jsonpath "$.requests[?(@.id==9740011)].can_complete" == false
jsonpath "$.requests[?(@.id==9740011)].confirmation.to" == "dl.924011@example.invalid"
jsonpath "$.requests[?(@.id==9740011)].confirmation.subject" == "Your The Strong Rope account has been deleted"
jsonpath "$.requests[?(@.id==9740011)].confirmation.body" startsWith "Dear Dl Member 924011,\n\nWe have finished deleting your The Strong Rope account, as you asked."

# 4. A held request: the operator's note, who handled it, the member's postal code and mobile
GET {{base_url}}/admin/deletion-requests
Authorization: {{auth_deletion_admin}}
HTTP 200
[Asserts]
jsonpath "$.requests[?(@.id==9740012)].status" == "awaiting_prize_delivery"
jsonpath "$.requests[?(@.id==9740012)].source" == "web"
jsonpath "$.requests[?(@.id==9740012)].operator_note" == "Prize is on its way"
jsonpath "$.requests[?(@.id==9740012)].handled_by" == 924001
jsonpath "$.requests[?(@.id==9740012)].handled_by_name" == "Dl Member 924001"
jsonpath "$.requests[?(@.id==9740012)].member_zip" == "411012"
jsonpath "$.requests[?(@.id==9740012)].member_mobile" == "+91000924012"
jsonpath "$.requests[?(@.id==9740012)].can_complete" == false

# 5. A cancelled and a completed request carry no confirmation text and cannot be completed
GET {{base_url}}/admin/deletion-requests
Authorization: {{auth_deletion_admin}}
HTTP 200
[Asserts]
jsonpath "$.requests[?(@.id==9740013)].status" == "cancelled"
jsonpath "$.requests[?(@.id==9740013)].cancelled_at" matches "^[0-9]{4}-[0-9]{2}-[0-9]{2}T"
jsonpath "$.requests[?(@.id==9740013)].confirmation" == null
jsonpath "$.requests[?(@.id==9740013)].can_complete" == false
jsonpath "$.requests[?(@.id==9740007)].status" == "completed"
jsonpath "$.requests[?(@.id==9740007)].completed_at" matches "^[0-9]{4}-[0-9]{2}-[0-9]{2}T"
jsonpath "$.requests[?(@.id==9740007)].confirmation" == null
jsonpath "$.requests[?(@.id==9740007)].can_complete" == false

# 6. A reviewer demo member: marked, confirmed, and still not completable
GET {{base_url}}/admin/deletion-requests
Authorization: {{auth_deletion_admin}}
HTTP 200
[Asserts]
jsonpath "$.requests[?(@.id==9740014)].is_demo" == true
jsonpath "$.requests[?(@.id==9740014)].confirmation_sent_at" matches "^[0-9]{4}-[0-9]{2}-[0-9]{2}T"
jsonpath "$.requests[?(@.id==9740014)].can_complete" == false
jsonpath "$.requests[?(@.id==9740014)].confirmation" == null

# 7. A status filter keeps only that status; a value that is not a status is no filter
GET {{base_url}}/admin/deletion-requests?status=cancelled
Authorization: {{auth_deletion_admin}}
HTTP 200
[Asserts]
jsonpath "$.requests[?(@.id==9740013)].id" == 9740013
jsonpath "$.requests[?(@.id==9740011)]" not exists
jsonpath "$.requests[?(@.id==9740012)]" not exists
jsonpath "$.counts.*" count == 4

GET {{base_url}}/admin/deletion-requests?status=awaiting_prize_delivery
Authorization: {{auth_deletion_admin}}
HTTP 200
[Asserts]
jsonpath "$.requests[?(@.id==9740012)].id" == 9740012
jsonpath "$.requests[?(@.id==9740013)]" not exists

GET {{base_url}}/admin/deletion-requests?status=bogus
Authorization: {{auth_deletion_admin}}
HTTP 200
[Asserts]
jsonpath "$.requests[?(@.id==9740011)].id" == 9740011
jsonpath "$.requests[?(@.id==9740013)].id" == 9740013

# 8. Every key is present on every request, null where there is nothing
GET {{base_url}}/admin/deletion-requests?status=cancelled
Authorization: {{auth_deletion_admin}}
HTTP 200
[Asserts]
jsonpath "$.requests[?(@.id==9740013)].*" count == 19
