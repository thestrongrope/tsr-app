# GET /syllabus/levels contract: every class level, with its sort order. Runs against any implementation.
# Variables: base_url and auth_<alias>. The five levels are PHP's: 1 SALMAN, 2 ABUZAR, 3 MIQDAD, 4 AMMAR, 5 BILAL.

# 1. Without sign-in: 401
GET {{base_url}}/syllabus/levels
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Any signed-in member holds syllabus:read: the levels with id, code, name and sort_order
GET {{base_url}}/syllabus/levels
Authorization: {{auth_outsider}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$" count == 5
jsonpath "$[0].id" == 1
jsonpath "$[0].code" == "SM"
jsonpath "$[0].name" == "SALMAN"
jsonpath "$[0].sort_order" == 1
jsonpath "$[2].name" == "MIQDAD"
jsonpath "$[4].id" == 5
jsonpath "$[4].sort_order" == 5
jsonpath "$[0].sortOrder" not exists
