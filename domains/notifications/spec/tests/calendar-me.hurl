# GET /me/calendar: the member's calendar as a student: the live events and slots of the live classes they are enrolled in, minus what they deleted for themselves, plus their settings.
# Runs against any implementation. Reads only.
# Variables: base_url and auth_cal_<alias>. Fixtures: db/synthetic/calendar-fixtures.sql. 928021 (reader) is a student of class 9702 (events 9280421 and 9280422 live, 9280423 deleted;
# slot 9280202 live, 9280203 deleted) and of the closed class 9709; two settings are stored for them: 9280421 muted with a 15 minute alert, 9280422 deleted for them. No file changes
# class 9702 or this member's settings.

GET {{base_url}}/me/calendar
Authorization: {{auth_cal_reader}}
HTTP 200
[Asserts]
jsonpath "$.server_time" matches /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/
jsonpath "$.freshness.max_hours" == 12
jsonpath "$.freshness.target_hours" == 6
# The closed class 9709 is left out
jsonpath "$.classes" count == 1
jsonpath "$.classes[0].class_id" == 9702
jsonpath "$.classes[0].code" == "CAL-G-702"
jsonpath "$.classes[0].name" == "Cal Class Read"
# 9280422 is hidden (deleted for this member), 9280423 is deleted for everyone
jsonpath "$.classes[0].events" count == 1
jsonpath "$.classes[0].events[0].key" == "event:9280421"
jsonpath "$.classes[0].events[0].id" == 9280421
jsonpath "$.classes[0].events[0].kind" == "event"
jsonpath "$.classes[0].events[0].class_id" == 9702
jsonpath "$.classes[0].events[0].message" == "Cal Read the lesson"
jsonpath "$.classes[0].events[0].description" == "Chapter two"
jsonpath "$.classes[0].events[0].action_link" == "/classes/9702/syllabus"
jsonpath "$.classes[0].events[0].weekdays[0]" == 1
jsonpath "$.classes[0].events[0].weekdays[1]" == 3
jsonpath "$.classes[0].events[0].send_time" == "18:30"
jsonpath "$.classes[0].events[0].timezone" == "Asia/Kolkata"
jsonpath "$.classes[0].events[0].created_by_user_id" isInteger
jsonpath "$.classes[0].events[0].editable_by_me" == false
jsonpath "$.classes[0].events[0].takeover" == false
jsonpath "$.classes[0].slots" count == 1
jsonpath "$.classes[0].slots[0].key" == "slot:9280202"
jsonpath "$.classes[0].slots[0].kind" == "slot"
jsonpath "$.classes[0].slots[0].message" == "Class timetable"
jsonpath "$.classes[0].slots[0].action_link" == "/classes/9702/dashboard"
jsonpath "$.classes[0].slots[0].weekdays[0]" == 2
jsonpath "$.classes[0].slots[0].send_time" == "18:05"
jsonpath "$.classes[0].slots[0].timezone" == "Europe/London"
jsonpath "$.classes[0].slots[0].editable_by_me" == false
# Every setting is answered, the tombstone too
jsonpath "$.settings['event:9280421'].offset_minutes" == -15
jsonpath "$.settings['event:9280421'].muted" == true
jsonpath "$.settings['event:9280421'].deleted" == false
jsonpath "$.settings['event:9280421'].updated_at" == "2026-11-10T08:00:00.000Z"
jsonpath "$.settings['event:9280421'].server_updated_at" == "2026-11-10T08:00:01.500Z"
jsonpath "$.settings['event:9280421'].device_key" == "calfixturedevice01"
jsonpath "$.settings['event:9280422'].offset_minutes" == null
jsonpath "$.settings['event:9280422'].muted" == false
jsonpath "$.settings['event:9280422'].deleted" == true

# The class's teacher is not its student: the calendar is empty, and the settings are an empty object
GET {{base_url}}/me/calendar
Authorization: {{auth_cal_teacher2}}
HTTP 200
[Asserts]
jsonpath "$.classes" count == 0
body contains "\"settings\":{}"

# A super administrator and a member in no class: empty too
GET {{base_url}}/me/calendar
Authorization: {{auth_cal_super}}
HTTP 200
[Asserts]
jsonpath "$.classes" count == 0

GET {{base_url}}/me/calendar
Authorization: {{auth_cal_member}}
HTTP 200
[Asserts]
jsonpath "$.classes" count == 0
body contains "\"settings\":{}"
