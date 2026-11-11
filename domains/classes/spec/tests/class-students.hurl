# GET /classes/{class_id}/students contract: a class's active roster. Runs against any implementation.
# Variables: base_url and auth_<alias>. Fixtures: class 9301 holds 900311 (note) and 900322 (900316 was removed); 9302 holds 900312 and 900323; 9303 is closed.

# 1. Without sign-in: 401
GET {{base_url}}/classes/9301/students
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Unknown or closed class: 404 (before any permission check)
GET {{base_url}}/classes/999999/students
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/classes/9303/students
Authorization: {{auth_admin}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 3. A plain student, an outsider and the teacher of another class: 403
GET {{base_url}}/classes/9301/students
Authorization: {{auth_student_g}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to view this class's students"

GET {{base_url}}/classes/9301/students
Authorization: {{auth_outsider}}
HTTP 403

GET {{base_url}}/classes/9301/students
Authorization: {{auth_teacher_l}}
HTTP 403

# 4. An admin sees the roster by name with contact details and the decoded note; the removed student is absent
GET {{base_url}}/classes/9301/students
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.students" count == 2
jsonpath "$.students[0].token" == 900322
jsonpath "$.students[0].name" == "Cls Child One"
jsonpath "$.students[0].email" == "cls.child.one@example.invalid"
jsonpath "$.students[0].mobile" == null
jsonpath "$.students[0].joinedOn" == "2025-09-01"
jsonpath "$.students[0].notes" == null
jsonpath "$.students[0].mcqAdmin" == false
jsonpath "$.students[1].token" == 900311
jsonpath "$.students[1].name" == "Cls Student Gents"
jsonpath "$.students[1].email" == "cls.student.gents@example.invalid"
jsonpath "$.students[1].mobile" == "+910000003011"
jsonpath "$.students[1].joinedOn" == "2025-09-01"
jsonpath "$.students[1].notes" == "Cls note & more"
jsonpath "$.students[1].mcqAdmin" == false

# 5. The class's own teacher sees names only: email, mobile and notes are null
GET {{base_url}}/classes/9301/students
Authorization: {{auth_teacher_g}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 2
jsonpath "$.students[1].token" == 900311
jsonpath "$.students[1].name" == "Cls Student Gents"
jsonpath "$.students[1].email" == null
jsonpath "$.students[1].mobile" == null
jsonpath "$.students[1].notes" == null
jsonpath "$.students[1].joinedOn" == "2025-09-01"

# 6. The other class
GET {{base_url}}/classes/9302/students
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 2
jsonpath "$.students[0].name" == "Cls Child Two"
jsonpath "$.students[1].name" == "Cls Student Ladies"
jsonpath "$.students[1].joinedOn" == "2025-09-08"
