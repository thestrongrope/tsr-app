# POST /classes/{class_id}/scheduled-events: a sender puts a weekly event on the class's calendar. Runs against any implementation. WRITES rows of class 9703 only (no other file uses it);
# tools/contract-calendar.sh resets them before each run.
# Variables: base_url and auth_cal_<alias>. Fixtures: db/synthetic/calendar-fixtures.sql. Class 9703 (teacher 928013 = teacher3) starts with no event.

# 422s in order: the body, the message, the description, the time, the link, the weekdays, the zone
POST {{base_url}}/classes/9703/scheduled-events
Authorization: {{auth_cal_teacher3}}
`not json`
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

POST {{base_url}}/classes/9703/scheduled-events
Authorization: {{auth_cal_teacher3}}
{"description": 5, "send_time": "x", "weekdays": [], "timezone": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Message is required and must be at most 500 characters"

POST {{base_url}}/classes/9703/scheduled-events
Authorization: {{auth_cal_teacher3}}
{"message": "   ", "weekdays": [1], "send_time": "09:00", "timezone": "Asia/Kolkata"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Message is required and must be at most 500 characters"

POST {{base_url}}/classes/9703/scheduled-events
Authorization: {{auth_cal_teacher3}}
{"message": "m", "description": 5, "send_time": "x", "weekdays": [], "timezone": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Description must be at most 2000 characters"

POST {{base_url}}/classes/9703/scheduled-events
Authorization: {{auth_cal_teacher3}}
{"message": "m", "send_time": "24:00", "action_link": "ftp://example.invalid/x", "weekdays": [], "timezone": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Time must be HH:MM"

POST {{base_url}}/classes/9703/scheduled-events
Authorization: {{auth_cal_teacher3}}
{"message": "m", "send_time": "9:00", "weekdays": [1], "timezone": "Asia/Kolkata"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Time must be HH:MM"

POST {{base_url}}/classes/9703/scheduled-events
Authorization: {{auth_cal_teacher3}}
{"message": "m", "send_time": "09:00", "action_link": "ftp://example.invalid/x", "weekdays": [], "timezone": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "action_link must be an https:// link or an in-app path such as /classes/12/syllabus"

POST {{base_url}}/classes/9703/scheduled-events
Authorization: {{auth_cal_teacher3}}
{"message": "m", "send_time": "09:00", "weekdays": [], "timezone": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose between one and seven weekdays"

POST {{base_url}}/classes/9703/scheduled-events
Authorization: {{auth_cal_teacher3}}
{"message": "m", "send_time": "09:00", "weekdays": [1, 2, 3, 4, 5, 6, 7, 1], "timezone": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose between one and seven weekdays"

POST {{base_url}}/classes/9703/scheduled-events
Authorization: {{auth_cal_teacher3}}
{"message": "m", "send_time": "09:00", "weekdays": [1, 8], "timezone": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Weekdays must be integers from 1 (Monday) to 7"

POST {{base_url}}/classes/9703/scheduled-events
Authorization: {{auth_cal_teacher3}}
{"message": "m", "send_time": "09:00", "weekdays": ["1"], "timezone": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Weekdays must be integers from 1 (Monday) to 7"

POST {{base_url}}/classes/9703/scheduled-events
Authorization: {{auth_cal_teacher3}}
{"message": "m", "send_time": "09:00", "weekdays": [1]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A valid IANA time zone from this phone is required"

POST {{base_url}}/classes/9703/scheduled-events
Authorization: {{auth_cal_teacher3}}
{"message": "m", "send_time": "09:00", "weekdays": [1], "timezone": "Nope/Nowhere"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A valid IANA time zone from this phone is required"

# Nothing was stored by a refusal
GET {{base_url}}/classes/9703/scheduled-events
Authorization: {{auth_cal_teacher3}}
HTTP 200
[Asserts]
jsonpath "$.events" count == 0

# 201: the message is trimmed, the weekdays sorted without repeats, a pasted article link becomes the in-app path, Asia/Calcutta is stored as Asia/Kolkata
POST {{base_url}}/classes/9703/scheduled-events
Authorization: {{auth_cal_teacher3}}
{"message": "  Cal Created event  ", "description": "Bring the book", "action_link": "https://www.thestrongrope.com/articles/cal-article", "weekdays": [5, 1, 5], "send_time": "06:45", "timezone": "Asia/Calcutta"}
HTTP 201
[Captures]
created_id: jsonpath "$.item.id"
[Asserts]
jsonpath "$.item.id" isInteger
jsonpath "$.item.kind" == "event"
jsonpath "$.item.class_id" == 9703
jsonpath "$.item.message" == "Cal Created event"
jsonpath "$.item.description" == "Bring the book"
jsonpath "$.item.action_link" == "/articles/cal-article"
jsonpath "$.item.weekdays" count == 2
jsonpath "$.item.weekdays[0]" == 1
jsonpath "$.item.weekdays[1]" == 5
jsonpath "$.item.send_time" == "06:45"
jsonpath "$.item.timezone" == "Asia/Kolkata"
jsonpath "$.item.created_by_user_id" isInteger
jsonpath "$.item.editable_by_me" == true
jsonpath "$.item.takeover" == false
jsonpath "$.success" not exists

# 201 with the fewest fields: no description, no link
POST {{base_url}}/classes/9703/scheduled-events
Authorization: {{auth_cal_teacher3}}
{"message": "Cal Bare event", "weekdays": [7], "send_time": "23:59", "timezone": "Europe/London"}
HTTP 201
[Asserts]
jsonpath "$.item.message" == "Cal Bare event"
jsonpath "$.item.description" == null
jsonpath "$.item.action_link" == null
jsonpath "$.item.weekdays[0]" == 7
jsonpath "$.item.send_time" == "23:59"
jsonpath "$.item.timezone" == "Europe/London"

# The list has both, in id order, with the key built from the id
GET {{base_url}}/classes/9703/scheduled-events
Authorization: {{auth_cal_teacher3}}
HTTP 200
[Asserts]
jsonpath "$.events" count == 2
jsonpath "$.events[0].id" == {{created_id}}
jsonpath "$.events[0].message" == "Cal Created event"
jsonpath "$.events[1].message" == "Cal Bare event"
