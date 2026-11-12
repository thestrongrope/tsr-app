# The WhatsApp routes when the notifier cannot be reached (neither test stack has one: the setting is absent on the new API, the host name does not resolve on PHP's parity network).
# Proxied routes: 502 {"detail": "notifier unreachable..."} (PHP appends curl's reason, the new API does not: only the start is asserted). Link routes: 503. An id of 0 or less is 400 before any call.
# Never a 500, never the notifier's host in the new API's body. Runs against any implementation. Variables: base_url, auth_edge_wa_down (super admin, used by this file only).

GET {{base_url}}/admin/whatsapp/reminders
Authorization: {{auth_edge_wa_down}}
HTTP 502
[Asserts]
header "Content-Type" startsWith "application/json"
jsonpath "$.detail" startsWith "notifier unreachable"

PUT {{base_url}}/admin/whatsapp/reminders/5
Authorization: {{auth_edge_wa_down}}
Content-Type: application/json
{"enabled": true, "leewayDays": 3}
HTTP 502
[Asserts]
jsonpath "$.detail" startsWith "notifier unreachable"

PUT {{base_url}}/admin/whatsapp/reminders/0
Authorization: {{auth_edge_wa_down}}
Content-Type: application/json
{"enabled": true}
HTTP 400
[Asserts]
jsonpath "$.detail" == "missing or invalid id"

PUT {{base_url}}/admin/whatsapp/reminders/abc
Authorization: {{auth_edge_wa_down}}
Content-Type: application/json
{"enabled": true}
HTTP 400
[Asserts]
jsonpath "$.detail" == "missing or invalid id"

# A dry run (nothing sent) and a real one both end at the unreachable notifier
POST {{base_url}}/admin/whatsapp/reminders/5/run
Authorization: {{auth_edge_wa_down}}
Content-Type: application/json
{}
HTTP 502
[Asserts]
jsonpath "$.detail" startsWith "notifier unreachable"

POST {{base_url}}/admin/whatsapp/reminders/5/run
Authorization: {{auth_edge_wa_down}}
Content-Type: application/json
{"dryRun": false}
HTTP 502
[Asserts]
jsonpath "$.detail" startsWith "notifier unreachable"

GET {{base_url}}/admin/whatsapp/runs
Authorization: {{auth_edge_wa_down}}
HTTP 502
[Asserts]
jsonpath "$.detail" startsWith "notifier unreachable"

GET {{base_url}}/admin/whatsapp/runs?limit=3&reminderId=7
Authorization: {{auth_edge_wa_down}}
HTTP 502

GET {{base_url}}/admin/whatsapp/runs?limit=3%26x%3D1&reminderId=abc
Authorization: {{auth_edge_wa_down}}
HTTP 502

GET {{base_url}}/admin/whatsapp/runs/5
Authorization: {{auth_edge_wa_down}}
HTTP 502
[Asserts]
jsonpath "$.detail" startsWith "notifier unreachable"

GET {{base_url}}/admin/whatsapp/runs/0
Authorization: {{auth_edge_wa_down}}
HTTP 400
[Asserts]
jsonpath "$.detail" == "missing or invalid id"

GET {{base_url}}/admin/whatsapp/runs/abc
Authorization: {{auth_edge_wa_down}}
HTTP 400
[Asserts]
jsonpath "$.detail" == "missing or invalid id"

# The test message goes nowhere: this notifier does not exist
POST {{base_url}}/admin/whatsapp/test
Authorization: {{auth_edge_wa_down}}
Content-Type: application/json
{"mobile": "+910000000000", "message": "hello"}
HTTP 502
[Asserts]
jsonpath "$.detail" startsWith "notifier unreachable"

POST {{base_url}}/admin/whatsapp/test
Authorization: {{auth_edge_wa_down}}
Content-Type: application/json
{"mobile": 5, "message": ["x"]}
HTTP 502

# The link routes: 503, never cached
GET {{base_url}}/admin/whatsapp/link
Authorization: {{auth_edge_wa_down}}
HTTP 503
[Asserts]
header "Cache-Control" == "no-store"
jsonpath "$.detail" == "The reminder service cannot be reached right now. Trying again."

GET {{base_url}}/admin/whatsapp/link/qr
Authorization: {{auth_edge_wa_down}}
HTTP 503
[Asserts]
header "Cache-Control" == "no-store"
jsonpath "$.detail" == "The reminder service cannot be reached right now. Trying again."

# Invalid JSON in a body that is read: 422, nothing sent
POST {{base_url}}/admin/whatsapp/reminders/5/run
Authorization: {{auth_edge_wa_down}}
Content-Type: application/json
```
{"dryRun": false
```
HTTP 422
[Asserts]
jsonpath "$.detail" matches /\S/

POST {{base_url}}/admin/whatsapp/test
Authorization: {{auth_edge_wa_down}}
Content-Type: application/json
```
not json
```
HTTP 422

# An id that is not a clean number cannot steer the call: it is read as PHP (int), so these all end at the unreachable notifier, never a 500
GET {{base_url}}/admin/whatsapp/runs/99999999999999999999999999999999999999999999999999999999999999999999999999999999
Authorization: {{auth_edge_wa_down}}
HTTP 502
[Asserts]
jsonpath "$.detail" startsWith "notifier unreachable"

GET {{base_url}}/admin/whatsapp/runs/12abc
Authorization: {{auth_edge_wa_down}}
HTTP 502

GET {{base_url}}/admin/whatsapp/runs/1%3Fx%3Dy
Authorization: {{auth_edge_wa_down}}
HTTP 502

GET {{base_url}}/admin/whatsapp/runs/1%00
Authorization: {{auth_edge_wa_down}}
HTTP *
[Asserts]
status < 500

POST {{base_url}}/admin/whatsapp/reminders/99999999999999999999999999999999999999999999999999999999999999999999999999999999/run
Authorization: {{auth_edge_wa_down}}
Content-Type: application/json
{}
HTTP 502

# The runs query: only digits reach the notifier; a long digit string and junk are dropped or passed, the call still ends at the unreachable notifier
GET {{base_url}}/admin/whatsapp/runs?limit=99999999999999999999999&reminderId=7%26y
Authorization: {{auth_edge_wa_down}}
HTTP 502
