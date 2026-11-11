# GET /admin/transfers/classes/{class_id}/students contract: who can be moved out of a class (contact details included). Runs against any implementation.
# Variables: base_url and auth_<alias>. B4a fixtures: 9511 (900931 joined 2025-09-02, 900932 joined 2025-09-01 active; 900933 removed; 900934 status I), 9512 (closed: cohort 900941 and 900942 removed 2025-10-05 with
# "Class deactivated: ..."; 900943 left earlier; 900944 in the cohort but active in 9513), 9513 (900944), 9515 (closed, nobody); the admin 900902 (role 1).

# 1. Without sign-in: 401
GET {{base_url}}/admin/transfers/classes/9511/students
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Only students:transfer
GET {{base_url}}/admin/transfers/classes/9511/students
Authorization: {{auth_en_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only administrators can transfer students"

# 3. An unknown class, and a path that is not a number, are 404
GET {{base_url}}/admin/transfers/classes/999999/students
Authorization: {{auth_b4_read}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/admin/transfers/classes/abc/students
Authorization: {{auth_b4_read}}
HTTP 404

# 4. An active class: its active students by name, with the first enrolment's day
GET {{base_url}}/admin/transfers/classes/9511/students
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 2
jsonpath "$.students[0].token" == 900931
jsonpath "$.students[0].name" == "B4 Member 900931"
jsonpath "$.students[0].email" == "b4.900931@example.invalid"
jsonpath "$.students[0].mobile" == "+910000090931"
jsonpath "$.students[0].joinedOn" == "2025-09-02"
jsonpath "$.students[0].removedOn" == null
jsonpath "$.students[0].fromDeactivation" == false
jsonpath "$.students[1].token" == 900932
jsonpath "$.students[1].joinedOn" == "2025-09-01"

# 5. A closed class with no active student: the students it had when it was deactivated, unless they are active somewhere
GET {{base_url}}/admin/transfers/classes/9512/students
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 2
jsonpath "$.students[0].token" == 900941
jsonpath "$.students[0].joinedOn" == null
jsonpath "$.students[0].removedOn" == "2025-10-05"
jsonpath "$.students[0].fromDeactivation" == true
jsonpath "$.students[1].token" == 900942

# 6. A class with one active student, and a closed class with nobody
GET {{base_url}}/admin/transfers/classes/9513/students
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 1
jsonpath "$.students[0].fromDeactivation" == false

GET {{base_url}}/admin/transfers/classes/9515/students
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 0
