# GET /guides contract: the class levels that can have a guide. Runs against any implementation (tools/classes-contract.sh).
# Variables: base_url and auth_<alias>. Synthetic members only.

# 1. Without sign-in: 401 with a detail
GET {{base_url}}/guides
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A member without guides:manage is refused with PHP's text
GET {{base_url}}/guides
Authorization: {{auth_student_g}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. A super admin gets the four levels that have a guide page (ids 2 to 5), in class level order, with name only
GET {{base_url}}/guides
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.levels" count == 4
jsonpath "$.levels[0].id" == 2
jsonpath "$.levels[0].name" == "ABUZAR"
jsonpath "$.levels[1].name" == "MIQDAD"
jsonpath "$.levels[2].name" == "AMMAR"
jsonpath "$.levels[3].id" == 5
jsonpath "$.levels[3].name" == "BILAL"
jsonpath "$.levels[0].code" not exists
