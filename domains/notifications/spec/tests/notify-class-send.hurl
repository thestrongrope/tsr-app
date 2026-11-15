# POST /classes/{id}/notifications contract: a push to a class's active students. Runs against any implementation.
# Variables: base_url and auth_nf_<alias>. Fixtures: db/synthetic/notify-fixtures.sql. Class 98601 (teacher 926031) has an active student with a device; class 98602 (teacher 926032) has one active student and no device; 98603 is closed (teacher 926033);
# 926034 teaches 98604 only. NOTHING IS PUSHED FROM THIS FILE: the only send that passes every check is the one to class 98602, which finds no device. (Rate limit: 10 sends an hour per member on either side; this file makes one for 926032.
# The send that reaches a device is in notify-class-send-new-api.hurl.)

POST {{base_url}}/classes/98601/notifications
{"title": "T", "body": "B"}
HTTP 401

# 404 before 403: no such class, a closed class (PHP's api_find_class: active only), a path that is not a number
POST {{base_url}}/classes/99999999/notifications
Authorization: {{auth_nf_teacher1}}
{"title": "T", "body": "B"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

POST {{base_url}}/classes/98603/notifications
Authorization: {{auth_nf_teacher3}}
{"title": "T", "body": "B"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

POST {{base_url}}/classes/abc/notifications
Authorization: {{auth_nf_teacher1}}
{"title": "T", "body": "B"}
HTTP 404

# 403: a plain member, the teacher of another class, a gender administrator who is not the class's teacher and has no class scope
POST {{base_url}}/classes/98601/notifications
Authorization: {{auth_nf_member}}
{"title": "T", "body": "B"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to send notifications for this class"

POST {{base_url}}/classes/98601/notifications
Authorization: {{auth_nf_teacher4}}
{"title": "T", "body": "B"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to send notifications for this class"

# 422s (title and body are trimmed, then counted; the link at most 500 characters and https or in-app)
POST {{base_url}}/classes/98601/notifications
Authorization: {{auth_nf_teacher1}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "title is required and must be at most 255 characters"

POST {{base_url}}/classes/98601/notifications
Authorization: {{auth_nf_teacher1}}
{"title": "   ", "body": "B"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "title is required and must be at most 255 characters"

POST {{base_url}}/classes/98601/notifications
Authorization: {{auth_nf_teacher1}}
{"title": "T", "body": "   "}
HTTP 422
[Asserts]
jsonpath "$.detail" == "body is required and must be at most 2000 characters"

POST {{base_url}}/classes/98601/notifications
Authorization: {{auth_nf_teacher1}}
{"title": "T", "body": "B", "action_link": "javascript:alert(1)"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "action_link must be an https:// link or an in-app path such as /classes/12/syllabus"

POST {{base_url}}/classes/98601/notifications
Authorization: {{auth_nf_teacher1}}
{"title": "T", "body": "B", "action_link": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "action_link must be at most 500 characters"

# The class teacher of a class with students and no device: 200, the student counted, nothing sent or written
POST {{base_url}}/classes/98602/notifications
Authorization: {{auth_nf_teacher2}}
{"title": " T ", "body": "B"}
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.message" == "No active student devices found for this class"
jsonpath "$.device_count" == 0
jsonpath "$.student_count" == 1
jsonpath "$.success_count" == 0
jsonpath "$.failure_count" == 0
jsonpath "$.notification_id" == null
