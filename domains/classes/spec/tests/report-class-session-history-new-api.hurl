# The class-sessions reports on the new API only. Variables: base_url and auth_<alias>. B5A fixtures.

# 1. A class number beyond the range of a number is no class (200, no sessions), not an error
GET {{base_url}}/reports/class-sessions/99999999999999999999
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.sessions" count == 0
