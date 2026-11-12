# A grant to oneself, PHP only: PHP has no self guard here (finding 10), so a super admin grants themselves a permission no role gives. The new API refuses this with 422: see admin-permission-self-new-api.hurl.
# Variables: base_url and auth_grants_<token> (tools/contract-grants.sh). Changes member 925002 (a super admin) only, and takes the grant back at the end.

POST {{base_url}}/admin/permissions/members/925002/grants
Authorization: {{auth_grants_925002}}
{"permission": "quiz:admin:all", "reason": "Self grant"}
HTTP 200
[Asserts]
jsonpath "$.member.token" == 925002
jsonpath "$.granted[0].name" == "quiz:admin:all"
jsonpath "$.granted[0].grantedBy" == "Gr Member 925002"
[Captures]
self_grant_id: jsonpath "$.granted[0].id"

GET {{base_url}}/me/permissions
Authorization: {{auth_grants_925002}}
HTTP 200
[Asserts]
jsonpath "$.permissions" contains "quiz:admin:all"

POST {{base_url}}/admin/permissions/grants/{{self_grant_id}}/revoke
Authorization: {{auth_grants_925002}}
{"reason": "Self grant, over"}
HTTP 200
