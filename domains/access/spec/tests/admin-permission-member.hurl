# GET /admin/permissions/members/{token} contract: what a member holds (from the role, granted) and what may still be granted. Runs against any implementation.
# Variables: base_url and auth_grants_<token> (tools/contract-grants.sh). Fixtures: db/synthetic/grants-fixtures.sql (read its header). This file only reads: 925010 holds one live named grant
# (id 9750001, standard-mcqs:update:all, granted by 925001), 925008 is a plain member, 925001 a super admin.

# 1. Without sign-in: 401
GET {{base_url}}/admin/permissions/members/925010
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Everyone but a super admin: 403
GET {{base_url}}/admin/permissions/members/925010
Authorization: {{auth_grants_925003}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can manage permissions"

GET {{base_url}}/admin/permissions/members/925010
Authorization: {{auth_grants_925004}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can manage permissions"

GET {{base_url}}/admin/permissions/members/925010
Authorization: {{auth_grants_925006}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can manage permissions"

GET {{base_url}}/admin/permissions/members/925010
Authorization: {{auth_grants_925007}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can manage permissions"

GET {{base_url}}/admin/permissions/members/925010
Authorization: {{auth_grants_925008}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can manage permissions"

GET {{base_url}}/admin/permissions/members/925010
Authorization: {{auth_grants_925010}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can manage permissions"

# 3. A member with one named grant: the shape, the granted list with who gave it and why, and what is not grantable
GET {{base_url}}/admin/permissions/members/925010
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.*" count == 4
jsonpath "$.member.*" count == 2
jsonpath "$.member.token" == 925010
jsonpath "$.member.name" == "Gr Member 925010"
jsonpath "$.fromRole" count == 0
jsonpath "$.granted" count == 1
jsonpath "$.granted[0].id" == 9750001
jsonpath "$.granted[0].name" == "standard-mcqs:update:all"
jsonpath "$.granted[0].reason" == "Gr fixture grant"
jsonpath "$.granted[0].grantedBy" == "Gr Member 925001"
jsonpath "$.granted[0].reach" == "In every class and for every member"
jsonpath "$.granted[0].grantedAt" matches "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}"
jsonpath "$.granted[0].description" matches /\S/
jsonpath "$.granted[0].*" count == 7
jsonpath "$.grantable[?(@.name=='standard-mcqs:update:all')]" not exists
jsonpath "$.grantable[?(@.name=='permissions:manage:all')]" not exists
jsonpath "$.grantable[?(@.name=='class-access:manage:all')]" not exists
jsonpath "$.grantable[?(@.name=='members:enrol-by-token:all')]" not exists
jsonpath "$.grantable[?(@.name=='api-docs:read:all')]" exists
jsonpath "$.grantable[?(@.name=='donors:read:all')]" exists
jsonpath "$.grantable[?(@.name=='class-access:manage:gender')]" not exists
jsonpath "$.grantable[?(@.name=='profile:read:self')]" not exists
jsonpath "$.grantable[0].*" count == 3
jsonpath "$.grantable[0].reach" == "In every class and for every member"
jsonpath "$.grantable[?(@.name=='content:read:all')]" not exists

# 4. A plain member: the role gives nothing, the member set is held (so not grantable), nothing is granted
GET {{base_url}}/admin/permissions/members/925008
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.fromRole" count == 0
jsonpath "$.granted" count == 0
jsonpath "$.grantable[?(@.name=='content:read:all')]" not exists
jsonpath "$.grantable[?(@.name=='syllabus:read:all')]" not exists
jsonpath "$.grantable[?(@.name=='api-docs:read:all')]" exists

# 5. A super admin: the role gives permissions:manage:all and the rest; none of it is grantable again
GET {{base_url}}/admin/permissions/members/925001
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.fromRole[?(@.name=='permissions:manage:all')]" exists
jsonpath "$.fromRole[?(@.name=='permissions:manage:all')].reach" == "In every class and for every member"
jsonpath "$.grantable[?(@.name=='permissions:manage:all')]" not exists
jsonpath "$.grantable[?(@.name=='feedback:review:all')]" not exists

# 6. A gents admin's role gives gender scopes
GET {{base_url}}/admin/permissions/members/925003
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.fromRole[?(@.name=='class-access:manage:gender')]" exists
jsonpath "$.fromRole[?(@.name=='class-access:manage:gender')].reach" == "In classes of their own gender"

# 7. No such member: a guest, a negative, a text, an unknown and a huge token are all 404
GET {{base_url}}/admin/permissions/members/0
Authorization: {{auth_grants_925001}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Member not found"

GET {{base_url}}/admin/permissions/members/-5
Authorization: {{auth_grants_925001}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Member not found"

GET {{base_url}}/admin/permissions/members/abc
Authorization: {{auth_grants_925001}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Member not found"

GET {{base_url}}/admin/permissions/members/99999999
Authorization: {{auth_grants_925001}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Member not found"

GET {{base_url}}/admin/permissions/members/99999999999999999999
Authorization: {{auth_grants_925001}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Member not found"
