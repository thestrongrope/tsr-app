# Scheduled class notifications: the routes past the guards. NEW API ONLY (the parity PHP database has no class_scheduled_notifications table; the guards run on both in notify-scheduled.hurl).
# Variables: base_url and auth_nf_<alias>. Fixtures: db/synthetic/notify-fixtures.sql. Class 98605 (teacher 926035) has the slots 9760202 (live, Tuesday 18:30 Asia/Kolkata) and 9760203 (deleted); class 98606 (teacher 926036) the slot 9760204 and
# is where this file proves that a row of another class is not reachable. The worker that SENDS a scheduled notification does not exist in the new API: nothing here fires (test-notify-notes.md).
# Rate limit: 20 creates an hour per member, and only a create that passed every check counts; this file makes four for 926035.

# 422s, in PHP's order after the kind: the cap, the zone, then the kind's own fields
POST {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
{"title": "T", "body": "B", "kind": "ONCE"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "timezone is required and must be an IANA time zone name such as Asia/Kolkata"

POST {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
{"title": "T", "body": "B", "kind": "ONCE", "timezone": "Not/AZone"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "timezone is required and must be an IANA time zone name such as Asia/Kolkata"

POST {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
{"title": "T", "body": "B", "kind": "ONCE", "timezone": "Asia/Kolkata"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "send_at is required for a ONCE notification"

POST {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
{"title": "T", "body": "B", "kind": "ONCE", "timezone": "Asia/Kolkata", "send_at": "2099-13-01T10:00"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "send_at must be a local date and time such as 2026-11-10T18:30, without an offset"

POST {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
{"title": "T", "body": "B", "kind": "ONCE", "timezone": "Asia/Kolkata", "send_at": "2099-01-05T10:00+05:30"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "send_at must be a local date and time such as 2026-11-10T18:30, without an offset"

POST {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
{"title": "T", "body": "B", "kind": "ONCE", "timezone": "Asia/Kolkata", "send_at": "2020-01-01T10:00"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "send_at must be in the future"

POST {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
{"title": "T", "body": "B", "kind": "WEEKLY", "timezone": "Asia/Kolkata", "send_time": "07:30"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "weekdays must be a non-empty list of ISO weekdays (1-7)"

POST {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
{"title": "T", "body": "B", "kind": "WEEKLY", "timezone": "Asia/Kolkata", "weekdays": [8], "send_time": "07:30"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "weekdays must be ISO weekdays (1-7)"

POST {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
{"title": "T", "body": "B", "kind": "WEEKLY", "timezone": "Asia/Kolkata", "weekdays": [1], "send_time": "7:30"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "send_time must be HH:MM"

# REMINDER: a slot of ANOTHER class, a deleted slot, an offset beyond a week, no offset
POST {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
{"title": "T", "body": "B", "kind": "REMINDER", "timezone": "Asia/Kolkata", "class_schedule_id": 9760204, "offset_minutes": -30}
HTTP 422
[Asserts]
jsonpath "$.detail" == "class_schedule_id must be one of this class's schedule slots"

POST {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
{"title": "T", "body": "B", "kind": "REMINDER", "timezone": "Asia/Kolkata", "class_schedule_id": 9760203, "offset_minutes": -30}
HTTP 422
[Asserts]
jsonpath "$.detail" == "class_schedule_id must be one of this class's schedule slots"

POST {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
{"title": "T", "body": "B", "kind": "REMINDER", "timezone": "Asia/Kolkata", "class_schedule_id": 9760202, "offset_minutes": 99999}
HTTP 422
[Asserts]
jsonpath "$.detail" == "offset_minutes must be within one week of the class"

POST {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
{"title": "T", "body": "B", "kind": "REMINDER", "timezone": "Asia/Kolkata", "class_schedule_id": 9760202}
HTTP 422
[Asserts]
jsonpath "$.detail" == "offset_minutes is required and must be a whole number"

# Nothing was created by the refusals
GET {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
HTTP 200
[Asserts]
jsonpath "$.items" count == 0
jsonpath "$.schedules" count == 1
jsonpath "$.schedules[0].id" == 9760202
jsonpath "$.schedules[0].day" == 2
jsonpath "$.schedules[0].hour" == 18
jsonpath "$.schedules[0].minute" == 30
jsonpath "$.schedules[0].timezone" == "Asia/Kolkata"

# ONCE: 201, the wall clock kept with no offset, next_run in the zone's offset (a date far ahead, so the answer does not depend on today)
POST {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
{"title": " Once ", "body": "B", "kind": "once", "timezone": "Asia/Calcutta", "send_at": "2099-01-05 10:00", "action_link": "https://thestrongrope.com/articles/some-slug"}
HTTP 201
[Captures]
once_id: jsonpath "$.item.id"
[Asserts]
jsonpath "$.success" == true
jsonpath "$.item.kind" == "ONCE"
jsonpath "$.item.title" == "Once"
jsonpath "$.item.action_link" == "/articles/some-slug"
jsonpath "$.item.status" == "active"
jsonpath "$.item.created_by" == 926035
jsonpath "$.item.creator_name" == "Nf Member 926035"
jsonpath "$.item.send_at" == "2099-01-05T10:00:00"
jsonpath "$.item.next_run" == "2099-01-05T10:00:00+05:30"
jsonpath "$.item.timezone" == "Asia/Kolkata"
jsonpath "$.item.weekdays" count == 0
jsonpath "$.item.send_time" == null
jsonpath "$.item.class_schedule_id" == null
jsonpath "$.item.repeat_weekly" == false
jsonpath "$.item.schedule" == null
jsonpath "$.item.last_run" == null
jsonpath "$.item.created_at" matches /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$/

# WEEKLY: weekdays sorted and de-duplicated, the time as HH:MM
POST {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
{"title": "Weekly", "body": "B", "kind": "WEEKLY", "timezone": "Asia/Kolkata", "weekdays": [3, 1, 3], "send_time": "07:30"}
HTTP 201
[Captures]
weekly_id: jsonpath "$.item.id"
[Asserts]
jsonpath "$.item.kind" == "WEEKLY"
jsonpath "$.item.weekdays[0]" == 1
jsonpath "$.item.weekdays[1]" == 3
jsonpath "$.item.weekdays" count == 2
jsonpath "$.item.send_time" == "07:30"
jsonpath "$.item.send_at" == null
jsonpath "$.item.next_run" matches /^[0-9]{4}-[0-9]{2}-[0-9]{2}T07:30:00\+05:30$/

# REMINDER on the class's own live slot: timed from the slot's zone; repeat_weekly kept
POST {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
{"title": "Reminder", "body": "B", "kind": "REMINDER", "timezone": "Asia/Kolkata", "class_schedule_id": 9760202, "offset_minutes": -30, "repeat_weekly": true}
HTTP 201
[Captures]
reminder_id: jsonpath "$.item.id"
[Asserts]
jsonpath "$.item.kind" == "REMINDER"
jsonpath "$.item.class_schedule_id" == 9760202
jsonpath "$.item.offset_minutes" == -30
jsonpath "$.item.repeat_weekly" == true
jsonpath "$.item.schedule.id" == 9760202
jsonpath "$.item.schedule.day" == 2
jsonpath "$.item.schedule.hour" == 18
jsonpath "$.item.schedule.minute" == 30
jsonpath "$.item.schedule.timezone" == "Asia/Kolkata"
jsonpath "$.item.next_run" matches /^[0-9]{4}-[0-9]{2}-[0-9]{2}T18:00:00\+05:30$/

# The list: newest first, the slots beside it
GET {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
HTTP 200
[Asserts]
jsonpath "$.items" count == 3
jsonpath "$.items[0].id" == {{reminder_id}}
jsonpath "$.items[1].id" == {{weekly_id}}
jsonpath "$.items[2].id" == {{once_id}}
jsonpath "$.schedules" count == 1

# Only the class's sender lists: the other class's teacher is refused, and sees none of these rows in their own list
GET {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher6}}
HTTP 403

GET {{base_url}}/classes/98606/notifications/scheduled
Authorization: {{auth_nf_teacher6}}
HTTP 200
[Asserts]
jsonpath "$.items" count == 0

# Delete: another class's route cannot reach the row (404), the other class's teacher cannot delete in this class (403), a missing id is 404, the sender's own delete works once
DELETE {{base_url}}/classes/98606/notifications/scheduled/{{once_id}}
Authorization: {{auth_nf_teacher6}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Scheduled notification not found"

DELETE {{base_url}}/classes/98605/notifications/scheduled/{{once_id}}
Authorization: {{auth_nf_teacher6}}
HTTP 403

DELETE {{base_url}}/classes/98605/notifications/scheduled/99999999
Authorization: {{auth_nf_teacher5}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Scheduled notification not found"

DELETE {{base_url}}/classes/98605/notifications/scheduled/{{once_id}}
Authorization: {{auth_nf_teacher5}}
HTTP 200
[Asserts]
jsonpath "$.success" == true

DELETE {{base_url}}/classes/98605/notifications/scheduled/{{once_id}}
Authorization: {{auth_nf_teacher5}}
HTTP 404

GET {{base_url}}/classes/98605/notifications/scheduled
Authorization: {{auth_nf_teacher5}}
HTTP 200
[Asserts]
jsonpath "$.items" count == 2
