# POST /user/notifications/{id}/read contract: the path id is the user_notifications row id. Runs against any implementation.
# Variables: base_url and auth_nf_<alias>. Fixtures: db/synthetic/notify-fixtures.sql. 926023 (read) owns rows 9760111 and 9760112; 926024 (read_victim) owns 9760113. Only this file changes these rows.

POST {{base_url}}/user/notifications/9760111/read
Content-Length: 0
HTTP 401

# Another member's row: a silent ok (not a 404, so ids cannot be probed), and nothing changes
POST {{base_url}}/user/notifications/9760113/read
Authorization: {{auth_nf_read}}
Content-Length: 0
HTTP 200
[Asserts]
jsonpath "$.ok" == true

GET {{base_url}}/user/notifications/unread-count
Authorization: {{auth_nf_read_victim}}
HTTP 200
[Asserts]
jsonpath "$.unread_count" == 1

# An id that exists nowhere, and ids PHP's (int) cast reads as 0 or a huge number: the same ok
POST {{base_url}}/user/notifications/99999999/read
Authorization: {{auth_nf_read}}
Content-Length: 0
HTTP 200
[Asserts]
jsonpath "$.ok" == true

POST {{base_url}}/user/notifications/abc/read
Authorization: {{auth_nf_read}}
Content-Length: 0
HTTP 200

POST {{base_url}}/user/notifications/99999999999999999999/read
Authorization: {{auth_nf_read}}
Content-Length: 0
HTTP 200

# Own row: marked read, once; the second call changes nothing and still answers ok
POST {{base_url}}/user/notifications/9760111/read
Authorization: {{auth_nf_read}}
Content-Length: 0
HTTP 200
[Asserts]
jsonpath "$.ok" == true

GET {{base_url}}/user/notifications
Authorization: {{auth_nf_read}}
HTTP 200
[Asserts]
jsonpath "$.unread_count" == 1
jsonpath "$.notifications[0].id" == 9760111
jsonpath "$.notifications[0].isRead" == true
jsonpath "$.notifications[0].readAt" isString
jsonpath "$.notifications[1].isRead" == false
jsonpath "$.notifications[1].readAt" == null

POST {{base_url}}/user/notifications/9760111/read
Authorization: {{auth_nf_read}}
Content-Length: 0
HTTP 200

GET {{base_url}}/user/notifications/unread-count
Authorization: {{auth_nf_read}}
HTTP 200
[Asserts]
jsonpath "$.unread_count" == 1
