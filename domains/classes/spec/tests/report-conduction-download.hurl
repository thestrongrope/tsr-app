# GET /reports/conduction/download?format=xlsx|pdf&gender&year&week&level contract: the conduction report as a file. Runs against any implementation (xlsx cells: tools/export-parity.sh, db/tests).
# Variables: base_url and auth_<alias>. B5A fixtures (see report-conduction.hurl): rp_coord reaches the gents classes 9581 and 9582; week 45 of 2025 is 9 to 15 Nov. The format is checked BEFORE the sign-in.

# 1. A bad format is 422 first
GET {{base_url}}/reports/conduction/download?year=2025&week=45
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be xlsx or pdf"

GET {{base_url}}/reports/conduction/download?format=docx&year=2025&week=45
Authorization: {{auth_outsider}}
HTTP 422

# 2. Then the sign-in (401), reports:read (403), and the year and week (422)
GET {{base_url}}/reports/conduction/download?format=xlsx&year=2025&week=45
HTTP 401

GET {{base_url}}/reports/conduction/download?format=pdf&year=2025&week=45
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/reports/conduction/download?format=xlsx&year=1999&week=45
Authorization: {{auth_rp_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid year or week"

GET {{base_url}}/reports/conduction/download?format=xlsx&year=2025&week=54
Authorization: {{auth_rp_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid year or week"

# 3. The coordinator's week: xlsx and pdf, the name carries the gender, week and year
GET {{base_url}}/reports/conduction/download?format=xlsx&year=2025&week=45
Authorization: {{auth_rp_coord}}
HTTP 200
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="Conduction-Gents-week-45-2025.xlsx"
[Asserts]
bytes startsWith hex,504b;

GET {{base_url}}/reports/conduction/download?format=pdf&year=2025&week=45
Authorization: {{auth_rp_coord}}
HTTP 200
Content-Type: application/pdf
Content-Disposition: attachment; filename="Conduction-Gents-week-45-2025.pdf"
[Asserts]
bytes startsWith hex,25504446;

# 4. A level that matches, a level that matches nothing (headers only, still a file), and the gender of a gender-locked coordinator
GET {{base_url}}/reports/conduction/download?format=xlsx&year=2025&week=45&level=MIQDAD
Authorization: {{auth_rp_coord}}
HTTP 200

GET {{base_url}}/reports/conduction/download?format=xlsx&year=2025&week=45&level=NOSUCH
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
bytes startsWith hex,504b;

GET {{base_url}}/reports/conduction/download?format=xlsx&year=2025&week=45&gender=2
Authorization: {{auth_rp_coord}}
HTTP 200
Content-Disposition: attachment; filename="Conduction-Gents-week-45-2025.xlsx"

GET {{base_url}}/reports/conduction/download?format=xlsx&year=2025&week=45&gender=2
Authorization: {{auth_admin}}
HTTP 200
Content-Disposition: attachment; filename="Conduction-Ladies-week-45-2025.xlsx"
