# GET /reports/registrations/download?format=xlsx|pdf&gender contract: the people waiting to be placed in a class, as a file. Runs against any implementation (the xlsx cells of the fixture members: tools/export-parity.sh, db/tests).
# Variables: base_url and auth_<alias>. B5B membership fixtures (see report-registrations.hurl). Guard: registrations:read for the gender (not reports:read); the format is checked BEFORE the sign-in. The file name carries today's date (UTC).

# 1. A bad format is 422 first
GET {{base_url}}/reports/registrations/download
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be xlsx or pdf"

GET {{base_url}}/reports/registrations/download?format=csv
Authorization: {{auth_b5b_plain}}
HTTP 422

# 2. Then the sign-in (401) and registrations:read (403)
GET {{base_url}}/reports/registrations/download?format=xlsx
HTTP 401

GET {{base_url}}/reports/registrations/download?format=pdf
Authorization: {{auth_b5b_plain}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. The administrator: xlsx (the PDF is in report-registrations-download-new-api.hurl: PHP's Dompdf runs out of memory on the parity database's waiting list), the name carries the gender and the day
GET {{base_url}}/reports/registrations/download?format=xlsx
Authorization: {{auth_b5b_admin}}
HTTP 200
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
[Asserts]
header "Content-Disposition" matches /^attachment; filename="Registrations-Gents-[0-9]{8}\.xlsx"$/
bytes startsWith hex,504b;

# 4. The gender: asked for by the administrator, locked for a gender administrator
GET {{base_url}}/reports/registrations/download?format=xlsx&gender=2
Authorization: {{auth_b5b_admin}}
HTTP 200
[Asserts]
header "Content-Disposition" matches /^attachment; filename="Registrations-Ladies-[0-9]{8}\.xlsx"$/

GET {{base_url}}/reports/registrations/download?format=xlsx&gender=2
Authorization: {{auth_b5b_gents_admin}}
HTTP 200
[Asserts]
header "Content-Disposition" matches /^attachment; filename="Registrations-Gents-[0-9]{8}\.xlsx"$/

GET {{base_url}}/reports/registrations/download?format=xlsx&gender=1
Authorization: {{auth_b5b_ladies_admin}}
HTTP 200
[Asserts]
header "Content-Disposition" matches /^attachment; filename="Registrations-Ladies-[0-9]{8}\.xlsx"$/
