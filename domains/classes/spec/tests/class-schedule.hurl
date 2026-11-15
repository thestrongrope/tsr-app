# GET /classes/{class_id}/schedule contract: a class's schedule slots and the timezone list. Runs against any implementation.
# Variables: base_url and auth_<alias>. Fixtures: class 9301 has slots 9301 (day 6, 18:30) and 9302 (day 2, 09:15), both Asia/Kolkata; 9302 has one (day 7, 10:00, Asia/Dubai).

# 1. Without sign-in: 401
GET {{base_url}}/classes/9301/schedule
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Unknown or closed class: 404
GET {{base_url}}/classes/999999/schedule
Authorization: {{auth_admin}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/classes/9303/schedule
Authorization: {{auth_admin}}
HTTP 404

# 3. A plain student, an outsider and another class's teacher: 403
GET {{base_url}}/classes/9301/schedule
Authorization: {{auth_student_g}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to set this class's schedule"

GET {{base_url}}/classes/9301/schedule
Authorization: {{auth_outsider}}
HTTP 403

GET {{base_url}}/classes/9301/schedule
Authorization: {{auth_teacher_l}}
HTTP 403

# 4. An admin and the class's teacher get the slots and the 121 zones (first label each, entities decoded)
GET {{base_url}}/classes/9301/schedule
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.schedules" count == 2
jsonpath "$.schedules[0].id" == 9301
jsonpath "$.schedules[0].day" == 6
jsonpath "$.schedules[0].hour" == 18
jsonpath "$.schedules[0].minute" == 30
jsonpath "$.schedules[0].timezone" == "Asia/Kolkata"
jsonpath "$.schedules[1].id" == 9302
jsonpath "$.schedules[1].day" == 2
jsonpath "$.schedules[1].hour" == 9
jsonpath "$.schedules[1].minute" == 15
jsonpath "$.timezones" count == 121
jsonpath "$.timezones[0].timezone" == "Pacific/Midway"
jsonpath "$.timezones[0].label" == "(UTC-11:00) Midway Island"
jsonpath "$.timezones[4].timezone" == "America/Los_Angeles"
jsonpath "$.timezones[4].label" == "(UTC-08:00) Pacific Time (US & Canada)"
jsonpath "$.timezones[120].timezone" == "Pacific/Tongatapu"
jsonpath "$.timezones[120].label" == "(UTC+13:00) Nuku'alofa"

GET {{base_url}}/classes/9301/schedule
Authorization: {{auth_teacher_g}}
HTTP 200
[Asserts]
jsonpath "$.schedules" count == 2
jsonpath "$.timezones" count == 121

# 5. The ladies class
GET {{base_url}}/classes/9302/schedule
Authorization: {{auth_teacher_l}}
HTTP 200
[Asserts]
jsonpath "$.schedules" count == 1
jsonpath "$.schedules[0].day" == 7
jsonpath "$.schedules[0].hour" == 10
jsonpath "$.schedules[0].minute" == 0
jsonpath "$.schedules[0].timezone" == "Asia/Dubai"
