# POST /admin/class-access/members/{token}/rules, PHP only: a gents admin gives ANOTHER gents admin a rule, and a rule on a level with no city: the "offered" list limits city, country and tag, not levels (findings 10 and 11).
# PHP accepts both; the peer keeps role 3. The new API refuses the rule on a gender admin with 403: see class-access-peers-new-api.hurl (a rule on a level is still allowed there: class-access-preview.hurl case 11).
# Variables: base_url and auth_grants_<token> (tools/contract-grants.sh). Fixtures: db/synthetic/grants-fixtures.sql. Changes 925045 (a gents admin, role 3) only.

GET {{base_url}}/admin/class-access/members/925045
Authorization: {{auth_grants_925003}}
HTTP 200
[Asserts]
jsonpath "$.version" matches "^3:[0-9a-f]{16}$"
[Captures]
v45: jsonpath "$.version"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "level", "value": 2}]}
HTTP 200
[Asserts]
jsonpath "$.classes[?(@.id==98501)]" exists
jsonpath "$.classes[?(@.id==98503)]" exists
[Captures]
level2_hash: jsonpath "$.previewHash"

POST {{base_url}}/admin/class-access/members/925045/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "level", "value": 2}], "reason": "Peer rule", "version": "{{v45}}", "previewHash": "{{level2_hash}}"}
HTTP 200
[Asserts]
jsonpath "$.saved" == true
jsonpath "$.member.token" == 925045
jsonpath "$.rules" count == 1
jsonpath "$.rules[0].note" == "Gents, level 2"
jsonpath "$.rules[0].classes[?(@.id==98503)]" exists
jsonpath "$.version" matches "^3:[0-9a-f]{16}$"

GET {{base_url}}/user/permissions
Authorization: {{auth_grants_925045}}
HTTP 200
[Asserts]
jsonpath "$.role_id" == 3
