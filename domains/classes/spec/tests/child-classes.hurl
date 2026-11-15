# GET /me/children/{child_token}/classes contract: the classes a linked child is or was in. Runs against any implementation.
# Variables: base_url and auth_<alias>. Fixtures: parent 900321 has active links to 900322 (in class 9301) and 900324 (in none), and a revoked link to 900323.

# 1. Without sign-in: 401
GET {{base_url}}/me/children/900322/classes
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A child the caller is not actively linked to (revoked link, someone else's child, junk): 404
GET {{base_url}}/me/children/900323/classes
Authorization: {{auth_parent}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Child not found"

GET {{base_url}}/me/children/900322/classes
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Child not found"

GET {{base_url}}/me/children/abc/classes
Authorization: {{auth_parent}}
HTTP 404

# 3. A linked child: the class row, without the class link
GET {{base_url}}/me/children/900322/classes
Authorization: {{auth_parent}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$" count == 1
jsonpath "$[0].class_id" == 9301
jsonpath "$[0].class_name" == "Cls Gents Class"
jsonpath "$[0].class_code" == "CLS-G-001"
jsonpath "$[0].gender" == 1
jsonpath "$[0].teacher_name" == "Cls Teacher Gents"
jsonpath "$[0].started_on" == "2025-09-01"
jsonpath "$[0].enrolment_status" == "A"
jsonpath "$[0].link" not exists

# 4. A linked child in no class: an empty list
GET {{base_url}}/me/children/900324/classes
Authorization: {{auth_parent}}
HTTP 200
[Asserts]
jsonpath "$" count == 0
