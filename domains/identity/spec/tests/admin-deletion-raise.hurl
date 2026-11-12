# POST /admin/deletion-requests contract: an administrator raises a request from an emailed address. Runs against any implementation.
# Variables: base_url, auth_deletion_admin (924001, role 1), auth_deletion_plain (924002, no permission). Target member 924006 (dl.924006@example.invalid, no request); the guest user (token 0,
# dl.guest.924000@example.invalid) must match nobody. Fixtures: db/synthetic/deletion-fixtures.sql (the reload deletes the request this file raises).

# 1. Without sign-in: 401. Without the permission: 403 before the address is looked at (the same answer for an address that exists and one that does not)
POST {{base_url}}/admin/deletion-requests
{"email": "dl.924006@example.invalid"}
HTTP 401

POST {{base_url}}/admin/deletion-requests
Authorization: {{auth_deletion_plain}}
{"email": "dl.924006@example.invalid"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/admin/deletion-requests
Authorization: {{auth_deletion_plain}}
{"email": "nobody.dl@example.invalid"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. A missing, blank or non-text address: 422
POST {{base_url}}/admin/deletion-requests
Authorization: {{auth_deletion_admin}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Enter the email address the request came from"

POST {{base_url}}/admin/deletion-requests
Authorization: {{auth_deletion_admin}}
{"email": "   "}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Enter the email address the request came from"

POST {{base_url}}/admin/deletion-requests
Authorization: {{auth_deletion_admin}}
{"email": 7}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Enter the email address the request came from"

# 3. An address that matches no member, or only the guest user: 404 naming the address
POST {{base_url}}/admin/deletion-requests
Authorization: {{auth_deletion_admin}}
{"email": "nobody.dl@example.invalid"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "No account matches nobody.dl@example.invalid"

POST {{base_url}}/admin/deletion-requests
Authorization: {{auth_deletion_admin}}
{"email": "dl.guest.924000@example.invalid"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "No account matches dl.guest.924000@example.invalid"

POST {{base_url}}/admin/deletion-requests
Authorization: {{auth_deletion_admin}}
{"email": "a\u0000b@example.invalid"}
HTTP 404
[Asserts]
jsonpath "$.detail" startsWith "No account matches a"

# 4. A member's address (in any case, with spaces round it) opens a request: 201, created true, source web
POST {{base_url}}/admin/deletion-requests
Authorization: {{auth_deletion_admin}}
{"email": "  DL.924006@Example.Invalid "}
HTTP 201
[Captures]
raised_id: jsonpath "$.request.id"
[Asserts]
jsonpath "$.created" == true
jsonpath "$.request.status" == "pending"
jsonpath "$.request.source" == "web"
jsonpath "$.request.token" == 924006
jsonpath "$.request.member_name" == "Dl Member 924006"
jsonpath "$.request.contact_email" == "dl.924006@example.invalid"
jsonpath "$.request.reason" == "Raised by an administrator from an emailed request."
jsonpath "$.request.confirmation_sent_at" == null
jsonpath "$.request.can_complete" == false
jsonpath "$.request.confirmation.to" == "dl.924006@example.invalid"
jsonpath "$.request.*" count == 19
jsonpath "$.*" count == 2

# 5. Again: 200 with the same request, created false
POST {{base_url}}/admin/deletion-requests
Authorization: {{auth_deletion_admin}}
{"email": "dl.924006@example.invalid"}
HTTP 200
[Asserts]
jsonpath "$.created" == false
jsonpath "$.request.id" == {{raised_id}}
