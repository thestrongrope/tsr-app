# The guards of the ten /admin/whatsapp/* routes: 401 without sign-in, 403 "You do not have permission to do that" for a member without whatsapp:manage, before any call to the notifier.
# The link routes (7 to 10) send Cache-Control: no-store even on a refusal. Reads no state; calls no notifier. Runs against any implementation.
# Variables: base_url, auth_edge_plain (no role), auth_edge_gents (gents admin, role 3: holds no whatsapp:manage).

GET {{base_url}}/admin/whatsapp/reminders
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

PUT {{base_url}}/admin/whatsapp/reminders/5
Content-Type: application/json
{"enabled": true}
HTTP 401

POST {{base_url}}/admin/whatsapp/reminders/5/run
Content-Type: application/json
{}
HTTP 401

GET {{base_url}}/admin/whatsapp/runs
HTTP 401

GET {{base_url}}/admin/whatsapp/runs/5
HTTP 401

POST {{base_url}}/admin/whatsapp/test
Content-Type: application/json
{"mobile": "+910000000000", "message": "hello"}
HTTP 401

GET {{base_url}}/admin/whatsapp/link
HTTP 401
[Asserts]
header "Cache-Control" == "no-store"

GET {{base_url}}/admin/whatsapp/link/qr
HTTP 401
[Asserts]
header "Cache-Control" == "no-store"

POST {{base_url}}/admin/whatsapp/link/relink
Content-Type: application/json
{}
HTTP 401
[Asserts]
header "Cache-Control" == "no-store"

POST {{base_url}}/admin/whatsapp/link/logout
Content-Type: application/json
{}
HTTP 401
[Asserts]
header "Cache-Control" == "no-store"

# A plain member and a gents admin: 403 on every route
GET {{base_url}}/admin/whatsapp/reminders
Authorization: {{auth_edge_plain}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

PUT {{base_url}}/admin/whatsapp/reminders/5
Authorization: {{auth_edge_plain}}
Content-Type: application/json
{"enabled": true}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/admin/whatsapp/reminders/5/run
Authorization: {{auth_edge_plain}}
Content-Type: application/json
{"dryRun": false}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/admin/whatsapp/runs
Authorization: {{auth_edge_plain}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/admin/whatsapp/runs/5
Authorization: {{auth_edge_plain}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/admin/whatsapp/test
Authorization: {{auth_edge_plain}}
Content-Type: application/json
{"mobile": "+910000000000", "message": "hello"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/admin/whatsapp/link
Authorization: {{auth_edge_plain}}
HTTP 403
[Asserts]
header "Cache-Control" == "no-store"
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/admin/whatsapp/link/qr
Authorization: {{auth_edge_plain}}
HTTP 403
[Asserts]
header "Cache-Control" == "no-store"
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/admin/whatsapp/link/relink
Authorization: {{auth_edge_plain}}
Content-Type: application/json
{}
HTTP 403
[Asserts]
header "Cache-Control" == "no-store"
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/admin/whatsapp/link/logout
Authorization: {{auth_edge_gents}}
Content-Type: application/json
{}
HTTP 403
[Asserts]
header "Cache-Control" == "no-store"
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/admin/whatsapp/reminders
Authorization: {{auth_edge_gents}}
HTTP 403

POST {{base_url}}/admin/whatsapp/test
Authorization: {{auth_edge_gents}}
Content-Type: application/json
{"mobile": "+910000000000", "message": "hello"}
HTTP 403
