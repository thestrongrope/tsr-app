# The guards of the six calendar routes: the sign-in, then (class routes) notifications:send on the class. Runs against any implementation. Reads only.
# Variables: base_url and auth_cal_<alias> (tools/contract-calendar.sh). Fixtures: db/synthetic/calendar-fixtures.sql. Class 9701: teacher 928011 (teacher1), student 928023 (student1);
# 928001 (member) is in no class; 928012 (teacher2) teaches 9702 only. The class is not looked up before the permission, so an unknown class is the same 403.

GET {{base_url}}/me/calendar
HTTP 401

PUT {{base_url}}/me/calendar/settings
{"device_key": "calguardsdevice01", "changes": []}
HTTP 401

GET {{base_url}}/classes/9701/scheduled-events
HTTP 401

POST {{base_url}}/classes/9701/scheduled-events
{"message": "m"}
HTTP 401

PATCH {{base_url}}/classes/9701/scheduled-events/1
{"message": "m"}
HTTP 401

DELETE {{base_url}}/classes/9701/scheduled-events/1
HTTP 401

# 403: a student of the class, on all four class routes; the permission is checked before the body and before the event is looked up
GET {{base_url}}/classes/9701/scheduled-events
Authorization: {{auth_cal_student1}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You cannot manage events for this class"

POST {{base_url}}/classes/9701/scheduled-events
Authorization: {{auth_cal_student1}}
`not json`
HTTP 403
[Asserts]
jsonpath "$.detail" == "You cannot manage events for this class"

PATCH {{base_url}}/classes/9701/scheduled-events/99999999
Authorization: {{auth_cal_student1}}
`not json`
HTTP 403
[Asserts]
jsonpath "$.detail" == "You cannot manage events for this class"

DELETE {{base_url}}/classes/9701/scheduled-events/99999999
Authorization: {{auth_cal_student1}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You cannot manage events for this class"

# 403: a member in no class, and the teacher of another class
GET {{base_url}}/classes/9701/scheduled-events
Authorization: {{auth_cal_member}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You cannot manage events for this class"

POST {{base_url}}/classes/9701/scheduled-events
Authorization: {{auth_cal_teacher2}}
{"message": "Cal guard", "weekdays": [1], "send_time": "09:00", "timezone": "Asia/Kolkata"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You cannot manage events for this class"

DELETE {{base_url}}/classes/9701/scheduled-events/1
Authorization: {{auth_cal_teacher2}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You cannot manage events for this class"

# 403, not 404: a class that does not exist
GET {{base_url}}/classes/99999999/scheduled-events
Authorization: {{auth_cal_teacher1}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You cannot manage events for this class"

# 200: the class's teacher and a super administrator (class 9701 has no event and no slot)
GET {{base_url}}/classes/9701/scheduled-events
Authorization: {{auth_cal_teacher1}}
HTTP 200
[Asserts]
jsonpath "$.events" count == 0
jsonpath "$.slots" count == 0

GET {{base_url}}/classes/9701/scheduled-events
Authorization: {{auth_cal_super}}
HTTP 200
[Asserts]
jsonpath "$.events" count == 0
jsonpath "$.slots" count == 0
