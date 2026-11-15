# GET /admin/class-access/members/{token} contract: one member's class access rules, the classes each reaches, and the version a write must echo. Runs against any implementation.
# Variables: base_url and auth_grants_<token> (tools/contract-grants.sh). Fixtures: db/synthetic/grants-fixtures.sql (read its header). Read-only. 925050 (gents, role 5) holds a gents rule 9750031 (city GRville: classes
# 98501 and 98502), a ladies rule 9750032 (GRville: 98505), a rule of either gender 9750033 (GRville: 98501, 98502, 98505) and a revoked rule 9750034. The closed class 98504 (also GRville) is reached by none.

# 1. Without sign-in: 401
GET {{base_url}}/admin/class-access/members/925050
HTTP 401

# 2. Who may not use the screen at all: 403
GET {{base_url}}/admin/class-access/members/925050
Authorization: {{auth_grants_925006}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/admin/class-access/members/925050
Authorization: {{auth_grants_925007}}
HTTP 403

GET {{base_url}}/admin/class-access/members/925050
Authorization: {{auth_grants_925008}}
HTTP 403

GET {{base_url}}/admin/class-access/members/925050
Authorization: {{auth_grants_925010}}
HTTP 403

# 3. A super admin sees every live rule (not the revoked one), in id order, with the classes each reaches and the version
GET {{base_url}}/admin/class-access/members/925050
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.*" count == 4
jsonpath "$.member.token" == 925050
jsonpath "$.member.name" == "Gr Member 925050"
jsonpath "$.member.gender" == 1
jsonpath "$.member.*" count == 3
jsonpath "$.version" matches "^5:[0-9a-f]{16}$"
jsonpath "$.fromRole" == null
jsonpath "$.rules" count == 3
jsonpath "$.rules[0].id" == 9750031
jsonpath "$.rules[0].gender" == 1
jsonpath "$.rules[0].note" == "Gents, GRville"
jsonpath "$.rules[0].createdAt" matches "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}"
jsonpath "$.rules[0].conditions" count == 1
jsonpath "$.rules[0].conditions[0].field" == "city"
jsonpath "$.rules[0].conditions[0].negate" == false
jsonpath "$.rules[0].conditions[0].value" == "GRville"
jsonpath "$.rules[0].classCount" == 2
jsonpath "$.rules[0].classes" count == 2
jsonpath "$.rules[0].classes[0].id" == 98501
jsonpath "$.rules[0].classes[0].code" == "GR-G-501"
jsonpath "$.rules[0].classes[0].name" == "Gr Class One"
jsonpath "$.rules[0].classes[0].ruleId" == 9750031
jsonpath "$.rules[0].classes[0].rule" == "Gents, GRville"
jsonpath "$.rules[0].classes[0].*" count == 5
jsonpath "$.rules[0].classes[1].id" == 98502
jsonpath "$.rules[1].id" == 9750032
jsonpath "$.rules[1].gender" == 2
jsonpath "$.rules[1].classCount" == 1
jsonpath "$.rules[1].classes[0].id" == 98505
jsonpath "$.rules[2].id" == 9750033
jsonpath "$.rules[2].gender" == null
jsonpath "$.rules[2].classCount" == 3
jsonpath "$.rules[2].classes[2].id" == 98505
[Captures]
all_rules_version: jsonpath "$.version"

# 4. A gents admin sees only the rules of their gender, but the version covers ALL live rules (the same as the super admin's)
GET {{base_url}}/admin/class-access/members/925050
Authorization: {{auth_grants_925003}}
HTTP 200
[Asserts]
jsonpath "$.version" == "{{all_rules_version}}"
jsonpath "$.rules" count == 1
jsonpath "$.rules[0].id" == 9750031
jsonpath "$.rules[?(@.id==9750032)]" not exists
jsonpath "$.rules[?(@.id==9750033)]" not exists

# 5. A member of the other gender, and a member with no recorded gender (for anyone, a super admin too): 403
GET {{base_url}}/admin/class-access/members/925050
Authorization: {{auth_grants_925004}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This member belongs to the other gender"

GET {{base_url}}/admin/class-access/members/925043
Authorization: {{auth_grants_925003}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This member belongs to the other gender"

GET {{base_url}}/admin/class-access/members/925044
Authorization: {{auth_grants_925003}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This member belongs to the other gender"

GET {{base_url}}/admin/class-access/members/925044
Authorization: {{auth_grants_925001}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This member belongs to the other gender"

GET {{base_url}}/admin/class-access/members/925043
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.member.gender" == 2
jsonpath "$.rules" count == 0

GET {{base_url}}/admin/class-access/members/925043
Authorization: {{auth_grants_925004}}
HTTP 200

# 6. fromRole: what the member's role already reaches. A super admin: every class; a gents admin: their gender. Viewing oneself is allowed
GET {{base_url}}/admin/class-access/members/925001
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.fromRole" == "Every class"
jsonpath "$.version" matches "^1:[0-9a-f]{16}$"
jsonpath "$.rules" count == 0

GET {{base_url}}/admin/class-access/members/925003
Authorization: {{auth_grants_925003}}
HTTP 200
[Asserts]
jsonpath "$.fromRole" == "Classes of their own gender"
jsonpath "$.version" matches "^3:[0-9a-f]{16}$"

# 7. No such member: a guest, a negative, a text, an unknown and a huge token
GET {{base_url}}/admin/class-access/members/0
Authorization: {{auth_grants_925001}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Member not found"

GET {{base_url}}/admin/class-access/members/-4
Authorization: {{auth_grants_925001}}
HTTP 404

GET {{base_url}}/admin/class-access/members/abc
Authorization: {{auth_grants_925003}}
HTTP 404

GET {{base_url}}/admin/class-access/members/99999999
Authorization: {{auth_grants_925003}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Member not found"

GET {{base_url}}/admin/class-access/members/99999999999999999999
Authorization: {{auth_grants_925001}}
HTTP 404
