# (PHP trim() strips NUL, so a level of only NUL means no level.)
# GET /reports/pending, cases only the new API answers well (PHP is not run on this file): a NUL byte in any text is never a 500 (PostgreSQL text cannot hold NUL; none of these reach SQL).
GET {{base_url}}/reports/pending?from=10-2025&to=10-2025&level=%00
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.teachers" count == 1

GET {{base_url}}/reports/pending?from=%00&to=10-2025
Authorization: {{auth_rc_coord}}
HTTP 422

GET {{base_url}}/reports/pending?from=10-2025&to=10-2025&gender=%00
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
