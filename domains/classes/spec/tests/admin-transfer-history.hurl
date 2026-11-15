# GET /admin/transfers/history contract: the transfer log, newest first, searchable and paged. Runs against any implementation.
# Variables: base_url and auth_<alias>. B4a fixtures: three transfers by 900910 ("B4 Admin Deact"): 951101 (900931, 9511 to 9513, transfer, "B4 reason a", 2025-10-01), 951102 (900932, 9511 to 9513, promotion,
# no reason, 2025-10-02), 951103 (900931, 9513 to 9511, demotion, "B4 100%_x", 2025-10-03); the admin 900902 (role 1).

# 1. Without sign-in: 401
GET {{base_url}}/admin/transfers/history
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Only students:transfer
GET {{base_url}}/admin/transfers/history
Authorization: {{auth_en_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only administrators can transfer students"

# 3. The operator's name finds the three, newest first, with every field
GET {{base_url}}/admin/transfers/history?q=B4%20Admin%20Deact
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.total" == 3
jsonpath "$.page" == 1
jsonpath "$.pageSize" == 50
jsonpath "$.items" count == 3
jsonpath "$.items[0].id" == 951103
jsonpath "$.items[0].studentToken" == 900931
jsonpath "$.items[0].studentName" == "B4 Member 900931"
jsonpath "$.items[0].type" == "demotion"
jsonpath "$.items[0].fromCode" == "B4-G-13"
jsonpath "$.items[0].toCode" == "B4-G-11"
jsonpath "$.items[0].reason" == "B4 100%_x"
jsonpath "$.items[0].transferredBy" == "B4 Admin Deact"
jsonpath "$.items[0].transferredAt" == "2025-10-03T10:00:00"
jsonpath "$.items[1].id" == 951102
jsonpath "$.items[1].reason" == null
jsonpath "$.items[2].id" == 951101

# 4. Paging: page size and page, clamped (a page below 1 is 1, a size below 1 is 1, a size above 100 is 100)
GET {{base_url}}/admin/transfers/history?q=B4%20Admin%20Deact&pageSize=2&page=2
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.total" == 3
jsonpath "$.page" == 2
jsonpath "$.pageSize" == 2
jsonpath "$.items" count == 1
jsonpath "$.items[0].id" == 951101

GET {{base_url}}/admin/transfers/history?q=B4%20Admin%20Deact&pageSize=0&page=0
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.page" == 1
jsonpath "$.pageSize" == 1
jsonpath "$.items" count == 1

GET {{base_url}}/admin/transfers/history?pageSize=500
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.pageSize" == 100

# 5. Search: a token (exact), a student's name, a class code in either direction (any case), a reason with the wildcards live
GET {{base_url}}/admin/transfers/history?q=900932
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.total" == 1
jsonpath "$.items[0].id" == 951102

GET {{base_url}}/admin/transfers/history?q=B4%20Member%20900931
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.total" == 2

GET {{base_url}}/admin/transfers/history?q=b4-g-13
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.total" == 3

GET {{base_url}}/admin/transfers/history?q=B4%201_0%25
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.total" == 1
jsonpath "$.items[0].id" == 951103

GET {{base_url}}/admin/transfers/history?q=B4%20reason%20a
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.total" == 1
jsonpath "$.items[0].id" == 951101

# 6. Nothing found, and a blank search (the whole log)
GET {{base_url}}/admin/transfers/history?q=nobody-b4-matches
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.total" == 0
jsonpath "$.items" count == 0

GET {{base_url}}/admin/transfers/history?q=%20%20
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.total" >= 3
