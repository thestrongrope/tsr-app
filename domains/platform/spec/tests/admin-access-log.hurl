# GET /admin/access-log contract: {users, pages, recent} of the admin access log. audit-log:read only; filters `token` (digits) and `page` (part of a page name); users and pages cover the last 30 days, recent does not (latest 500).
# The rows are seeded by db/synthetic/edge-fixtures.sql and tools/parity-php/edge-fixtures.sql for the subject token 927100 (and 927101, a row whose member does not exist), relative to the load time. Every assertion is made under a token filter,
# because other lanes' admin calls add rows to the shared parity log. Runs against any implementation. Variables: base_url, auth_edge_log (super admin), auth_edge_gents (gents admin: no audit-log:read), auth_edge_plain.
# Finding 4 (docs/specs/initial-build/build-out-findings.md): the list carries name, email and ip of every row for every audit-log:read holder; PHP does too.

# 1. Without sign-in: 401
GET {{base_url}}/admin/access-log
HTTP 401

# 2. Without audit-log:read: 403
GET {{base_url}}/admin/access-log
Authorization: {{auth_edge_gents}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/admin/access-log
Authorization: {{auth_edge_plain}}
HTTP 403

# 3. The filters are checked after the permission: 422 for a token that is not all digits
GET {{base_url}}/admin/access-log?token=abc
Authorization: {{auth_edge_log}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "token must be a member number"

GET {{base_url}}/admin/access-log?token=1.5
Authorization: {{auth_edge_log}}
HTTP 422

GET {{base_url}}/admin/access-log?token=-5
Authorization: {{auth_edge_log}}
HTTP 422

GET {{base_url}}/admin/access-log?token=abc
Authorization: {{auth_edge_gents}}
HTTP 403

# 4. One subject: users and pages hold the window (4 rows), recent holds all 5 (the 40 day old one too), newest id first
GET {{base_url}}/admin/access-log?token=927100
Authorization: {{auth_edge_log}}
HTTP 200
[Asserts]
header "Content-Type" startsWith "application/json"
jsonpath "$.users" count == 1
jsonpath "$.users[0].token" == 927100
jsonpath "$.users[0].name" == "Edge Member 927100"
jsonpath "$.users[0].email" == "edge.927100@example.invalid"
jsonpath "$.users[0].hits" == 4
jsonpath "$.users[0].activeDays" == 4
jsonpath "$.users[0].lastAccessed" matches /^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/
jsonpath "$.users[0].*" count == 6
jsonpath "$.pages" count == 3
jsonpath "$.pages[0].page" == "/edge/alpha"
jsonpath "$.pages[0].hits" == 2
jsonpath "$.pages[1].hits" == 1
jsonpath "$.pages[2].hits" == 1
jsonpath "$.pages[0].*" count == 3
jsonpath "$.pages[*].page" not contains "/edge/old"
jsonpath "$.recent" count == 5
jsonpath "$.recent[0].page" == "/edge/old"
jsonpath "$.recent[0].role" == "Member"
jsonpath "$.recent[0].ip" == "192.0.2.4"
jsonpath "$.recent[1].page" == "/edge/gamma"
jsonpath "$.recent[1].role" == ""
jsonpath "$.recent[1].ip" == ""
jsonpath "$.recent[2].page" == "/edge/=beta"
jsonpath "$.recent[2].role" == "Role 9"
jsonpath "$.recent[3].method" == "POST"
jsonpath "$.recent[3].role" == "Gents admin"
jsonpath "$.recent[4].role" == "Admin"
jsonpath "$.recent[4].name" == "Edge Member 927100"
jsonpath "$.recent[4].email" == "edge.927100@example.invalid"
jsonpath "$.recent[4].accessedAt" matches /^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/
jsonpath "$.recent[4].id" isInteger
jsonpath "$.recent[4].*" count == 9

# 5. A row whose member row does not exist: empty name and email, the token and role still shown
GET {{base_url}}/admin/access-log?token=927101
Authorization: {{auth_edge_log}}
HTTP 200
[Asserts]
jsonpath "$.users[0].name" == ""
jsonpath "$.users[0].email" == ""
jsonpath "$.users[0].hits" == 1
jsonpath "$.recent[0].token" == 927101
jsonpath "$.recent[0].role" == "Admin"

# 6. The page filter is part of a name, applied to all three lists
GET {{base_url}}/admin/access-log?token=927100&page=alpha
Authorization: {{auth_edge_log}}
HTTP 200
[Asserts]
jsonpath "$.users[0].hits" == 2
jsonpath "$.users[0].activeDays" == 2
jsonpath "$.pages" count == 1
jsonpath "$.recent" count == 2

GET {{base_url}}/admin/access-log?token=927100&page=old
Authorization: {{auth_edge_log}}
HTTP 200
[Asserts]
jsonpath "$.users" count == 0
jsonpath "$.pages" count == 0
jsonpath "$.recent" count == 1

# 7. A token nobody has: three empty lists. A token past the 64-bit range matches nothing too
GET {{base_url}}/admin/access-log?token=927999
Authorization: {{auth_edge_log}}
HTTP 200
[Asserts]
jsonpath "$.users" count == 0
jsonpath "$.pages" count == 0
jsonpath "$.recent" count == 0

# 8. Spaces around the filters are trimmed
GET {{base_url}}/admin/access-log?token=%20927100%20&page=%20gamma%20
Authorization: {{auth_edge_log}}
HTTP 200
[Asserts]
jsonpath "$.recent" count == 1
jsonpath "$.recent[0].page" == "/edge/gamma"

# 9. Without a filter the answer has the three sections (the content belongs to every lane's admin calls)
GET {{base_url}}/admin/access-log
Authorization: {{auth_edge_log}}
HTTP 200
[Asserts]
jsonpath "$.users" isCollection
jsonpath "$.pages" isCollection
jsonpath "$.recent" isCollection
jsonpath "$.recent" count <= 500
