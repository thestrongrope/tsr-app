# GET /reports/pending/download?format=xlsx|pdf&gender&from&to&level contract: the pending work report as a file, a row per pending class under its teacher. Runs against any implementation (xlsx cells: tools/export-parity.sh, db/tests).
# Variables: base_url and auth_<alias>. B5C fixtures (see report-pending.hurl): rc_coord reaches the gents classes 9564 and 9565 and the ladies class 9567; October 2025. The format is checked BEFORE the sign-in.

# 1. A bad format is 422 first
GET {{base_url}}/reports/pending/download?from=10-2025&to=10-2025
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be xlsx or pdf"

GET {{base_url}}/reports/pending/download?format=zip&from=10-2025&to=10-2025
Authorization: {{auth_outsider}}
HTTP 422

# 2. Then the sign-in (401), reports:read (403) and the months (422)
GET {{base_url}}/reports/pending/download?format=xlsx&from=10-2025&to=10-2025
HTTP 401

GET {{base_url}}/reports/pending/download?format=pdf&from=10-2025&to=10-2025
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/reports/pending/download?format=xlsx&from=10-2025&to=09-2025
Authorization: {{auth_rc_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be months as MM-YYYY, from not after to"

GET {{base_url}}/reports/pending/download?format=xlsx&from=01-2024&to=12-2025
Authorization: {{auth_rc_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The range can cover at most 12 months"

# 3. xlsx and pdf: the name always carries both months
GET {{base_url}}/reports/pending/download?format=xlsx&from=10-2025&to=10-2025
Authorization: {{auth_rc_coord}}
HTTP 200
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="Pending-Gents-10-2025-to-10-2025.xlsx"
[Asserts]
bytes startsWith hex,504b;

GET {{base_url}}/reports/pending/download?format=pdf&from=09-2025&to=10-2025
Authorization: {{auth_rc_coord}}
HTTP 200
Content-Type: application/pdf
Content-Disposition: attachment; filename="Pending-Gents-09-2025-to-10-2025.pdf"
[Asserts]
bytes startsWith hex,25504446;

# 4. A level, a level that matches nothing (headers only), and the gender
GET {{base_url}}/reports/pending/download?format=xlsx&from=10-2025&to=10-2025&level=MIQDAD
Authorization: {{auth_rc_coord}}
HTTP 200

GET {{base_url}}/reports/pending/download?format=xlsx&from=10-2025&to=10-2025&level=NOSUCH
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
bytes startsWith hex,504b;

GET {{base_url}}/reports/pending/download?format=xlsx&from=10-2025&to=10-2025&gender=2
Authorization: {{auth_rc_coord}}
HTTP 200
Content-Disposition: attachment; filename="Pending-Ladies-10-2025-to-10-2025.xlsx"
