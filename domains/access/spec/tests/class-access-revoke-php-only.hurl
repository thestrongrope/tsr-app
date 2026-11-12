# POST /admin/class-access/rules/{id}/revoke, PHP only: a gents admin removes a rule of ANOTHER gents admin (equal rank) that a super admin granted: allowed, the only self guard is the operator's own token (finding 11).
# The new API refuses this with 403: see class-access-revoke-new-api.hurl.
# Variables: base_url and auth_grants_<token> (tools/contract-grants.sh). Fixtures: db/synthetic/grants-fixtures.sql. Changes 925005 (a second gents admin, role 3: rule 9750052 is removed, 9750051 stays); class-access-revoke.hurl
# only refuses on 925005, so the two files do not depend on each other.

GET {{base_url}}/admin/class-access/members/925005
Authorization: {{auth_grants_925003}}
HTTP 200
[Asserts]
jsonpath "$.rules" count == 2
jsonpath "$.version" matches "^3:[0-9a-f]{16}$"
jsonpath "$.fromRole" == "Classes of their own gender"
[Captures]
vC: jsonpath "$.version"

POST {{base_url}}/admin/class-access/rules/9750052/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Peer rule removed", "version": "{{vC}}"}
HTTP 200
[Asserts]
jsonpath "$.saved" == true
jsonpath "$.member.token" == 925005
jsonpath "$.rules" count == 1
jsonpath "$.rules[0].id" == 9750051
jsonpath "$.version" matches "^3:[0-9a-f]{16}$"

GET {{base_url}}/user/permissions
Authorization: {{auth_grants_925005}}
HTTP 200
[Asserts]
jsonpath "$.role_id" == 3
