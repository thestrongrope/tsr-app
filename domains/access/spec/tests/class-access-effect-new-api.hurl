# What a class access rule does to the member, on the new API only (the parity database still reads the legacy class_access table for PHP's assigned scope, so PHP cannot show it), and the NUL byte cases (PHP stores a
# NUL in a reason; PostgreSQL cannot, so the new API answers 422 where PHP answers 200). Variables: base_url and auth_grants_<token> (tools/contract-grants.sh). This file changes members 925053 and 925054 only.

# 1. Before: the member holds no assigned class
GET {{base_url}}/me/permissions
Authorization: {{auth_grants_925053}}
HTTP 200
[Asserts]
jsonpath "$.scopes.assigned" count == 0

GET {{base_url}}/admin/class-access/members/925053
Authorization: {{auth_grants_925003}}
HTTP 200
[Captures]
v0: jsonpath "$.version"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}]}
HTTP 200
[Captures]
hash: jsonpath "$.previewHash"

# 2. The grant takes effect on the very next request: the classes the preview showed are the member's assigned scope (one matcher for the preview, the saved view and the engine); the closed class is not among them
POST {{base_url}}/admin/class-access/members/925053/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Effect", "version": "{{v0}}", "previewHash": "{{hash}}"}
HTTP 200
[Asserts]
jsonpath "$.rules[0].classCount" == 2
[Captures]
rule: jsonpath "$.rules[0].id"
v1: jsonpath "$.version"

GET {{base_url}}/me/permissions
Authorization: {{auth_grants_925053}}
HTTP 200
[Asserts]
jsonpath "$.scopes.assigned" count == 2
jsonpath "$.scopes.assigned" contains 98501
jsonpath "$.scopes.assigned" contains 98502
jsonpath "$.scopes.assigned" not contains 98503
jsonpath "$.scopes.assigned" not contains 98504
jsonpath "$.scopes.assigned" not contains 98505
jsonpath "$.scopes.assigned_genders" count == 1
jsonpath "$.scopes.assigned_genders[0]" == 1

# 3. A revoked rule stops working at once
POST {{base_url}}/admin/class-access/rules/{{rule}}/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Effect over", "version": "{{v1}}"}
HTTP 200
[Asserts]
jsonpath "$.rules" count == 0

GET {{base_url}}/me/permissions
Authorization: {{auth_grants_925053}}
HTTP 200
[Asserts]
jsonpath "$.scopes.assigned" count == 0

# 4. A NUL byte in a reason is refused (never a 500), on both writes, and nothing is written
GET {{base_url}}/admin/class-access/members/925054
Authorization: {{auth_grants_925003}}
HTTP 200
[Captures]
v54: jsonpath "$.version"

POST {{base_url}}/admin/class-access/members/925054/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "a\u0000b", "version": "{{v54}}", "previewHash": "{{hash}}"}
HTTP 422
[Asserts]
jsonpath "$.detail" matches /\S/

POST {{base_url}}/admin/class-access/members/925054/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Fine", "version": "{{v54}}", "previewHash": "{{hash}}"}
HTTP 200
[Captures]
rule54: jsonpath "$.rules[0].id"
v54b: jsonpath "$.version"

POST {{base_url}}/admin/class-access/rules/{{rule54}}/revoke
Authorization: {{auth_grants_925003}}
{"reason": "a\u0000b", "version": "{{v54b}}"}
HTTP 422
[Asserts]
jsonpath "$.detail" matches /\S/

GET {{base_url}}/admin/class-access/members/925054
Authorization: {{auth_grants_925003}}
HTTP 200
[Asserts]
jsonpath "$.rules" count == 1
jsonpath "$.version" == "{{v54b}}"

# 5. A NUL byte in a condition value is simply not an offered value; in a search term it is refused
POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GR\u0000ville"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose a city from the list"

GET {{base_url}}/admin/class-access/members?q=%00ab
Authorization: {{auth_grants_925001}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "q must be text"

GET {{base_url}}/admin/permissions/members?q=%00ab
Authorization: {{auth_grants_925001}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "q must be text"
