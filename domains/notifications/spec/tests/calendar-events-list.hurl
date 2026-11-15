# GET /classes/{class_id}/scheduled-events: a class's live events and live timetable slots, for who manages it. Runs against any implementation. Reads only.
# Variables: base_url and auth_cal_<alias>. Fixtures: db/synthetic/calendar-fixtures.sql. Class 9702 (teacher 928012 = teacher2): events 9280421 (the teacher's), 9280422 (the super
# administrator's, who still has access, so the teacher may not edit it), 9280423 (deleted); slots 9280202 (live) and 9280203 (deleted). No file changes class 9702.

GET {{base_url}}/classes/9702/scheduled-events
Authorization: {{auth_cal_teacher2}}
HTTP 200
[Asserts]
jsonpath "$.events" count == 2
jsonpath "$.events[0].key" == "event:9280421"
jsonpath "$.events[0].id" == 9280421
jsonpath "$.events[0].kind" == "event"
jsonpath "$.events[0].class_id" == 9702
jsonpath "$.events[0].message" == "Cal Read the lesson"
jsonpath "$.events[0].description" == "Chapter two"
jsonpath "$.events[0].action_link" == "/classes/9702/syllabus"
jsonpath "$.events[0].weekdays" count == 2
jsonpath "$.events[0].weekdays[0]" == 1
jsonpath "$.events[0].weekdays[1]" == 3
jsonpath "$.events[0].send_time" == "18:30"
jsonpath "$.events[0].timezone" == "Asia/Kolkata"
jsonpath "$.events[0].created_by_user_id" isInteger
jsonpath "$.events[0].editable_by_me" == true
jsonpath "$.events[0].takeover" == false
jsonpath "$.events[1].id" == 9280422
jsonpath "$.events[1].description" == null
jsonpath "$.events[1].action_link" == null
jsonpath "$.events[1].weekdays[0]" == 5
jsonpath "$.events[1].send_time" == "07:05"
jsonpath "$.events[1].timezone" == "Europe/London"
jsonpath "$.events[1].editable_by_me" == false
jsonpath "$.events[1].takeover" == false
jsonpath "$.slots" count == 1
jsonpath "$.slots[0].key" == "slot:9280202"
jsonpath "$.slots[0].id" not exists
jsonpath "$.slots[0].kind" == "slot"
jsonpath "$.slots[0].class_id" == 9702
jsonpath "$.slots[0].message" == "Class timetable"
jsonpath "$.slots[0].description" == null
jsonpath "$.slots[0].action_link" == "/classes/9702/dashboard"
jsonpath "$.slots[0].weekdays" count == 1
jsonpath "$.slots[0].weekdays[0]" == 2
jsonpath "$.slots[0].send_time" == "18:05"
jsonpath "$.slots[0].timezone" == "Europe/London"
jsonpath "$.slots[0].editable_by_me" == false
jsonpath "$.slots[0].takeover" == false

# The super administrator sees the same two events and may edit only their own: the teacher still has access, so there is no take-over
GET {{base_url}}/classes/9702/scheduled-events
Authorization: {{auth_cal_super}}
HTTP 200
[Asserts]
jsonpath "$.events" count == 2
jsonpath "$.events[0].id" == 9280421
jsonpath "$.events[0].editable_by_me" == false
jsonpath "$.events[0].takeover" == false
jsonpath "$.events[1].id" == 9280422
jsonpath "$.events[1].editable_by_me" == true
jsonpath "$.events[1].takeover" == false
