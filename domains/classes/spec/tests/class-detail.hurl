# GET /classes/{class_id} contract: one class with its schedule. Runs against any implementation.
# Variables: base_url and auth_<alias>. Fixtures: class 9301 (gents; student 900311, teacher 900301), 9302 (ladies), 9303 (closed).

# 1. Without sign-in: 401
GET {{base_url}}/classes/9301
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. An unknown, non-numeric or closed class: 404
GET {{base_url}}/classes/999999
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/classes/abc
Authorization: {{auth_student_g}}
HTTP 404

GET {{base_url}}/classes/9303
Authorization: {{auth_student_g}}
HTTP 404

# 3. Not in the class (never, removed, the other gender's student): 403 with PHP's text
GET {{base_url}}/classes/9301
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/classes/9301
Authorization: {{auth_removed}}
HTTP 403

GET {{base_url}}/classes/9301
Authorization: {{auth_student_l}}
HTTP 403

# 4. A student gets the card and the schedule, without the listing details
GET {{base_url}}/classes/9301
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.id" == 9301
jsonpath "$.code" == "CLS-G-001"
jsonpath "$.name" == "Cls Gents Class"
jsonpath "$.level" == 3
jsonpath "$.levelName" == "MIQDAD"
jsonpath "$.language" == 1
jsonpath "$.gender" == 1
jsonpath "$.status" == "A"
jsonpath "$.location" == "Cls Hall"
jsonpath "$.teacherName" == "Cls Teacher Gents"
jsonpath "$.teacherMobile" == "+910000003001"
jsonpath "$.format" == "Offline"
jsonpath "$.startedOn" == "2025-09-01"
jsonpath "$.role" == "attending"
jsonpath "$.joinUrl" == null
jsonpath "$.schedules" count == 2
jsonpath "$.schedules[0].day" == 2
jsonpath "$.schedules[1].hour" == 18
jsonpath "$.schedules[1].minute" == 30
jsonpath "$.tags" not exists
jsonpath "$.studentCount" not exists

# 5. The teacher: conducting
GET {{base_url}}/classes/9301
Authorization: {{auth_teacher_g}}
HTTP 200
[Asserts]
jsonpath "$.role" == "conducting"

# 6. A super admin opens a class they do not attend: managing
GET {{base_url}}/classes/9301
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.id" == 9301
jsonpath "$.role" == "managing"
jsonpath "$.schedules" count == 2

# 7. A class without schedule rows or location: an empty list and a null location
GET {{base_url}}/classes/9302
Authorization: {{auth_student_l}}
HTTP 200
[Asserts]
jsonpath "$.location" == null
jsonpath "$.format" == "Online"
jsonpath "$.schedules" count == 1
