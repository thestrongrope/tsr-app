# DELETE /classes/{class_id}/scheduled-events/{event_id}: remove an event of a class (the row is kept, marked deleted). Runs against any implementation.
# WRITES event 9280451 of class 9705 only (no other file uses that class); tools/contract-calendar.sh resets it before each run.
# Variables: base_url and auth_cal_<alias>. Fixtures: db/synthetic/calendar-fixtures.sql. Class 9705 (teacher 928015 = teacher5): events 9280451 (the teacher's), 9280452 (the super
# administrator's), 9280453 (deleted). 9280421 is an event of class 9702.

# 404: no such event, an event already deleted, another class's event
DELETE {{base_url}}/classes/9705/scheduled-events/99999999
Authorization: {{auth_cal_teacher5}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Scheduled event not found"

DELETE {{base_url}}/classes/9705/scheduled-events/9280453
Authorization: {{auth_cal_teacher5}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Scheduled event not found"

DELETE {{base_url}}/classes/9705/scheduled-events/9280421
Authorization: {{auth_cal_teacher5}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Scheduled event not found"

# 403: the owner still has access (the teacher on the super administrator's event, and the other way round)
DELETE {{base_url}}/classes/9705/scheduled-events/9280452
Authorization: {{auth_cal_teacher5}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only the owner can delete this event while they retain access"

DELETE {{base_url}}/classes/9705/scheduled-events/9280451
Authorization: {{auth_cal_super}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only the owner can delete this event while they retain access"

GET {{base_url}}/classes/9705/scheduled-events
Authorization: {{auth_cal_teacher5}}
HTTP 200
[Asserts]
jsonpath "$.events" count == 2

# 200: the owner deletes it; it leaves the list, and deleting or editing it again finds nothing
DELETE {{base_url}}/classes/9705/scheduled-events/9280451
Authorization: {{auth_cal_teacher5}}
HTTP 200
[Asserts]
jsonpath "$.success" == true

GET {{base_url}}/classes/9705/scheduled-events
Authorization: {{auth_cal_teacher5}}
HTTP 200
[Asserts]
jsonpath "$.events" count == 1
jsonpath "$.events[0].id" == 9280452

DELETE {{base_url}}/classes/9705/scheduled-events/9280451
Authorization: {{auth_cal_teacher5}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Scheduled event not found"

PATCH {{base_url}}/classes/9705/scheduled-events/9280451
Authorization: {{auth_cal_teacher5}}
{"message": "Cal x"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Scheduled event not found"
