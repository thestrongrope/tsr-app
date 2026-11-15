# GET /classes/{class_id}/guide contract: the guide of the class's level. Runs against any implementation (tools/classes-contract.sh).
# Variables: base_url and auth_<alias>. Fixtures: class 9301 (gents, MIQDAD, has a guide), 9302 (ladies, BILAL, blank guide), 9303 (closed).

# 1. Without sign-in: 401
GET {{base_url}}/classes/9301/guide
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A member without a numeric gender: 400, before the class is looked up
GET {{base_url}}/classes/9301/guide
Authorization: {{auth_nogender}}
HTTP 400
[Asserts]
jsonpath "$.detail" == "User gender not set; update profile first"

# 3. An unknown, a non-numeric and a closed class: 404
GET {{base_url}}/classes/999999/guide
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/classes/abc/guide
Authorization: {{auth_student_g}}
HTTP 404

GET {{base_url}}/classes/9303/guide
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 4. A member who is not in the class: 403 with PHP's text
GET {{base_url}}/classes/9301/guide
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/classes/9301/guide
Authorization: {{auth_student_l}}
HTTP 403

# 5. A student, and the class's teacher, get the guide untouched with the level's name
GET {{base_url}}/classes/9301/guide
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$.guide" == "<p>Cls Miqdad guide</p>"
jsonpath "$.level_name" == "MIQDAD"
jsonpath "$.share_url" == null

GET {{base_url}}/classes/9301/guide
Authorization: {{auth_teacher_g}}
HTTP 200
[Asserts]
jsonpath "$.guide" == "<p>Cls Miqdad guide</p>"

# 6. A blank guide answers 200 with nulls and the level name
GET {{base_url}}/classes/9302/guide
Authorization: {{auth_student_l}}
HTTP 200
[Asserts]
jsonpath "$.guide" == null
jsonpath "$.share_url" == null
jsonpath "$.level_name" == "BILAL"
