# POST /classes/{class_id}/deactivate: a NUL character in the reason is a 422 (PostgreSQL cannot store it; PHP stores it). New API only. Fixtures as class-deactivate.hurl; class 9434 is never deactivated.
POST {{base_url}}/classes/9434/deactivate
Authorization: {{auth_wr_admin}}
{"type": "completed", "effectiveDate": "2026-01-05", "reason": "a\u0000b"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Reason must not contain NUL characters"

GET {{base_url}}/classes/9434/manage
Authorization: {{auth_wr_admin}}
HTTP 200
