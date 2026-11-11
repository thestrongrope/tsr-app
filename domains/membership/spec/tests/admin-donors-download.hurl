# GET /admin/donors/download?format=xlsx|pdf contract: the donors list as a file. Runs against any implementation (the xlsx cells of the fixture donors: tools/export-parity.sh, db/tests).
# Variables: base_url and auth_<alias>. B4B fixtures (see admin-donors.hurl): b4b_donor_admin holds donors:read, b4b_plain does not. The format is checked BEFORE the sign-in. The file name carries the UTC time.
# The 404 "There are no donors to download" needs an empty list: both databases hold donors, so db/tests proves it. The PDF is in admin-donors-download-new-api.hurl (PHP's Dompdf runs out of memory on the parity database's donors).

# 1. A bad format is 422 first
GET {{base_url}}/admin/donors/download
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be xlsx or pdf"

GET {{base_url}}/admin/donors/download?format=csv
Authorization: {{auth_b4b_plain}}
HTTP 422

# 2. Then the sign-in (401) and donors:read (403)
GET {{base_url}}/admin/donors/download?format=xlsx
HTTP 401

GET {{base_url}}/admin/donors/download?format=xlsx
Authorization: {{auth_b4b_plain}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. The donors administrator: an xlsx named with the time
GET {{base_url}}/admin/donors/download?format=xlsx
Authorization: {{auth_b4b_donor_admin}}
HTTP 200
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
[Asserts]
header "Content-Disposition" matches /^attachment; filename="TSR_Donors_Export_[0-9]{8}_[0-9]{6}\.xlsx"$/
bytes startsWith hex,504b;
