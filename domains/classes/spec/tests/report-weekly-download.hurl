# GET /reports/weekly/download?format=xlsx|pdf&gender&from&to&level contract: the weekly report as one table in a file. Runs against any implementation (xlsx cells: tools/export-parity.sh, db/tests).
# Variables: base_url and auth_<alias>. B5A fixtures (see report-weekly.hurl): rp_coord reaches 9581 and 9582; month 11-2025. The format is checked BEFORE the sign-in.

# 1. A bad format is 422 first
GET {{base_url}}/reports/weekly/download?from=11-2025
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be xlsx or pdf"

GET {{base_url}}/reports/weekly/download?format=xls&from=11-2025
Authorization: {{auth_outsider}}
HTTP 422

# 2. Then the sign-in (401), reports:read (403) and the months (422)
GET {{base_url}}/reports/weekly/download?format=xlsx&from=11-2025
HTTP 401

GET {{base_url}}/reports/weekly/download?format=pdf&from=11-2025
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/reports/weekly/download?format=xlsx&from=13-2025
Authorization: {{auth_rp_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be months as MM-YYYY, from not after to"

GET {{base_url}}/reports/weekly/download?format=xlsx&from=01-2025&to=02-2026
Authorization: {{auth_rp_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The range can cover at most 12 months"

# 3. One month and two months: xlsx and pdf, the name carries the gender and the months
GET {{base_url}}/reports/weekly/download?format=xlsx&from=11-2025&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 200
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="Weekly-Gents-11-2025.xlsx"
[Asserts]
bytes startsWith hex,504b;

GET {{base_url}}/reports/weekly/download?format=pdf&from=10-2025&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 200
Content-Type: application/pdf
Content-Disposition: attachment; filename="Weekly-Gents-10-2025-to-11-2025.pdf"
[Asserts]
bytes startsWith hex,25504446;

# 4. A level, a level that matches nothing (headers only), and the gender
GET {{base_url}}/reports/weekly/download?format=xlsx&from=11-2025&level=MIQDAD
Authorization: {{auth_rp_coord}}
HTTP 200
Content-Disposition: attachment; filename="Weekly-Gents-11-2025.xlsx"

GET {{base_url}}/reports/weekly/download?format=xlsx&from=11-2025&level=NOSUCH
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
bytes startsWith hex,504b;

GET {{base_url}}/reports/weekly/download?format=xlsx&from=11-2025&gender=2
Authorization: {{auth_admin}}
HTTP 200
Content-Disposition: attachment; filename="Weekly-Ladies-11-2025.xlsx"
