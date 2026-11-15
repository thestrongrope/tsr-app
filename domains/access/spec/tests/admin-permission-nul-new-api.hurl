# A NUL byte in the reason of a named grant, on the new API only: PHP stores it (200), PostgreSQL cannot, so the new API refuses with 422 and writes nothing. Variables: base_url and auth_grants_<token>
# (tools/contract-grants.sh). This file changes no member: every request here is refused.

POST {{base_url}}/admin/permissions/members/925008/grants
Authorization: {{auth_grants_925001}}
{"permission": "api-docs:read:all", "reason": "a\u0000b"}
HTTP 422
[Asserts]
jsonpath "$.detail" matches /\S/

POST {{base_url}}/admin/permissions/grants/9750001/revoke
Authorization: {{auth_grants_925001}}
{"reason": "a\u0000b"}
HTTP 422
[Asserts]
jsonpath "$.detail" matches /\S/

GET {{base_url}}/admin/permissions/members/925008
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.granted" count == 0

GET {{base_url}}/admin/permissions/members/925010
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.granted" count == 1
