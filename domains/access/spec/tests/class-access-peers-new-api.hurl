# POST /admin/class-access/members/{token}/rules, new API only: stricter than PHP (decision of 12 Nov 2026). An operator who is not a super admin may not add a rule to a super admin or a gender admin:
# 403 "You do not have permission to do that", nothing written. PHP accepts it: see class-access-peers-php-only.hurl. A super admin may (class-access-peers.hurl case 2).
# Variables: base_url and auth_grants_<token> (tools/contract-grants.sh). Fixtures: db/synthetic/grants-fixtures.sql. Every request here is refused; 925045 is a gents admin (role 3), 925046 a super admin (role 1).

POST {{base_url}}/admin/class-access/members/925045/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "level", "value": 2}], "reason": "Peer rule", "version": "x", "previewHash": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/admin/class-access/members/925046/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Super admin rule", "version": "x", "previewHash": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/admin/class-access/members/925045
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.rules" count == 0
