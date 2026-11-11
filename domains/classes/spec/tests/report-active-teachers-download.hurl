# GET /reports/active-teachers/download?format=xlsx|pdf contract: the active teachers report as a file. Runs against any implementation (xlsx cells are compared by tools/export-parity.sh and db/tests).
# Variables: base_url and auth_<alias>. B5B fixtures (db/synthetic/classes-b5b-fixtures.sql), the same members as report-active-teachers.hurl.
# PHP's order: the format is checked BEFORE the sign-in, so an unsigned bad format is 422 and an unsigned good one 401.

# 1. A bad format is 422 first, signed in or not
GET {{base_url}}/reports/active-teachers/download
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be xlsx or pdf"

GET {{base_url}}/reports/active-teachers/download?format=csv
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be xlsx or pdf"

GET {{base_url}}/reports/active-teachers/download?format=XLSX
Authorization: {{auth_outsider}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be xlsx or pdf"

# 2. A good format needs the sign-in (401), then reports:read (403)
GET {{base_url}}/reports/active-teachers/download?format=xlsx
HTTP 401

GET {{base_url}}/reports/active-teachers/download?format=pdf
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. xlsx: a zip package, the spreadsheet type and an attachment name that no caller input reaches
GET {{base_url}}/reports/active-teachers/download?format=xlsx
Authorization: {{auth_rb_coord}}
HTTP 200
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="Active-teachers-Gents.xlsx"
[Asserts]
bytes startsWith hex,504b;

# 4. pdf: a PDF
GET {{base_url}}/reports/active-teachers/download?format=pdf
Authorization: {{auth_rb_coord}}
HTTP 200
Content-Type: application/pdf
Content-Disposition: attachment; filename="Active-teachers-Gents.pdf"
[Asserts]
bytes startsWith hex,25504446;

# 5. The gender follows the same rule as the screen: a gents-only coordinator is held to gents, a ladies administrator to ladies, the super administrator chooses
GET {{base_url}}/reports/active-teachers/download?format=xlsx&gender=2
Authorization: {{auth_rb_coord}}
HTTP 200
Content-Disposition: attachment; filename="Active-teachers-Gents.xlsx"

GET {{base_url}}/reports/active-teachers/download?format=xlsx&gender=1
Authorization: {{auth_en_ladmin}}
HTTP 200
Content-Disposition: attachment; filename="Active-teachers-Ladies.xlsx"

GET {{base_url}}/reports/active-teachers/download?format=pdf&gender=2
Authorization: {{auth_admin}}
HTTP 200
Content-Disposition: attachment; filename="Active-teachers-Ladies.pdf"
[Asserts]
bytes startsWith hex,25504446;

GET {{base_url}}/reports/active-teachers/download?format=xlsx&gender=7
Authorization: {{auth_admin}}
HTTP 200
Content-Disposition: attachment; filename="Active-teachers-Gents.xlsx"
