# GET /reports/students, cases only the new API answers well (PHP is not run on this file): a NUL byte in any text is never a 500 (PostgreSQL text cannot hold NUL; none of these reach SQL: the days are checked
# first and the gender is read as a number), and a default `from` that would fall before year 1 is 422 (PHP builds "0000-..." and refuses it the same way; an underflow must not crash).
GET {{base_url}}/reports/students?from=%00&to=2025-11-05
Authorization: {{auth_rc_coord}}
HTTP 422

GET {{base_url}}/reports/students?from=2025-10-01&to=%00
Authorization: {{auth_rc_coord}}
HTTP 422

GET {{base_url}}/reports/students?from=2025-10-01&to=2025-11-05&gender=%00
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1

GET {{base_url}}/reports/students?to=0001-01-20
Authorization: {{auth_rc_coord}}
HTTP 422
