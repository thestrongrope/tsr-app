# GET /reports/registrations/allocated/download?format=xlsx|pdf&gender contract: everyone who registered and is placed in an active class, 25 columns. Runs against any implementation (the xlsx cells of the fixture members: tools/export-parity.sh, db/tests).
# Variables: base_url and auth_<alias>. B5D membership fixtures (db/synthetic/membership-b5d-fixtures.sql): b5d_coord is a coordinator assigned the class 9561 only (it gets only the registrations that name a class, of people placed in 9561); the administrators get every placed
# person of their gender, open registrations too. Guard: registrations:read for the gender; the format is checked BEFORE the sign-in. The file name carries today's date (UTC). The PDF is in the -new-api file (PHP's Dompdf runs out of memory on the parity database).

# 1. A bad format is 422 first
GET {{base_url}}/reports/registrations/allocated/download
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be xlsx or pdf"

GET {{base_url}}/reports/registrations/allocated/download?format=csv
Authorization: {{auth_b5b_plain}}
HTTP 422

# 2. Then the sign-in (401) and registrations:read (403)
GET {{base_url}}/reports/registrations/allocated/download?format=xlsx
HTTP 401

GET {{base_url}}/reports/registrations/allocated/download?format=xlsx
Authorization: {{auth_b5b_plain}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. The administrator and the coordinator: xlsx, the name carries the gender and the day
GET {{base_url}}/reports/registrations/allocated/download?format=xlsx
Authorization: {{auth_b5b_admin}}
HTTP 200
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
[Asserts]
header "Content-Disposition" matches /^attachment; filename="Registrations-placed-Gents-[0-9]{8}\.xlsx"$/
bytes startsWith hex,504b;

GET {{base_url}}/reports/registrations/allocated/download?format=xlsx
Authorization: {{auth_b5d_coord}}
HTTP 200
[Asserts]
header "Content-Disposition" matches /^attachment; filename="Registrations-placed-Gents-[0-9]{8}\.xlsx"$/
bytes startsWith hex,504b;

# 4. The gender: asked for by the administrator, locked for the gender administrators
GET {{base_url}}/reports/registrations/allocated/download?format=xlsx&gender=2
Authorization: {{auth_b5b_admin}}
HTTP 200
[Asserts]
header "Content-Disposition" matches /^attachment; filename="Registrations-placed-Ladies-[0-9]{8}\.xlsx"$/

GET {{base_url}}/reports/registrations/allocated/download?format=xlsx&gender=2
Authorization: {{auth_b5b_gents_admin}}
HTTP 200
[Asserts]
header "Content-Disposition" matches /^attachment; filename="Registrations-placed-Gents-[0-9]{8}\.xlsx"$/

GET {{base_url}}/reports/registrations/allocated/download?format=xlsx&gender=1
Authorization: {{auth_b5b_ladies_admin}}
HTTP 200
[Asserts]
header "Content-Disposition" matches /^attachment; filename="Registrations-placed-Ladies-[0-9]{8}\.xlsx"$/
