# The guards of the scheduled class notification routes (POST, GET /classes/{id}/notifications/scheduled and DELETE .../scheduled/{sid}). Runs against any implementation.
# Variables: base_url and auth_nf_<alias>. Fixtures: db/synthetic/notify-fixtures.sql. Class 98601 (teacher 926031), 98603 closed, 926034 teaches 98604 only.
# ONLY THE GUARDS run here: the parity PHP database lacks the class_scheduled_notifications table (its 2026_11_08 migration is not applied there, and the shared stack is not ours to change), so every PHP path that
# reaches the table dies with a fatal error. Everything from the kind's own fields on is in notify-scheduled-new-api.hurl.

POST {{base_url}}/classes/98601/notifications/scheduled
{"title": "T", "body": "B", "kind": "ONCE"}
HTTP 401

GET {{base_url}}/classes/98601/notifications/scheduled
HTTP 401

DELETE {{base_url}}/classes/98601/notifications/scheduled/1
HTTP 401

# 404: no such class, a closed class (all three verbs)
POST {{base_url}}/classes/99999999/notifications/scheduled
Authorization: {{auth_nf_teacher1}}
{"title": "T", "body": "B", "kind": "ONCE"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/classes/98603/notifications/scheduled
Authorization: {{auth_nf_teacher3}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

DELETE {{base_url}}/classes/99999999/notifications/scheduled/1
Authorization: {{auth_nf_teacher1}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 403: only the class's sender (a plain member and the teacher of another class are refused, all three verbs)
POST {{base_url}}/classes/98601/notifications/scheduled
Authorization: {{auth_nf_member}}
{"title": "T", "body": "B", "kind": "ONCE"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to send notifications for this class"

GET {{base_url}}/classes/98601/notifications/scheduled
Authorization: {{auth_nf_teacher4}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to send notifications for this class"

DELETE {{base_url}}/classes/98601/notifications/scheduled/1
Authorization: {{auth_nf_teacher4}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to send notifications for this class"

# 422s before the table is read: the message rules, then the kind
POST {{base_url}}/classes/98601/notifications/scheduled
Authorization: {{auth_nf_teacher1}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "title is required and must be at most 255 characters"

POST {{base_url}}/classes/98601/notifications/scheduled
Authorization: {{auth_nf_teacher1}}
{"title": "T", "body": ""}
HTTP 422
[Asserts]
jsonpath "$.detail" == "body is required and must be at most 2000 characters"

POST {{base_url}}/classes/98601/notifications/scheduled
Authorization: {{auth_nf_teacher1}}
{"title": "T", "body": "B", "action_link": "ftp://example.invalid/x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "action_link must be an https:// link or an in-app path such as /classes/12/syllabus"

POST {{base_url}}/classes/98601/notifications/scheduled
Authorization: {{auth_nf_teacher1}}
{"title": "T", "body": "B"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "kind must be ONCE, WEEKLY or REMINDER"

POST {{base_url}}/classes/98601/notifications/scheduled
Authorization: {{auth_nf_teacher1}}
{"title": "T", "body": "B", "kind": "DAILY"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "kind must be ONCE, WEEKLY or REMINDER"
