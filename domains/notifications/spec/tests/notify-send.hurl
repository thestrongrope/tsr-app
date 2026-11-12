# POST /notifications/send contract: an announcement to an audience. Runs against any implementation.
# Variables: base_url and auth_nf_<alias>. Fixtures: db/synthetic/notify-fixtures.sql. 926101 (super) is a super administrator, 926102 (gents) a gender administrator, 926001 (member) a plain member.
# NOTHING IS EVER PUSHED FROM THIS FILE: every success case here finds no device (the audience is empty), which answers 200 before any push. The parity PHP and the test stack have no Google credential;
# the case where there ARE devices is in notify-send-new-api.hurl and in the database tests (a fake sender). Bodyless and invalid cases stop earlier still.

POST {{base_url}}/notifications/send
{"title": "T", "body": "B", "target": {"type": "ALL_USERS"}}
HTTP 401

# 403: only the super administrator, with this endpoint's own wording; a gender administrator is refused too
POST {{base_url}}/notifications/send
Authorization: {{auth_nf_member}}
{"title": "T", "body": "B", "target": {"type": "ALL_USERS"}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super administrators can send notifications"

POST {{base_url}}/notifications/send
Authorization: {{auth_nf_gents}}
{"title": "T", "body": "B", "target": {"type": "ALL_USERS"}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super administrators can send notifications"

# 422s in PHP's order: title, body, target, type, value, link
POST {{base_url}}/notifications/send
Authorization: {{auth_nf_super}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "title is required and must be at most 255 characters"

POST {{base_url}}/notifications/send
Authorization: {{auth_nf_super}}
{"title": "", "body": "B", "target": {"type": "ALL_USERS"}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "title is required and must be at most 255 characters"

POST {{base_url}}/notifications/send
Authorization: {{auth_nf_super}}
{"title": 5, "body": "B", "target": {"type": "ALL_USERS"}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "title is required and must be at most 255 characters"

POST {{base_url}}/notifications/send
Authorization: {{auth_nf_super}}
{"title": "T", "target": {"type": "ALL_USERS"}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "body is required and must be at most 2000 characters"

POST {{base_url}}/notifications/send
Authorization: {{auth_nf_super}}
{"title": "T", "body": "B"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "target is required"

POST {{base_url}}/notifications/send
Authorization: {{auth_nf_super}}
{"title": "T", "body": "B", "target": "ALL_USERS"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "target is required"

POST {{base_url}}/notifications/send
Authorization: {{auth_nf_super}}
{"title": "T", "body": "B", "target": {"type": "EVERYONE"}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "target.type must be one of ALL_USERS, CLASS_LEVEL, GENDER, TEACHERS"

POST {{base_url}}/notifications/send
Authorization: {{auth_nf_super}}
{"title": "T", "body": "B", "target": {"type": "GENDER", "value": "male"}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "target.value must be a list"

POST {{base_url}}/notifications/send
Authorization: {{auth_nf_super}}
{"title": "T", "body": "B", "target": {"type": "ALL_USERS"}, "action_link": "http://example.invalid/x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "action_link must be an https:// link or an in-app path such as /classes/12/syllabus"

POST {{base_url}}/notifications/send
Authorization: {{auth_nf_super}}
{"title": "T", "body": "B", "target": {"type": "ALL_USERS"}, "action_link": 7}
HTTP 422
[Asserts]
jsonpath "$.detail" == "action_link must be at most 500 characters"

# No devices match: 200, nothing sent, nothing written (a CLASS_LEVEL no class has; a GENDER that is not 1 or 2; a class whose teacher has no device; an empty list)
POST {{base_url}}/notifications/send
Authorization: {{auth_nf_super}}
{"title": "T", "body": "B", "target": {"type": "CLASS_LEVEL", "value": [99999999]}}
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.message" == "No devices found matching the target criteria"
jsonpath "$.device_count" == 0
jsonpath "$.success_count" == 0
jsonpath "$.failure_count" == 0
jsonpath "$.notification_id" == null

POST {{base_url}}/notifications/send
Authorization: {{auth_nf_super}}
{"title": "T", "body": "B", "target": {"type": "GENDER", "value": [3]}}
HTTP 200
[Asserts]
jsonpath "$.message" == "No devices found matching the target criteria"

POST {{base_url}}/notifications/send
Authorization: {{auth_nf_super}}
{"title": "T", "body": "B", "target": {"type": "CLASS_LEVEL", "value": []}}
HTTP 200
[Asserts]
jsonpath "$.device_count" == 0

POST {{base_url}}/notifications/send
Authorization: {{auth_nf_super}}
{"title": "T", "body": "B", "target": {"type": "CLASS_LEVEL", "value": ["abc", null, ""]}}
HTTP 200
[Asserts]
jsonpath "$.device_count" == 0

POST {{base_url}}/notifications/send
Authorization: {{auth_nf_super}}
{"title": "T", "body": "B", "target": {"type": "TEACHERS", "value": [98602]}, "action_link": "/classes/98602/syllabus"}
HTTP 200
[Asserts]
jsonpath "$.message" == "No devices found matching the target criteria"
jsonpath "$.notification_id" == null
