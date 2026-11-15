# Class access rules between operators of equal rank, and what a rule may reach: the cases PHP and the new API still answer alike (the looseness the new API no longer has is in class-access-peers-php-only.hurl and class-access-peers-new-api.hurl). Runs against any implementation.
# Variables: base_url and auth_grants_<token> (tools/contract-grants.sh). Fixtures: db/synthetic/grants-fixtures.sql (read its header). This file changes 925046 (a super admin, role 1),
# 925047 (role 6) and 925049 (a gents member) only. Every case here PINS what PHP does today; none is a wish. The proposals for the owner are in docs/specs/initial-build/test-grants-notes.md.

# 1. (A gents admin giving ANOTHER gents admin a rule is PHP's looseness: class-access-peers-php-only.hurl; the new API refuses it with 403: class-access-peers-new-api.hurl.)

# 2. A super admin gives another super admin a rule (role 1 stays) and a role 6 member a rule (role 6 stays)
GET {{base_url}}/admin/class-access/members/925046
Authorization: {{auth_grants_925001}}
HTTP 200
[Captures]
v46: jsonpath "$.version"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}]}
HTTP 200
[Captures]
ville_hash: jsonpath "$.previewHash"

POST {{base_url}}/admin/class-access/members/925046/rules
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Peer rule", "version": "{{v46}}", "previewHash": "{{ville_hash}}"}
HTTP 200
[Asserts]
jsonpath "$.version" matches "^1:[0-9a-f]{16}$"
jsonpath "$.fromRole" == "Every class"
jsonpath "$.rules" count == 1

GET {{base_url}}/admin/class-access/members/925047
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.version" matches "^6:[0-9a-f]{16}$"
[Captures]
v47: jsonpath "$.version"

POST {{base_url}}/admin/class-access/members/925047/rules
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Teacher role keeps its role", "version": "{{v47}}", "previewHash": "{{ville_hash}}"}
HTTP 200
[Asserts]
jsonpath "$.version" matches "^6:[0-9a-f]{16}$"
jsonpath "$.rules" count == 1

GET {{base_url}}/user/permissions
Authorization: {{auth_grants_925047}}
HTTP 200
[Asserts]
jsonpath "$.role_id" == 6

# 3. A rule of either gender: only a super admin may give or remove it
GET {{base_url}}/admin/class-access/members/925049
Authorization: {{auth_grants_925001}}
HTTP 200
[Captures]
v49: jsonpath "$.version"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"conditions": [{"field": "city", "value": "GRville"}]}
HTTP 200
[Asserts]
jsonpath "$.classCount" == 3
[Captures]
either_hash: jsonpath "$.previewHash"

POST {{base_url}}/admin/class-access/members/925049/rules
Authorization: {{auth_grants_925001}}
{"conditions": [{"field": "city", "value": "GRville"}], "reason": "Both genders", "version": "{{v49}}", "previewHash": "{{either_hash}}"}
HTTP 200
[Asserts]
jsonpath "$.version" matches "^5:[0-9a-f]{16}$"
jsonpath "$.rules[0].gender" == null
jsonpath "$.rules[0].note" == "Any gender, GRville"
jsonpath "$.rules[0].classCount" == 3
[Captures]
either_rule: jsonpath "$.rules[0].id"
v49b: jsonpath "$.version"

GET {{base_url}}/admin/class-access/members/925049
Authorization: {{auth_grants_925003}}
HTTP 200
[Asserts]
jsonpath "$.rules" count == 0
jsonpath "$.version" == "{{v49b}}"

POST {{base_url}}/admin/class-access/rules/{{either_rule}}/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Not mine to remove", "version": "{{v49b}}"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This member belongs to the other gender"

# 4. The preview hash proves "the same classes", not "the same rule". A different draft reaching other classes is refused; a different rule reaching the SAME classes is accepted (finding 14)
POST {{base_url}}/admin/class-access/members/925049/rules
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRother"}], "reason": "Another draft", "version": "{{v49b}}", "previewHash": "{{ville_hash}}"}
HTTP 409
[Asserts]
jsonpath "$.code" == "preview_changed"
jsonpath "$.classCount" == 1
jsonpath "$.classes[0].id" == 98503

POST {{base_url}}/admin/class-access/members/925049/rules
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "tag", "value": "gr-tag-a"}], "reason": "Same classes, another rule", "version": "{{v49b}}", "previewHash": "{{ville_hash}}"}
HTTP 200
[Asserts]
jsonpath "$.rules" count == 2
jsonpath "$.rules[1].note" == "Gents, gr-tag-a"
jsonpath "$.rules[1].classCount" == 2

# 5. A super admin removes the rule of either gender; the member keeps the other rule and role 5
POST {{base_url}}/admin/class-access/rules/{{either_rule}}/revoke
Authorization: {{auth_grants_925001}}
{"reason": "Both genders removed", "version": "{{v49b}}"}
HTTP 409
[Asserts]
jsonpath "$.code" == "member_changed"

GET {{base_url}}/admin/class-access/members/925049
Authorization: {{auth_grants_925001}}
HTTP 200
[Captures]
v49c: jsonpath "$.version"

POST {{base_url}}/admin/class-access/rules/{{either_rule}}/revoke
Authorization: {{auth_grants_925001}}
{"reason": "Both genders removed", "version": "{{v49c}}"}
HTTP 200
[Asserts]
jsonpath "$.rules" count == 1
jsonpath "$.version" matches "^5:[0-9a-f]{16}$"
