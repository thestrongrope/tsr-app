# POST /classes/{class_id}/students/{token}/remove contract: take a student off a class; answers with the roster. Runs against any implementation.
# Variables: base_url and auth_<alias>. ENROLMENT fixtures (reset by tools/classes-contract.sh): class 9411 (gents; teacher 900511; students 900521 and 900522, 900523 removed), the ladies class 9414,
# the closed class 9417, the other class 9412 (student 900532), the write admin 900331, the gents admin 900501, the ladies admin 900502.

# 1. Without sign-in: 401
POST {{base_url}}/classes/9411/students/900521/remove
{"reason": "x"}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Unknown or closed class: 404 before the permission check
POST {{base_url}}/classes/999999/students/900521/remove
Authorization: {{auth_en_student}}
{"reason": "x"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

POST {{base_url}}/classes/9417/students/900521/remove
Authorization: {{auth_wr_admin}}
{"reason": "x"}
HTTP 404

# 3. A student, the class's own teacher, and an admin of the other gender: 403
POST {{base_url}}/classes/9411/students/900522/remove
Authorization: {{auth_en_student}}
{"reason": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to change this class's students"

POST {{base_url}}/classes/9411/students/900522/remove
Authorization: {{auth_en_teacher}}
{"reason": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to change this class's students"

POST {{base_url}}/classes/9411/students/900522/remove
Authorization: {{auth_en_ladmin}}
{"reason": "x"}
HTTP 403

# 4. A member who is not on the active roster of THIS class (removed, in another class, no such member): 404 before the body is read
POST {{base_url}}/classes/9411/students/900523/remove
Authorization: {{auth_wr_admin}}
{"reason": "x"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Student not found in this class"

POST {{base_url}}/classes/9411/students/900532/remove
Authorization: {{auth_wr_admin}}
{"reason": "x"}
HTTP 404

POST {{base_url}}/classes/9411/students/999999999/remove
Authorization: {{auth_wr_admin}}
{}
HTTP 404

# 5. The reason: required, trimmed, at most 500 characters
POST {{base_url}}/classes/9411/students/900521/remove
Authorization: {{auth_wr_admin}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason is required and must be at most 500 characters"

POST {{base_url}}/classes/9411/students/900521/remove
Authorization: {{auth_wr_admin}}
{"reason": "   "}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason is required and must be at most 500 characters"

POST {{base_url}}/classes/9411/students/900521/remove
Authorization: {{auth_wr_admin}}
{"reason": null}
HTTP 422

POST {{base_url}}/classes/9411/students/900521/remove
Authorization: {{auth_wr_admin}}
{"reason": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason is required and must be at most 500 characters"

POST {{base_url}}/classes/9411/students/900521/remove
Authorization: {{auth_wr_admin}}
Content-Type: application/json
```
{"reason": "tru
```
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

# 6. The gents admin removes a student: the reason is trimmed, the roster shows the removal and who did it
POST {{base_url}}/classes/9411/students/900521/remove
Authorization: {{auth_en_gadmin}}
{"reason": "  moved away  "}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.students" count == 1
jsonpath "$.students[0].token" == 900522
jsonpath "$.removedStudents" count == 2
jsonpath "$.removedStudents[?(@.token==900521)].removedReason" == "moved away"
jsonpath "$.removedStudents[?(@.token==900521)].removedByName" == "En Member 900501"
jsonpath "$.removedStudents[?(@.token==900523)].removedReason" == "En removed"

# ... and the roster read afterwards shows it
GET {{base_url}}/classes/9411/manage
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 1
jsonpath "$.removedStudents[?(@.token==900521)].removedReason" == "moved away"

# 7. Removing the same student again: no longer on the roster, 404
POST {{base_url}}/classes/9411/students/900521/remove
Authorization: {{auth_wr_admin}}
{"reason": "again"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Student not found in this class"

# 8. The write admin removes the last student, with a reason of exactly 500 characters: contacts and the transfer history are shown
POST {{base_url}}/classes/9411/students/900522/remove
Authorization: {{auth_wr_admin}}
{"reason": "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy"}
HTTP 200
[Asserts]
jsonpath "$.students" count == 0
jsonpath "$.removedStudents" count == 3
jsonpath "$.removedStudents[?(@.token==900522)].email" == "en.900522@example.invalid"
jsonpath "$.transferHistory" count == 0
