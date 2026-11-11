# GET /reports/summary/download?format=xlsx|pdf&gender&from&to&level contract: the class summary as a file, a row per class. Runs against any implementation (xlsx cells: tools/export-parity.sh, db/tests).
# Variables: base_url and auth_<alias>. B5A fixtures (see report-summary.hurl): rp_coord reaches 9581 and 9582; months 11-2025. "from" is required (PHP's default is broken, so no "from" is 422). The format is checked BEFORE the sign-in.

# 1. A bad format is 422 first
GET {{base_url}}/reports/summary/download?from=11-2025&to=11-2025
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be xlsx or pdf"

GET {{base_url}}/reports/summary/download?format=csv&from=11-2025&to=11-2025
Authorization: {{auth_outsider}}
HTTP 422

# 2. Then the sign-in (401), reports:read (403) and the months (422)
GET {{base_url}}/reports/summary/download?format=xlsx&from=11-2025&to=11-2025
HTTP 401

GET {{base_url}}/reports/summary/download?format=pdf&from=11-2025&to=11-2025
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/reports/summary/download?format=xlsx&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be months as MM-YYYY, from not after to"

GET {{base_url}}/reports/summary/download?format=xlsx&from=12-2025&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 422

# 3. xlsx and pdf: the name carries the gender and the months
GET {{base_url}}/reports/summary/download?format=xlsx&from=11-2025&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 200
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="Summary-Gents-11-2025-to-11-2025.xlsx"
[Asserts]
bytes startsWith hex,504b;

GET {{base_url}}/reports/summary/download?format=pdf&from=10-2025&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 200
Content-Type: application/pdf
Content-Disposition: attachment; filename="Summary-Gents-10-2025-to-11-2025.pdf"
[Asserts]
bytes startsWith hex,25504446;

# 4. A level, a level that matches nothing (headers only), and the gender
GET {{base_url}}/reports/summary/download?format=xlsx&from=11-2025&to=11-2025&level=MIQDAD
Authorization: {{auth_rp_coord}}
HTTP 200

GET {{base_url}}/reports/summary/download?format=xlsx&from=11-2025&to=11-2025&level=NOSUCH
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
bytes startsWith hex,504b;

GET {{base_url}}/reports/summary/download?format=xlsx&from=11-2025&to=11-2025&gender=2
Authorization: {{auth_admin}}
HTTP 200
Content-Disposition: attachment; filename="Summary-Ladies-11-2025-to-11-2025.xlsx"
