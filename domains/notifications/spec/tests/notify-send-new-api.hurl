# The push routes when there ARE devices, on a stack with no Google credential. NEW API ONLY: on the parity PHP the same request dies with a fatal error (HTTP 200 and an HTML body, no network call: it has no credential either),
# which is not a contract to copy. The new API answers 500 {"detail": "Push notifications are not configured"} BEFORE anything is sent or written (the credential-present paths are in the database tests, with a fake sender).
# Variables: base_url and auth_nf_<alias>. Fixtures: db/synthetic/notify-fixtures.sql: the active student 926041 of class 98601 has the device n6-stu-41 (level 3). Nothing is pushed: there is no credential.
# Rate limit: 10 class sends an hour per member; this file makes one for 926031.

POST {{base_url}}/notifications/send
Authorization: {{auth_nf_super}}
{"title": "T", "body": "B", "target": {"type": "CLASS_LEVEL", "value": [3]}}
HTTP 500
[Asserts]
jsonpath "$.detail" == "Push notifications are not configured"

POST {{base_url}}/notifications/cleanup-invalid-tokens
Authorization: {{auth_nf_super}}
Content-Length: 0
HTTP 500
[Asserts]
jsonpath "$.detail" == "Push notifications are not configured"

# Nothing was recorded by the refused sends: the history head is still the fixture rows
GET {{base_url}}/notifications/history?limit=1
Authorization: {{auth_nf_super}}
HTTP 200
[Asserts]
jsonpath "$.notifications[0].notification_id" == 9760001

POST {{base_url}}/classes/98601/notifications
Authorization: {{auth_nf_teacher1}}
{"title": "T", "body": "B"}
HTTP 500
[Asserts]
jsonpath "$.detail" == "Push notifications are not configured"
