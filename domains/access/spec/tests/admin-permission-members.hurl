# GET /admin/permissions/members?q= contract: a super admin finds members by name, token, email or mobile; the answer holds name and token only. Runs against any implementation.
# Variables: base_url and auth_grants_<token> (tools/contract-grants.sh). Fixtures: db/synthetic/grants-fixtures.sql (read its header): 925031 to 925034 are the search names, 925060 to 925084 "Gsrch Many nn".

# 1. Without sign-in: 401
GET {{base_url}}/admin/permissions/members
[QueryStringParams]
q: Gsrch
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Everyone but a super admin: 403, whatever the role (gents admin, ladies admin, class admin, finance, plain member, teacher role, a holder of only a named grant)
GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925003}}
[QueryStringParams]
q: Gsrch
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can manage permissions"

GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925004}}
[QueryStringParams]
q: Gsrch
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can manage permissions"

GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925006}}
[QueryStringParams]
q: Gsrch
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can manage permissions"

GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925007}}
[QueryStringParams]
q: Gsrch
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can manage permissions"

GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925008}}
[QueryStringParams]
q: Gsrch
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can manage permissions"

GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925009}}
[QueryStringParams]
q: Gsrch
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can manage permissions"

GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925010}}
[QueryStringParams]
q: Gsrch
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can manage permissions"

# 3. A missing q, one character and a lone space-padded character find nobody
GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.members" count == 0

GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: G
HTTP 200
[Asserts]
jsonpath "$.members" count == 0

GET {{base_url}}/admin/permissions/members?q=%20%20G%20%20
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.members" count == 0

# 4. By name (case-insensitive): name and token only, no email or mobile
GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: gSRCH plain
HTTP 200
[Asserts]
jsonpath "$.*" count == 1
jsonpath "$.members" count == 1
jsonpath "$.members[0].token" == 925033
jsonpath "$.members[0].name" == "Gsrch Plain"
jsonpath "$.members[0].*" count == 2

# 5. A typed % or _ matches itself, not anything
GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: Percent 50%
HTTP 200
[Asserts]
jsonpath "$.members" count == 1
jsonpath "$.members[0].token" == 925031

GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: Gsrch Plai%
HTTP 200
[Asserts]
jsonpath "$.members" count == 0

GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: Gsrch Plai_
HTTP 200
[Asserts]
jsonpath "$.members" count == 0

GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: Under_Sc
HTTP 200
[Asserts]
jsonpath "$.members" count == 1
jsonpath "$.members[0].token" == 925032

# 6. By email, by mobile and by token (an all-digit term)
GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: GR.925033@EXAMPLE
HTTP 200
[Asserts]
jsonpath "$.members" count == 1
jsonpath "$.members[0].token" == 925033

GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: +91000925034
HTTP 200
[Asserts]
jsonpath "$.members" count == 1
jsonpath "$.members[0].token" == 925034

GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: 925031
HTTP 200
[Asserts]
jsonpath "$.members" count == 1
jsonpath "$.members[0].token" == 925031

# 7. At most 20, ordered by name then token
GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: Gsrch Many
HTTP 200
[Asserts]
jsonpath "$.members" count == 20
jsonpath "$.members[0].token" == 925060
jsonpath "$.members[0].name" == "Gsrch Many 01"
jsonpath "$.members[19].token" == 925079
jsonpath "$.members[19].name" == "Gsrch Many 20"

# 8. An unknown term finds nobody
GET {{base_url}}/admin/permissions/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: no-such-member-gr
HTTP 200
[Asserts]
jsonpath "$.members" count == 0

# 9. PHP reads the LAST q when it is given twice
GET {{base_url}}/admin/permissions/members?q=Gsrch+Plain&q=Gsrch+Many+01
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.members" count == 1
