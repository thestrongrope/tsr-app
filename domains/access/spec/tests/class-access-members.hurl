# GET /admin/class-access/members?q= contract: an operator finds members by name or token, of the genders they may manage. Runs against any implementation.
# Variables: base_url and auth_grants_<token> (tools/contract-grants.sh). Fixtures: db/synthetic/grants-fixtures.sql (read its header). Names are "Gr Member <token>": 925041 to 925049 match "Gr Member 92504";
# 925043 is a ladies member, 925044 has no recorded gender (found by nobody), the rest are gents. Read-only.

# 1. Without sign-in: 401
GET {{base_url}}/admin/class-access/members
[QueryStringParams]
q: Gr Member
HTTP 401

# 2. Who may not use the screen at all (class admin, finance, plain member, teacher role, holder of a named grant): 403
GET {{base_url}}/admin/class-access/members
Authorization: {{auth_grants_925006}}
[QueryStringParams]
q: Gr Member
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/admin/class-access/members
Authorization: {{auth_grants_925007}}
[QueryStringParams]
q: Gr Member
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/admin/class-access/members
Authorization: {{auth_grants_925008}}
[QueryStringParams]
q: Gr Member
HTTP 403

GET {{base_url}}/admin/class-access/members
Authorization: {{auth_grants_925009}}
[QueryStringParams]
q: Gr Member
HTTP 403

GET {{base_url}}/admin/class-access/members
Authorization: {{auth_grants_925010}}
[QueryStringParams]
q: Gr Member
HTTP 403

# 3. A super admin finds both genders, name and token and gender only; a member with no recorded gender is found by nobody
GET {{base_url}}/admin/class-access/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: Gr Member 92504
HTTP 200
[Asserts]
jsonpath "$.members" count == 8
jsonpath "$.members[0].token" == 925041
jsonpath "$.members[0].name" == "Gr Member 925041"
jsonpath "$.members[0].gender" == 1
jsonpath "$.members[0].*" count == 3
jsonpath "$.members[2].token" == 925043
jsonpath "$.members[2].gender" == 2
jsonpath "$.members[?(@.token==925044)]" not exists

# 4. A gents admin finds gents only
GET {{base_url}}/admin/class-access/members
Authorization: {{auth_grants_925003}}
[QueryStringParams]
q: Gr Member 92504
HTTP 200
[Asserts]
jsonpath "$.members" count == 7
jsonpath "$.members[?(@.token==925043)]" not exists
jsonpath "$.members[?(@.token==925044)]" not exists
jsonpath "$.members[?(@.token==925041)]" exists
jsonpath "$.members[?(@.gender==2)]" not exists

# 5. A ladies admin finds ladies only
GET {{base_url}}/admin/class-access/members
Authorization: {{auth_grants_925004}}
[QueryStringParams]
q: Gr Member 92504
HTTP 200
[Asserts]
jsonpath "$.members" count == 1
jsonpath "$.members[0].token" == 925043
jsonpath "$.members[0].gender" == 2

# 6. By token; the email and the mobile are not searched
GET {{base_url}}/admin/class-access/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: 925042
HTTP 200
[Asserts]
jsonpath "$.members" count == 1
jsonpath "$.members[0].token" == 925042

GET {{base_url}}/admin/class-access/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: gr.925042@example
HTTP 200
[Asserts]
jsonpath "$.members" count == 0

GET {{base_url}}/admin/class-access/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: +91000925042
HTTP 200
[Asserts]
jsonpath "$.members" count == 0

# 7. Under two characters, a missing q: nobody. A typed % or _ matches itself
GET {{base_url}}/admin/class-access/members
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.members" count == 0

GET {{base_url}}/admin/class-access/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: G
HTTP 200
[Asserts]
jsonpath "$.members" count == 0

GET {{base_url}}/admin/class-access/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: Gr Member 92504%
HTTP 200
[Asserts]
jsonpath "$.members" count == 0

GET {{base_url}}/admin/class-access/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: Gr Member 92504_
HTTP 200
[Asserts]
jsonpath "$.members" count == 0

# 8. q must be text: a list is 422
GET {{base_url}}/admin/class-access/members?q[]=ab
Authorization: {{auth_grants_925001}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "q must be text"

# 9. At most 20 members
GET {{base_url}}/admin/class-access/members
Authorization: {{auth_grants_925001}}
[QueryStringParams]
q: Gsrch Many
HTTP 200
[Asserts]
jsonpath "$.members" count == 20
jsonpath "$.members[0].name" == "Gsrch Many 01"
jsonpath "$.members[19].name" == "Gsrch Many 20"

# 10. PHP reads the LAST q when it is given twice (the first is ignored)
GET {{base_url}}/admin/class-access/members?q=Gsrch+Plain&q=Gsrch+Many+01
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.members" count == 1
jsonpath "$.members[0].token" == 925060
