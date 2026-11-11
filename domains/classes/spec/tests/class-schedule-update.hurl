# PUT /classes/{class_id}/schedule contract: replace a class's weekly slots; answers like GET. Runs against any implementation.
# Variables: base_url and auth_<alias>. WRITE fixtures (reset by tools/classes-contract.sh): class 9402 (gents; teacher 900402) with live slots 9401 (day 1, 08:00, Asia/Kolkata) and 9402 (day 3, 09:30, Asia/Dubai)
# and a deleted slot 9403. The read class 9301 owns slot 9301 (day 6, 18:30): an id from another class must not edit it.

# 1. Without sign-in: 401
PUT {{base_url}}/classes/9402/schedule
{"schedules": []}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Unknown or closed class: 404 before the permission check
PUT {{base_url}}/classes/999999/schedule
Authorization: {{auth_student_g}}
{"schedules": []}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

PUT {{base_url}}/classes/9303/schedule
Authorization: {{auth_admin}}
{"schedules": []}
HTTP 404

# 3. A plain student, an outsider and another class's teacher: 403
PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_student_g}}
{"schedules": []}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to set this class's schedule"

PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_outsider}}
{"schedules": []}
HTTP 403

PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_teacher1}}
{"schedules": []}
HTTP 403

# 4. The body (422): not JSON, no list, too long, each slot's fields, the timezone
PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
Content-Type: application/json
```
[
```
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "schedules must be a list of at most 21 entries"

PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
{"schedules": "weekly"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "schedules must be a list of at most 21 entries"

PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
{"schedules": [{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"},{"day":1,"hour":1,"minute":1,"timezone":"Asia/Kolkata"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "schedules must be a list of at most 21 entries"

PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
{"schedules": ["monday"]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "each schedule needs a day (1-7), hour (0-23), minute (0-59) and timezone"

PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
{"schedules": [{"day":0,"hour":1,"minute":1,"timezone":"Asia/Kolkata"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "each schedule needs a day (1-7), hour (0-23), minute (0-59) and timezone"

PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
{"schedules": [{"day":8,"hour":1,"minute":1,"timezone":"Asia/Kolkata"}]}
HTTP 422

PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
{"schedules": [{"day":"1","hour":1,"minute":1,"timezone":"Asia/Kolkata"}]}
HTTP 422

PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
{"schedules": [{"day":1.0,"hour":1,"minute":1,"timezone":"Asia/Kolkata"}]}
HTTP 422

PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
{"schedules": [{"day":1,"hour":24,"minute":1,"timezone":"Asia/Kolkata"}]}
HTTP 422

PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
{"schedules": [{"day":1,"hour":1,"minute":60,"timezone":"Asia/Kolkata"}]}
HTTP 422

PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
{"schedules": [{"day":1,"hour":1,"minute":1}]}
HTTP 422

PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
{"schedules": [{"day":1,"hour":1,"minute":1,"timezone":7}]}
HTTP 422

PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
{"schedules": [{"day":1,"hour":1,"minute":1,"timezone":"Mars/Base"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "timezone is not one of the supported timezones"

# ... and nothing was changed by the refusals
GET {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.schedules" count == 2
jsonpath "$.schedules[?(@.id==9401)].day" == 1
jsonpath "$.schedules[?(@.id==9402)].timezone" == "Asia/Dubai"

# 5. The admin edits slot 9401 in place ("Calcutta" is read as "Kolkata"), adds one, and drops 9402; topics and other fields are ignored
PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
{"schedules": [{"id": 9401, "day": 2, "hour": 7, "minute": 5, "timezone": "Asia/Calcutta", "topics": "ignored", "extra": 1}, {"day": 4, "hour": 20, "minute": 45, "timezone": "Asia/Karachi"}]}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.schedules" count == 2
jsonpath "$.schedules[0].id" == 9401
jsonpath "$.schedules[0].day" == 2
jsonpath "$.schedules[0].hour" == 7
jsonpath "$.schedules[0].minute" == 5
jsonpath "$.schedules[0].timezone" == "Asia/Kolkata"
jsonpath "$.schedules[1].day" == 4
jsonpath "$.schedules[1].hour" == 20
jsonpath "$.schedules[1].minute" == 45
jsonpath "$.schedules[1].timezone" == "Asia/Karachi"
jsonpath "$.schedules[?(@.id==9402)]" not exists
jsonpath "$.schedules[?(@.id==9403)]" not exists
jsonpath "$.timezones[?(@.timezone=='Asia/Kolkata')].label" matches /\S/

GET {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.schedules" count == 2
jsonpath "$.schedules[0].id" == 9401
jsonpath "$.schedules[0].day" == 2

# 6. The class's teacher replaces the schedule; a slot named by another class's id is a new slot and leaves that class alone
PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_teacher2}}
{"schedules": [{"id": 9301, "day": 7, "hour": 6, "minute": 0, "timezone": "Asia/Kolkata"}, {"id": "9401", "day": 1, "hour": 23, "minute": 59, "timezone": "Asia/Kolkata"}]}
HTTP 200
[Asserts]
jsonpath "$.schedules" count == 2
jsonpath "$.schedules[?(@.id==9301)]" not exists
jsonpath "$.schedules[?(@.id==9401)].day" == 1
jsonpath "$.schedules[?(@.id==9401)].hour" == 23
jsonpath "$.schedules[?(@.hour==6)].day" == 7

GET {{base_url}}/classes/9301/schedule
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.schedules[?(@.id==9301)].day" == 6
jsonpath "$.schedules[?(@.id==9301)].hour" == 18

# 7. An empty list clears the schedule
PUT {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
{"schedules": []}
HTTP 200
[Asserts]
jsonpath "$.schedules" count == 0

GET {{base_url}}/classes/9402/schedule
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.schedules" count == 0
