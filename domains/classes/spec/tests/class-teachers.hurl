# GET /classes/{class_id}/teachers contract: teacher candidates for an existing class. Runs against any implementation.
# Variables: base_url and auth_<alias>. Pool: active students of any class (see class-create-teachers.hurl). Class 9301 is gents, 9302 ladies, 9303 closed.

# 1. Without sign-in: 401
GET {{base_url}}/classes/9301/teachers?q=Cls
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Unknown or closed class: 404
GET {{base_url}}/classes/999999/teachers?q=Cls
Authorization: {{auth_admin}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/classes/9303/teachers?q=Cls
Authorization: {{auth_admin}}
HTTP 404

# 3. The class's own teacher and a student may not manage it: 403
GET {{base_url}}/classes/9301/teachers?q=Cls
Authorization: {{auth_teacher_g}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage this class"

GET {{base_url}}/classes/9301/teachers?q=Cls
Authorization: {{auth_student_g}}
HTTP 403

# 4. A gents class takes gents only
GET {{base_url}}/classes/9301/teachers?q=Cls
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.teachers" count == 2
jsonpath "$.teachers[0].token" == 900322
jsonpath "$.teachers[0].name" == "Cls Child One"
jsonpath "$.teachers[1].token" == 900311
jsonpath "$.teachers[1].name" == "Cls Student Gents"

# 5. A ladies class takes anyone
GET {{base_url}}/classes/9302/teachers?q=Cls
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.teachers" count == 4

GET {{base_url}}/classes/9301/teachers?q=900312
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.teachers" count == 0

GET {{base_url}}/classes/9302/teachers?q=900312
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.teachers" count == 1
jsonpath "$.teachers[0].token" == 900312

# 6. No text: an empty list
GET {{base_url}}/classes/9301/teachers
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.teachers" count == 0
