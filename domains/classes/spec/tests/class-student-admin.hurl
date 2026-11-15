# PUT /classes/{class_id}/students/{token}/class-admin contract: set or clear a student's MCQ-admin flag; answers with the roster. Runs against any implementation.
# Variables: base_url and auth_<alias>. WRITE fixtures (reset by tools/classes-contract.sh): class 9401 (gents; teacher 900401; students 900411 and 900412, 900413 removed), the write admin 900331.

# 1. Without sign-in: 401
PUT {{base_url}}/classes/9401/students/900411/class-admin
{"status": true}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Unknown or closed class: 404 before the permission check
PUT {{base_url}}/classes/999999/students/900411/class-admin
Authorization: {{auth_student_g}}
{"status": true}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

PUT {{base_url}}/classes/9303/students/900311/class-admin
Authorization: {{auth_wr_admin}}
{"status": true}
HTTP 404

# 3. A student, an outsider and another class's teacher: 403
PUT {{base_url}}/classes/9401/students/900411/class-admin
Authorization: {{auth_wr_student1}}
{"status": true}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to set the MCQ-admin flag"

PUT {{base_url}}/classes/9401/students/900411/class-admin
Authorization: {{auth_outsider}}
{"status": true}
HTTP 403

PUT {{base_url}}/classes/9401/students/900411/class-admin
Authorization: {{auth_teacher_l}}
{"status": true}
HTTP 403

# 4. A member who is not on the active roster (removed, outsider, no such member): 404 before the body is read
PUT {{base_url}}/classes/9401/students/900413/class-admin
Authorization: {{auth_wr_admin}}
{"status": true}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Student not found in this class"

PUT {{base_url}}/classes/9401/students/900313/class-admin
Authorization: {{auth_wr_admin}}
{"status": true}
HTTP 404

PUT {{base_url}}/classes/9401/students/999999999/class-admin
Authorization: {{auth_wr_admin}}
{"status": true}
HTTP 404

# 5. The body: status must be a JSON true or false
PUT {{base_url}}/classes/9401/students/900411/class-admin
Authorization: {{auth_wr_admin}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "status must be true or false"

PUT {{base_url}}/classes/9401/students/900411/class-admin
Authorization: {{auth_wr_admin}}
{"status": "true"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "status must be true or false"

PUT {{base_url}}/classes/9401/students/900411/class-admin
Authorization: {{auth_wr_admin}}
{"status": 1}
HTTP 422

PUT {{base_url}}/classes/9401/students/900411/class-admin
Authorization: {{auth_wr_admin}}
{"status": null}
HTTP 422

PUT {{base_url}}/classes/9401/students/900411/class-admin
Authorization: {{auth_wr_admin}}
Content-Type: application/json
```
{"status": tru
```
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

# 6. The admin sets the flag: the roster in the answer shows it, with contacts and the transfer history
PUT {{base_url}}/classes/9401/students/900411/class-admin
Authorization: {{auth_wr_admin}}
{"status": true}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.students" count == 2
jsonpath "$.students[?(@.token==900411)].mcqAdmin" == true
jsonpath "$.students[?(@.token==900411)].email" == "wr.student.one@example.invalid"
jsonpath "$.students[?(@.token==900412)].mcqAdmin" == false
jsonpath "$.removedStudents[?(@.token==900413)].removedReason" == "Wr removed"
jsonpath "$.mcqStudents" count == 0
jsonpath "$.transferHistory" count == 0

# ... and the roster read afterwards shows it
GET {{base_url}}/classes/9401/students
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students[?(@.token==900411)].mcqAdmin" == true
jsonpath "$.students[?(@.token==900412)].mcqAdmin" == false

# 7. The class's teacher may clear it; the answer has no contact details and no transfer history
PUT {{base_url}}/classes/9401/students/900411/class-admin
Authorization: {{auth_wr_teacher1}}
{"status": false}
HTTP 200
[Asserts]
jsonpath "$.students[?(@.token==900411)].mcqAdmin" == false
jsonpath "$.students[?(@.token==900411)].email" == null
jsonpath "$.students[?(@.token==900411)].mobile" == null
jsonpath "$.students[?(@.token==900411)].notes" == null
jsonpath "$.students[?(@.token==900411)].name" == "Wr Student One"
jsonpath "$.removedStudents[?(@.token==900413)].email" == null
jsonpath "$.transferHistory" == null

GET {{base_url}}/classes/9401/students
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students[?(@.token==900411)].mcqAdmin" == false
