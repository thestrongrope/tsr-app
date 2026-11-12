# GET /user/notifications and GET /user/notifications/unread-count contract: a member reads only their own inbox. Runs against any implementation.
# Variables: base_url and auth_nf_<alias>. Fixtures: db/synthetic/notify-fixtures.sql. 926021 (inbox) has three rows 9760101 (unread), 9760102 (read), 9760103 (unread), newest first; 926022 has one row (9760104) that 926021 must never see.

GET {{base_url}}/user/notifications
HTTP 401

GET {{base_url}}/user/notifications/unread-count
HTTP 401

# The list: camelCase item keys except notification_id, newest first, only the caller's rows, the totals are the caller's
GET {{base_url}}/user/notifications
Authorization: {{auth_nf_inbox}}
HTTP 200
[Asserts]
jsonpath "$.notifications" count == 3
jsonpath "$.notifications[0].id" == 9760101
jsonpath "$.notifications[0].notification_id" == 9760001
jsonpath "$.notifications[0].title" == "Nf History All"
jsonpath "$.notifications[0].body" == "Nf body one"
jsonpath "$.notifications[0].actionLink" == null
jsonpath "$.notifications[0].sentAt" == "2099-12-31T23:00:04"
jsonpath "$.notifications[0].isRead" == false
jsonpath "$.notifications[0].readAt" == null
jsonpath "$.notifications[0].classes" count == 0
jsonpath "$.notifications[1].id" == 9760102
jsonpath "$.notifications[1].actionLink" == "/classes/12/syllabus"
jsonpath "$.notifications[1].isRead" == true
jsonpath "$.notifications[1].readAt" == "2099-12-31T23:30:00"
jsonpath "$.notifications[2].id" == 9760103
jsonpath "$.total" == 3
jsonpath "$.unread_count" == 2
jsonpath "$.limit" == 20
jsonpath "$.offset" == 0

# Another member sees only their own row
GET {{base_url}}/user/notifications
Authorization: {{auth_nf_inbox_other}}
HTTP 200
[Asserts]
jsonpath "$.notifications" count == 1
jsonpath "$.notifications[0].id" == 9760104
jsonpath "$.total" == 1

# A member with no rows
GET {{base_url}}/user/notifications
Authorization: {{auth_nf_member}}
HTTP 200
[Asserts]
jsonpath "$.notifications" count == 0
jsonpath "$.total" == 0
jsonpath "$.unread_count" == 0

# Paging
GET {{base_url}}/user/notifications?limit=2&offset=1
Authorization: {{auth_nf_inbox}}
HTTP 200
[Asserts]
jsonpath "$.notifications" count == 2
jsonpath "$.notifications[0].id" == 9760102
jsonpath "$.limit" == 2
jsonpath "$.offset" == 1

GET {{base_url}}/user/notifications?limit=2&offset=5
Authorization: {{auth_nf_inbox}}
HTTP 200
[Asserts]
jsonpath "$.notifications" count == 0
jsonpath "$.total" == 3

# limit below 1 reads one row and echoes what was asked (PHP's model clamps, the echo does not)
GET {{base_url}}/user/notifications?limit=0
Authorization: {{auth_nf_inbox}}
HTTP 200
[Asserts]
jsonpath "$.notifications" count == 1
jsonpath "$.limit" == 0

GET {{base_url}}/user/notifications?limit=-1&offset=-5
Authorization: {{auth_nf_inbox}}
HTTP 200
[Asserts]
jsonpath "$.notifications" count == 1
jsonpath "$.limit" == -1
jsonpath "$.offset" == -5

# An empty value is the default
GET {{base_url}}/user/notifications?limit=&offset=
Authorization: {{auth_nf_inbox}}
HTTP 200
[Asserts]
jsonpath "$.limit" == 20
jsonpath "$.offset" == 0

# Not a whole number: 422
GET {{base_url}}/user/notifications?limit=abc
Authorization: {{auth_nf_inbox}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid limit"

GET {{base_url}}/user/notifications?offset=1.5
Authorization: {{auth_nf_inbox}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid offset"

# The count
GET {{base_url}}/user/notifications/unread-count
Authorization: {{auth_nf_inbox}}
HTTP 200
[Asserts]
jsonpath "$.unread_count" == 2

GET {{base_url}}/user/notifications/unread-count
Authorization: {{auth_nf_member}}
HTTP 200
[Asserts]
jsonpath "$.unread_count" == 0
