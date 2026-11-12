# What only the new API does on the WhatsApp routes: a 422 for text no notifier column could hold (a NUL byte, text past the column length), where PHP forwards it to the notifier (502 here, as nothing listens).
# New API only. Variables: base_url, auth_edge_wa_new (super admin, used by this file only). The exact notifier URLs are asserted in domains/notifications/api/domain/Notifier.Tests.cs and db/tests/TestEdgeWhatsappTests.cs.

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

# No leaked host in the new API's 502 body
GET {{base_url}}/admin/whatsapp/runs/5
Authorization: {{auth_edge_wa_new}}
HTTP 502
[Asserts]
jsonpath "$.detail" == "notifier unreachable"
