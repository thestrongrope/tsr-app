# GET /reports/tsr/download?format=xlsx|pdf&gender&from&to contract: TSR at a glance as a file, eight tables. Runs against any implementation (xlsx cells: tools/export-parity.sh, db/tests).
# Variables: base_url and auth_<alias>. B5C fixtures (see report-tsr.hurl): rc_coord reaches the gents classes 9564 and 9565 and the ladies class 9567; the range is fixed in October and November 2025. The format is checked BEFORE the sign-in.

# 1. A bad format is 422 first
GET {{base_url}}/reports/tsr/download?from=2025-10-01&to=2025-11-30
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be xlsx or pdf"

GET {{base_url}}/reports/tsr/download?format=txt&from=2025-10-01&to=2025-11-30
Authorization: {{auth_outsider}}
HTTP 422

# 2. Then the sign-in (401), reports:read (403) and the dates (422)
GET {{base_url}}/reports/tsr/download?format=xlsx&from=2025-10-01&to=2025-11-30
HTTP 401

GET {{base_url}}/reports/tsr/download?format=pdf&from=2025-10-01&to=2025-11-30
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/reports/tsr/download?format=xlsx&from=2025-11-30&to=2025-10-01
Authorization: {{auth_rc_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be dates as YYYY-MM-DD, from not after to"

GET {{base_url}}/reports/tsr/download?format=xlsx&from=2023-01-01&to=2025-10-01
Authorization: {{auth_rc_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The range can cover at most a year"

# 3. xlsx and pdf: the name carries the gender and the dates
GET {{base_url}}/reports/tsr/download?format=xlsx&from=2025-10-01&to=2025-11-30
Authorization: {{auth_rc_coord}}
HTTP 200
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="TSR-Gents-2025-10-01-to-2025-11-30.xlsx"
[Asserts]
bytes startsWith hex,504b;

GET {{base_url}}/reports/tsr/download?format=pdf&from=2025-10-01&to=2025-11-30
Authorization: {{auth_rc_coord}}
HTTP 200
Content-Type: application/pdf
Content-Disposition: attachment; filename="TSR-Gents-2025-10-01-to-2025-11-30.pdf"
[Asserts]
bytes startsWith hex,25504446;

# 4. The gender asked for decides for a coordinator with classes of both genders; a range with no session at all is still a file
GET {{base_url}}/reports/tsr/download?format=xlsx&from=2025-10-01&to=2025-11-30&gender=2
Authorization: {{auth_rc_coord}}
HTTP 200
Content-Disposition: attachment; filename="TSR-Ladies-2025-10-01-to-2025-11-30.xlsx"

GET {{base_url}}/reports/tsr/download?format=xlsx&from=2024-01-01&to=2024-01-05
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
bytes startsWith hex,504b;
