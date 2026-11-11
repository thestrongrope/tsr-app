# GET /guides/{level_id} contract: the guide as the editor starts from it. Runs against any implementation.
# Variables: base_url and auth_<alias>. Synthetic members only. The fixtures give level 3 a guide and level 4 none.

# 1. Without sign-in: 401
GET {{base_url}}/guides/3
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Without guides:manage: 403 with PHP's text
GET {{base_url}}/guides/3
Authorization: {{auth_student_g}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. A level that has a guide: the text untouched, and the level's name
GET {{base_url}}/guides/3
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.guide" == "<p>Cls Miqdad guide</p>"
jsonpath "$.level_name" == "MIQDAD"

# 4. A level that can have a guide but has no row: guide is null
GET {{base_url}}/guides/4
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.guide" == null
jsonpath "$.level_name" == "AMMAR"

# 5. A level without a guide page (1) and a non-numeric one (cast to 0): 404
GET {{base_url}}/guides/1
Authorization: {{auth_admin}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Level not found"

GET {{base_url}}/guides/abc
Authorization: {{auth_admin}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Level not found"

# 6. The id is PHP's (int) cast: 3abc is level 3
GET {{base_url}}/guides/3abc
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.level_name" == "MIQDAD"
