# GET /classes/{class_id}/sessions contract: a class's sessions, newest day first, as a bare array. Runs against any implementation.
# Variables: base_url and auth_<alias>. Fixtures: class 9301 has three sessions (2025-09-20 conducted, 09-13 not conducted, 09-06 conducted).

# 1. Without sign-in: 401
GET {{base_url}}/classes/9301/sessions
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. No numeric gender: 400. Unknown class: 404. Not in the class: 403
GET {{base_url}}/classes/9301/sessions
Authorization: {{auth_nogender}}
HTTP 400
[Asserts]
jsonpath "$.detail" == "User gender not set; update profile first"

GET {{base_url}}/classes/999999/sessions
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/classes/9301/sessions
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. A student and the teacher get all three sessions, newest first, with the wire shape
GET {{base_url}}/classes/9301/sessions
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$" count == 3
jsonpath "$[0].id" isInteger
jsonpath "$[0].conductedOn" == "2025-09-20"
jsonpath "$[0].conducted" == true
jsonpath "$[0].duration" == 45
jsonpath "$[0].attendance" == 1
jsonpath "$[0].aqaedConducted" == true
jsonpath "$[0].arabicConducted" == false
jsonpath "$[0].arabicTopic" == null
jsonpath "$[0].nonConductionReason" == null
jsonpath "$[1].conductedOn" == "2025-09-13"
jsonpath "$[1].conducted" == false
jsonpath "$[1].duration" == null
jsonpath "$[1].nonConductionReason" == "Cls teacher unwell"
jsonpath "$[2].conductedOn" == "2025-09-06"

GET {{base_url}}/classes/9301/sessions
Authorization: {{auth_teacher_g}}
HTTP 200
[Asserts]
jsonpath "$" count == 3

# 4. Paging: pageSize and page cut the list; a junk value falls back (page 0 is 1, pageSize 0 is 1)
GET {{base_url}}/classes/9301/sessions?pageSize=2
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$" count == 2

GET {{base_url}}/classes/9301/sessions?pageSize=2&page=2
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].conductedOn" == "2025-09-06"

GET {{base_url}}/classes/9301/sessions?pageSize=0&page=0
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].conductedOn" == "2025-09-20"
