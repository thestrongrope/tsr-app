# GET /reports/class-sessions/{class_id}/download?format=xlsx|pdf contract: one class's session history as a file (oldest first). Runs against any implementation (xlsx cells: tools/export-parity.sh, db/tests).
# Variables: base_url and auth_<alias>. B5A fixtures (see report-class-session-history.hurl): 9581 has 6 sessions; 9584 is another city, 9585 closed, 9583 ladies. A class that is missing or out of reach is a file with headers only, never a 404.
# PHP's order: the format is checked BEFORE the sign-in.

# 1. A bad format is 422 first, signed in or not
GET {{base_url}}/reports/class-sessions/9581/download
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be xlsx or pdf"

GET {{base_url}}/reports/class-sessions/9581/download?format=csv
Authorization: {{auth_outsider}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be xlsx or pdf"

# 2. A good format needs the sign-in (401), then reports:read (403)
GET {{base_url}}/reports/class-sessions/9581/download?format=xlsx
HTTP 401

GET {{base_url}}/reports/class-sessions/9581/download?format=pdf
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. The coordinator's class: xlsx and pdf, the name carries the id
GET {{base_url}}/reports/class-sessions/9581/download?format=xlsx
Authorization: {{auth_rp_coord}}
HTTP 200
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="Class-sessions-9581.xlsx"
[Asserts]
bytes startsWith hex,504b;

GET {{base_url}}/reports/class-sessions/9581/download?format=pdf
Authorization: {{auth_rp_coord}}
HTTP 200
Content-Type: application/pdf
Content-Disposition: attachment; filename="Class-sessions-9581.pdf"
[Asserts]
bytes startsWith hex,25504446;

# 4. A class outside the reach, closed, missing or not a number: still a file (headers only)
GET {{base_url}}/reports/class-sessions/9584/download?format=xlsx
Authorization: {{auth_rp_coord}}
HTTP 200
Content-Disposition: attachment; filename="Class-sessions-9584.xlsx"
[Asserts]
bytes startsWith hex,504b;

GET {{base_url}}/reports/class-sessions/999999/download?format=xlsx
Authorization: {{auth_admin}}
HTTP 200
Content-Disposition: attachment; filename="Class-sessions-999999.xlsx"

GET {{base_url}}/reports/class-sessions/abc/download?format=pdf
Authorization: {{auth_admin}}
HTTP 200
Content-Disposition: attachment; filename="Class-sessions-abc.pdf"
[Asserts]
bytes startsWith hex,25504446;
