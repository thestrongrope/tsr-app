# POST /user/notifications/read-all contract: marks the caller's rows only. Runs against any implementation.
# Variables: base_url and auth_nf_<alias>. Fixtures: db/synthetic/notify-fixtures.sql. 926025 (readall) owns 9760121 and 9760122, both unread; 926026 (readall_other) owns 9760123. Only this file changes these rows.

POST {{base_url}}/user/notifications/read-all
Content-Length: 0
HTTP 401

GET {{base_url}}/user/notifications/unread-count
Authorization: {{auth_nf_readall}}
HTTP 200
[Asserts]
jsonpath "$.unread_count" == 2

POST {{base_url}}/user/notifications/read-all
Authorization: {{auth_nf_readall}}
Content-Length: 0
HTTP 200
[Asserts]
jsonpath "$.ok" == true

GET {{base_url}}/user/notifications/unread-count
Authorization: {{auth_nf_readall}}
HTTP 200
[Asserts]
jsonpath "$.unread_count" == 0

# The other member's row is untouched
GET {{base_url}}/user/notifications/unread-count
Authorization: {{auth_nf_readall_other}}
HTTP 200
[Asserts]
jsonpath "$.unread_count" == 1

# Again, and a member with nothing: ok
POST {{base_url}}/user/notifications/read-all
Authorization: {{auth_nf_readall}}
Content-Length: 0
HTTP 200

POST {{base_url}}/user/notifications/read-all
Authorization: {{auth_nf_member}}
Content-Length: 0
HTTP 200
[Asserts]
jsonpath "$.ok" == true
