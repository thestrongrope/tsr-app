# POST /classes/{class_id}/students/{token}/restore contract: put a removed student back; answers with the roster. Runs against any implementation.
# Variables: base_url and auth_<alias>. ENROLMENT fixtures (reset by tools/classes-contract.sh): class 9412 (gents; teacher 900511; 900531 removed, 900532 active, 900533 moved away to class 9411),
# the closed class 9417, the gents admin 900501, the ladies admin 900502, the write admin 900331.

# (Every POST carries an empty JSON body: the route reads none, and the gateway refuses a POST with no Content-Length.)
# 1. Without sign-in: 401
POST {{base_url}}/classes/9412/students/900531/restore
{}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Unknown or closed class: 404 before the permission check
POST {{base_url}}/classes/999999/students/900531/restore
Authorization: {{auth_en_student}}
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

POST {{base_url}}/classes/9417/students/900531/restore
Authorization: {{auth_wr_admin}}
{}
HTTP 404

# 3. A student, the class's own teacher, and an admin of the other gender: 403
POST {{base_url}}/classes/9412/students/900531/restore
Authorization: {{auth_en_student}}
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to change this class's students"

POST {{base_url}}/classes/9412/students/900531/restore
Authorization: {{auth_en_teacher}}
{}
HTTP 403

POST {{base_url}}/classes/9412/students/900531/restore
Authorization: {{auth_en_ladmin}}
{}
HTTP 403

# 4. Not on the removed list of THIS class: a live student, a member moved to another class, a stranger, a student of another class
POST {{base_url}}/classes/9412/students/900532/restore
Authorization: {{auth_wr_admin}}
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Student is not in the removed list"

POST {{base_url}}/classes/9412/students/900533/restore
Authorization: {{auth_wr_admin}}
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Student is not in the removed list"

POST {{base_url}}/classes/9412/students/900521/restore
Authorization: {{auth_wr_admin}}
{}
HTTP 404

POST {{base_url}}/classes/9412/students/999999999/restore
Authorization: {{auth_wr_admin}}
{}
HTTP 404

# 5. The gents admin restores the removed student: back on the roster, off the removed list
POST {{base_url}}/classes/9412/students/900531/restore
Authorization: {{auth_en_gadmin}}
{}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.students" count == 2
jsonpath "$.students[?(@.token==900531)].name" == "En Member 900531"
jsonpath "$.students[?(@.token==900531)].mcqAdmin" == false
jsonpath "$.removedStudents" count == 0

GET {{base_url}}/classes/9412/students
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 2

# 6. Restoring a live student again: 404
POST {{base_url}}/classes/9412/students/900531/restore
Authorization: {{auth_wr_admin}}
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Student is not in the removed list"

# 7. Remove then restore round trip as the write admin (contacts shown): the student comes back with no removal data
POST {{base_url}}/classes/9412/students/900532/remove
Authorization: {{auth_wr_admin}}
{"reason": "round trip"}
HTTP 200
[Asserts]
jsonpath "$.removedStudents[?(@.token==900532)].removedReason" == "round trip"

POST {{base_url}}/classes/9412/students/900532/restore
Authorization: {{auth_wr_admin}}
{}
HTTP 200
[Asserts]
jsonpath "$.students" count == 2
jsonpath "$.students[?(@.token==900532)].email" == "en.900532@example.invalid"
jsonpath "$.removedStudents" count == 0
jsonpath "$.mcqStudents" count == 0
