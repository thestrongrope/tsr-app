# GET /notifications/history, GET /notifications/stats and the refusals of POST /notifications/cleanup-invalid-tokens contract. Runs against any implementation.
# Variables: base_url and auth_nf_<alias>. Fixtures: db/synthetic/notify-fixtures.sql: notifications 9760001 to 9760004 sent 2099-12-31 (so they head the history), sent by 926111 ("Nf Sender"), inbox rows of 6 members on 9760001, 3 on 9760002.
# The cleanup success path pushes to every device, so it is not run here (notify-send-new-api.hurl holds the new API's, with no credential).

GET {{base_url}}/notifications/history
HTTP 401

GET {{base_url}}/notifications/stats
HTTP 401

POST {{base_url}}/notifications/cleanup-invalid-tokens
Content-Length: 0
HTTP 401

# Only the super administrator, each endpoint with its own wording
GET {{base_url}}/notifications/history
Authorization: {{auth_nf_member}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super administrators can view notification history"

GET {{base_url}}/notifications/stats
Authorization: {{auth_nf_gents}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super administrators can view notification statistics"

POST {{base_url}}/notifications/cleanup-invalid-tokens
Authorization: {{auth_nf_member}}
Content-Length: 0
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super administrators can cleanup invalid tokens"

POST {{base_url}}/notifications/cleanup-invalid-tokens
Authorization: {{auth_nf_gents}}
Content-Length: 0
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super administrators can cleanup invalid tokens"

# History: newest first, the target decoded, the audience in words, the recipients counted
GET {{base_url}}/notifications/history?limit=4
Authorization: {{auth_nf_super}}
HTTP 200
[Asserts]
jsonpath "$.limit" == 4
jsonpath "$.offset" == 0
jsonpath "$.count" == 4
jsonpath "$.notifications[0].notification_id" == 9760001
jsonpath "$.notifications[0].title" == "Nf History All"
jsonpath "$.notifications[0].body" == "Nf body one"
jsonpath "$.notifications[0].device_count" == 4
jsonpath "$.notifications[0].success_count" == 3
jsonpath "$.notifications[0].failure_count" == 1
jsonpath "$.notifications[0].sent_at" == "2099-12-31T23:00:04"
jsonpath "$.notifications[0].action_link" == null
jsonpath "$.notifications[0].sender_name" == "Nf Sender"
jsonpath "$.notifications[0].sender_email" == "nf.926111@example.invalid"
jsonpath "$.notifications[0].target_audience_criteria.type" == "ALL_USERS"
jsonpath "$.notifications[0].target_audience_criteria.value" == null
jsonpath "$.notifications[0].audience_summary" == "All users"
jsonpath "$.notifications[0].recipient_count" == 6
jsonpath "$.notifications[1].notification_id" == 9760002
jsonpath "$.notifications[1].action_link" == "/classes/12/syllabus"
jsonpath "$.notifications[1].target_audience_criteria.value[0]" == "male"
jsonpath "$.notifications[1].audience_summary" == "One gender"
jsonpath "$.notifications[1].recipient_count" == 3
jsonpath "$.notifications[2].notification_id" == 9760003
jsonpath "$.notifications[2].target_audience_criteria.type" == "CLASS_LEVEL"
jsonpath "$.notifications[2].recipient_count" == 1
jsonpath "$.notifications[3].notification_id" == 9760004
jsonpath "$.notifications[3].target_audience_criteria.type" == "TEACHERS"
jsonpath "$.notifications[3].recipient_count" == 0

GET {{base_url}}/notifications/history?limit=1&offset=1
Authorization: {{auth_nf_super}}
HTTP 200
[Asserts]
jsonpath "$.count" == 1
jsonpath "$.notifications[0].notification_id" == 9760002
jsonpath "$.offset" == 1

GET {{base_url}}/notifications/history?limit=abc
Authorization: {{auth_nf_super}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid limit"

GET {{base_url}}/notifications/history?offset=1.5
Authorization: {{auth_nf_super}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid offset"

# Stats: whole numbers (the database holds other rows too, so only the shape and lower bounds)
GET {{base_url}}/notifications/stats
Authorization: {{auth_nf_super}}
HTTP 200
[Asserts]
jsonpath "$.total_notifications" isInteger
jsonpath "$.total_notifications" >= 4
jsonpath "$.total_devices_targeted" isInteger
jsonpath "$.total_devices_targeted" >= 7
jsonpath "$.total_successful" isInteger
jsonpath "$.total_failed" isInteger
jsonpath "$.last_sent_at" == "2099-12-31T23:00:04"
