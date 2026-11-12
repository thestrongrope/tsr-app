# What only the new API does on the WhatsApp routes (PHP raises a 500 or forwards the input): a 422 for text no notifier column could hold, for invalid JSON, and ids and queries that cannot steer the notifier call.
# New API only. Variables: base_url, auth_edge_wa_new (super admin, used by this file only). The exact notifier URLs are asserted in domains/notifications/api/domain/Notifier.Tests.cs and db/tests/TestEdgeWhatsappTests.cs.

# Invalid JSON in a body that is read: 422, nothing sent
POST {{base_url}}/admin/whatsapp/reminders/5/run
Authorization: {{auth_edge_wa_new}}
Content-Type: application/json
```
{"dryRun": false
```
HTTP 422
[Asserts]
jsonpath "$.detail" matches /\S/

POST {{base_url}}/admin/whatsapp/test
Authorization: {{auth_edge_wa_new}}
Content-Type: application/json
```
not json
```
HTTP 422

# A NUL byte inside text, or text past the column length: 422, never 500
POST {{base_url}}/admin/whatsapp/test
Authorization: {{auth_edge_wa_new}}
Content-Type: application/json
{"mobile": "+91\u00001", "message": "hello"}
HTTP 422
[Asserts]
jsonpath "$.detail" matches /NUL/

POST {{base_url}}/admin/whatsapp/test
Authorization: {{auth_edge_wa_new}}
Content-Type: application/json
{"mobile": "12345678901234567890123456789012345678901234", "message": "hello"}
HTTP 422

PUT {{base_url}}/admin/whatsapp/reminders/5
Authorization: {{auth_edge_wa_new}}
Content-Type: application/json
{"city": "a\u0000b"}
HTTP 422

# An id with no digits, an 80 digit id, a path-like id: never a 500 and never a different path
GET {{base_url}}/admin/whatsapp/runs/99999999999999999999999999999999999999999999999999999999999999999999999999999999
Authorization: {{auth_edge_wa_new}}
HTTP 502
[Asserts]
jsonpath "$.detail" == "notifier unreachable"

GET {{base_url}}/admin/whatsapp/runs/12abc
Authorization: {{auth_edge_wa_new}}
HTTP 502

GET {{base_url}}/admin/whatsapp/runs/1%3Fx%3Dy
Authorization: {{auth_edge_wa_new}}
HTTP 502

POST {{base_url}}/admin/whatsapp/reminders/99999999999999999999999999999999999999999999999999999999999999999999999999999999/run
Authorization: {{auth_edge_wa_new}}
Content-Type: application/json
{}
HTTP 502

# The runs query: digits only reach the notifier, a long digit string and junk are dropped; the call still ends at the unreachable notifier
GET {{base_url}}/admin/whatsapp/runs?limit=99999999999999999999999&reminderId=7%26y
Authorization: {{auth_edge_wa_new}}
HTTP 502
