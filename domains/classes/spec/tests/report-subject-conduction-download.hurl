# GET /reports/subject-conduction/download?format=xlsx|pdf&gender&from&to&level&classId contract: the subject conduction report as a file, a row per class and week. Runs against any implementation (xlsx cells: tools/export-parity.sh, db/tests).
# Variables: base_url and auth_<alias>. B5A fixtures (see report-subject-conduction.hurl): rp_coord reaches 9581 and 9582; month 11-2025; 9584 is another city, 9585 closed. The format is checked BEFORE the sign-in.

# 1. A bad format is 422 first
GET {{base_url}}/reports/subject-conduction/download?from=11-2025
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be xlsx or pdf"

GET {{base_url}}/reports/subject-conduction/download?format=odt&from=11-2025
Authorization: {{auth_outsider}}
HTTP 422

# 2. Then the sign-in (401), reports:read (403), the months (422) and a class the caller does not reach (403)
GET {{base_url}}/reports/subject-conduction/download?format=xlsx&from=11-2025
HTTP 401

GET {{base_url}}/reports/subject-conduction/download?format=pdf&from=11-2025
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/reports/subject-conduction/download?format=xlsx&from=2025-11
Authorization: {{auth_rp_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be months as MM-YYYY, from not after to"

GET {{base_url}}/reports/subject-conduction/download?format=xlsx&from=11-2025&classId=9584
Authorization: {{auth_rp_coord}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/reports/subject-conduction/download?format=xlsx&from=11-2025&classId=9585
Authorization: {{auth_admin}}
HTTP 403

# 3. xlsx and pdf: the name carries the gender and the months
GET {{base_url}}/reports/subject-conduction/download?format=xlsx&from=11-2025&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 200
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="Subject-conduction-Gents-11-2025.xlsx"
[Asserts]
bytes startsWith hex,504b;

GET {{base_url}}/reports/subject-conduction/download?format=pdf&from=10-2025&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 200
Content-Type: application/pdf
Content-Disposition: attachment; filename="Subject-conduction-Gents-10-2025-to-11-2025.pdf"
[Asserts]
bytes startsWith hex,25504446;

# 4. One class, a level, a level that matches nothing (headers only) and the gender
GET {{base_url}}/reports/subject-conduction/download?format=xlsx&from=11-2025&classId=9581
Authorization: {{auth_rp_coord}}
HTTP 200

GET {{base_url}}/reports/subject-conduction/download?format=xlsx&from=11-2025&level=ABUZAR
Authorization: {{auth_rp_coord}}
HTTP 200

GET {{base_url}}/reports/subject-conduction/download?format=xlsx&from=11-2025&level=NOSUCH
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
bytes startsWith hex,504b;

GET {{base_url}}/reports/subject-conduction/download?format=xlsx&from=11-2025&gender=2
Authorization: {{auth_admin}}
HTTP 200
Content-Disposition: attachment; filename="Subject-conduction-Ladies-11-2025.xlsx"
