# A grant to oneself, new API only: stricter than PHP (decision of 12 Nov 2026). The operator granting a permission to themself is refused with 422 and nothing is written. PHP allows it: see admin-permission-self-php-only.hurl.
# Variables: base_url and auth_grants_<token> (tools/contract-grants.sh). Changes no member: every request here is refused.

POST {{base_url}}/admin/permissions/members/925002/grants
Authorization: {{auth_grants_925002}}
{"permission": "quiz:admin:all", "reason": "Self grant"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "You cannot grant a permission to yourself"

GET {{base_url}}/admin/permissions/members/925002
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.granted" count == 0

GET {{base_url}}/me/permissions
Authorization: {{auth_grants_925002}}
HTTP 200
[Asserts]
jsonpath "$.permissions" not contains "quiz:admin:all"

# Without the permission, a grant to oneself is still the 403 of the permission check
POST {{base_url}}/admin/permissions/members/925008/grants
Authorization: {{auth_grants_925008}}
{"permission": "quiz:admin:all", "reason": "Self grant"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can manage permissions"
