# GET /admin/class-access/options contract: the genders an operator may use, the levels, and the cities, countries and tags of the ACTIVE classes of those genders. Runs against any implementation.
# Variables: base_url and auth_grants_<token> (tools/contract-grants.sh). Fixtures: db/synthetic/grants-fixtures.sql (read its header). Other lanes' classes share the database, so the lists are
# checked for the fixture values only: GRville (gents 98501, 98502 and ladies 98505), GRother (gents 98503), GRlady (ladies 98506), Grland, tags gr-tag-a (gents classes) and gr-tag-b (a ladies class),
# and GRclosed / Grclosedland, which only a CLOSED class (98507) has and so are offered to nobody. Read-only.

# 1. Without sign-in: 401
GET {{base_url}}/admin/class-access/options
HTTP 401

# 2. Who may not use the screen: 403
GET {{base_url}}/admin/class-access/options
Authorization: {{auth_grants_925006}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/admin/class-access/options
Authorization: {{auth_grants_925008}}
HTTP 403

GET {{base_url}}/admin/class-access/options
Authorization: {{auth_grants_925010}}
HTTP 403

# 3. A super admin: both genders, the levels, and every active class's values; a closed class's values are not offered
GET {{base_url}}/admin/class-access/options
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.*" count == 5
jsonpath "$.genders" count == 2
jsonpath "$.genders[0].id" == 1
jsonpath "$.genders[0].name" == "Gents"
jsonpath "$.genders[1].id" == 2
jsonpath "$.genders[1].name" == "Ladies"
jsonpath "$.genders[0].*" count == 2
jsonpath "$.levels[0].*" count == 3
jsonpath "$.levels[0].id" isInteger
jsonpath "$.levels[0].code" isString
jsonpath "$.levels[?(@.id==2)]" exists
jsonpath "$.cities" contains "GRville"
jsonpath "$.cities" contains "GRother"
jsonpath "$.cities" contains "GRlady"
jsonpath "$.cities" not contains "GRclosed"
jsonpath "$.countries" contains "Grland"
jsonpath "$.countries" not contains "Grclosedland"
jsonpath "$.tags" contains "gr-tag-a"
jsonpath "$.tags" contains "gr-tag-b"

# 4. A gents admin: gents only, and only the values of active gents classes (GRlady and gr-tag-b are ladies only)
GET {{base_url}}/admin/class-access/options
Authorization: {{auth_grants_925003}}
HTTP 200
[Asserts]
jsonpath "$.genders" count == 1
jsonpath "$.genders[0].id" == 1
jsonpath "$.genders[0].name" == "Gents"
jsonpath "$.cities" contains "GRville"
jsonpath "$.cities" contains "GRother"
jsonpath "$.cities" not contains "GRlady"
jsonpath "$.cities" not contains "GRclosed"
jsonpath "$.countries" contains "Grland"
jsonpath "$.countries" not contains "Grclosedland"
jsonpath "$.tags" contains "gr-tag-a"
jsonpath "$.tags" not contains "gr-tag-b"

# 5. A ladies admin: ladies only (GRother and gr-tag-a are gents only)
GET {{base_url}}/admin/class-access/options
Authorization: {{auth_grants_925004}}
HTTP 200
[Asserts]
jsonpath "$.genders" count == 1
jsonpath "$.genders[0].id" == 2
jsonpath "$.genders[0].name" == "Ladies"
jsonpath "$.cities" contains "GRville"
jsonpath "$.cities" contains "GRlady"
jsonpath "$.cities" not contains "GRother"
jsonpath "$.tags" contains "gr-tag-b"
jsonpath "$.tags" not contains "gr-tag-a"
