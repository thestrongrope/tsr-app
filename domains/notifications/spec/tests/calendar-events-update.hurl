# PATCH /classes/{class_id}/scheduled-events/{event_id}: change an event; a field left out keeps its value and the zone never changes. Runs against any implementation.
# WRITES event 9280441 of class 9704 only (no other file uses that class); tools/contract-calendar.sh resets it before each run.
# Variables: base_url and auth_cal_<alias>. Fixtures: db/synthetic/calendar-fixtures.sql. Class 9704 (teacher 928014 = teacher4): events 9280441 (the teacher's: message "Cal Edit me",
# description "Before", link /classes/9704/syllabus, weekdays 2,4 at 07:15, Europe/London), 9280442 (the super administrator's), 9280443 (deleted). 9280421 is an event of class 9702.

# Order: the body is read before the event is looked up
PATCH {{base_url}}/classes/9704/scheduled-events/99999999
Authorization: {{auth_cal_teacher4}}
`not json`
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

# 404 before any field is checked: no such event, a deleted event, another class's event
PATCH {{base_url}}/classes/9704/scheduled-events/99999999
Authorization: {{auth_cal_teacher4}}
{"message": ""}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Scheduled event not found"

PATCH {{base_url}}/classes/9704/scheduled-events/9280443
Authorization: {{auth_cal_teacher4}}
{"message": "Cal x"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Scheduled event not found"

PATCH {{base_url}}/classes/9704/scheduled-events/9280421
Authorization: {{auth_cal_teacher4}}
{"message": "Cal x"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Scheduled event not found"

# 403 before any field is checked: the owner still has access (the teacher on the super administrator's event, and the other way round)
PATCH {{base_url}}/classes/9704/scheduled-events/9280442
Authorization: {{auth_cal_teacher4}}
{"message": ""}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only the owner can change this event while they retain access"

PATCH {{base_url}}/classes/9704/scheduled-events/9280441
Authorization: {{auth_cal_super}}
{"message": "Cal x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only the owner can change this event while they retain access"

# 422: a field sent is checked, null included; nothing is stored
PATCH {{base_url}}/classes/9704/scheduled-events/9280441
Authorization: {{auth_cal_teacher4}}
{"message": null}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Message is required and must be at most 500 characters"

PATCH {{base_url}}/classes/9704/scheduled-events/9280441
Authorization: {{auth_cal_teacher4}}
{"description": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Description must be at most 2000 characters"

PATCH {{base_url}}/classes/9704/scheduled-events/9280441
Authorization: {{auth_cal_teacher4}}
{"send_time": "7:15"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Time must be HH:MM"

PATCH {{base_url}}/classes/9704/scheduled-events/9280441
Authorization: {{auth_cal_teacher4}}
{"action_link": "ftp://example.invalid/x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "action_link must be an https:// link or an in-app path such as /classes/12/syllabus"

PATCH {{base_url}}/classes/9704/scheduled-events/9280441
Authorization: {{auth_cal_teacher4}}
{"weekdays": null}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose between one and seven weekdays"

PATCH {{base_url}}/classes/9704/scheduled-events/9280441
Authorization: {{auth_cal_teacher4}}
{"weekdays": [0]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Weekdays must be integers from 1 (Monday) to 7"

# 200 with an empty body: nothing changes
PATCH {{base_url}}/classes/9704/scheduled-events/9280441
Authorization: {{auth_cal_teacher4}}
{}
HTTP 200
[Asserts]
jsonpath "$.item.key" == "event:9280441"
jsonpath "$.item.id" == 9280441
jsonpath "$.item.message" == "Cal Edit me"
jsonpath "$.item.description" == "Before"
jsonpath "$.item.action_link" == "/classes/9704/syllabus"
jsonpath "$.item.weekdays[0]" == 2
jsonpath "$.item.weekdays[1]" == 4
jsonpath "$.item.send_time" == "07:15"
jsonpath "$.item.timezone" == "Europe/London"

# 200: only the message changes; a zone in the body is ignored (the event keeps its creator's zone)
PATCH {{base_url}}/classes/9704/scheduled-events/9280441
Authorization: {{auth_cal_teacher4}}
{"message": "  Cal Edited  ", "timezone": "Asia/Kolkata"}
HTTP 200
[Asserts]
jsonpath "$.item.message" == "Cal Edited"
jsonpath "$.item.description" == "Before"
jsonpath "$.item.action_link" == "/classes/9704/syllabus"
jsonpath "$.item.weekdays" count == 2
jsonpath "$.item.send_time" == "07:15"
jsonpath "$.item.timezone" == "Europe/London"
jsonpath "$.item.class_id" == 9704
jsonpath "$.item.editable_by_me" == true
jsonpath "$.item.takeover" == false

# 200: null clears the description and the link; the weekdays and the time change; a pasted video link becomes the in-app path
PATCH {{base_url}}/classes/9704/scheduled-events/9280441
Authorization: {{auth_cal_teacher4}}
{"description": null, "action_link": null, "weekdays": [7, 6], "send_time": "23:05"}
HTTP 200
[Asserts]
jsonpath "$.item.message" == "Cal Edited"
jsonpath "$.item.description" == null
jsonpath "$.item.action_link" == null
jsonpath "$.item.weekdays[0]" == 6
jsonpath "$.item.weekdays[1]" == 7
jsonpath "$.item.send_time" == "23:05"

PATCH {{base_url}}/classes/9704/scheduled-events/9280441
Authorization: {{auth_cal_teacher4}}
{"action_link": "https://youtu.be/calvideo1"}
HTTP 200
[Asserts]
jsonpath "$.item.action_link" == "/videos/calvideo1"

# The list shows the stored result; the super administrator's event is untouched
GET {{base_url}}/classes/9704/scheduled-events
Authorization: {{auth_cal_teacher4}}
HTTP 200
[Asserts]
jsonpath "$.events" count == 2
jsonpath "$.events[0].id" == 9280441
jsonpath "$.events[0].message" == "Cal Edited"
jsonpath "$.events[0].send_time" == "23:05"
jsonpath "$.events[1].id" == 9280442
jsonpath "$.events[1].message" == "Cal Super event"
