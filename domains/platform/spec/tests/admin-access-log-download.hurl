# GET /admin/access-log/download?format=xlsx|pdf contract: the window's accesses as a file. A bad or missing format is 422 BEFORE the sign-in; then 401, audit-log:read (403), the token filter (422), 404 "No accesses match".
# The cells are compared with PHP's by tools/export-parity.sh (cases "edge_download" of tools/export-parity.cases) and read back in db/tests/TestEdgeAccessLogTests.cs.
# Fixture rows: db/synthetic/edge-fixtures.sql. Runs against any implementation. Variables: base_url, auth_edge_download (super admin), auth_edge_gents, auth_edge_plain.

# 1. The format is checked first, even without sign-in
GET {{base_url}}/admin/access-log/download
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be xlsx or pdf"

GET {{base_url}}/admin/access-log/download?format=csv
HTTP 422

GET {{base_url}}/admin/access-log/download?format=XLSX
HTTP 422

# 2. A good format without sign-in: 401
GET {{base_url}}/admin/access-log/download?format=xlsx
HTTP 401

# 3. Without audit-log:read: 403
GET {{base_url}}/admin/access-log/download?format=xlsx
Authorization: {{auth_edge_gents}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/admin/access-log/download?format=xlsx&token=927100
Authorization: {{auth_edge_plain}}
HTTP 403

# 4. A bad token: 422 after the permission
GET {{base_url}}/admin/access-log/download?format=xlsx&token=abc
Authorization: {{auth_edge_download}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "token must be a member number"

GET {{base_url}}/admin/access-log/download?format=xlsx&token=abc
Authorization: {{auth_edge_gents}}
HTTP 403

# 5. Nothing in the window matches: 404
GET {{base_url}}/admin/access-log/download?format=xlsx&token=999999999
Authorization: {{auth_edge_download}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "No accesses match"

GET {{base_url}}/admin/access-log/download?format=xlsx&token=927100&page=old
Authorization: {{auth_edge_download}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "No accesses match"

# 6. A workbook: the type, the attachment name, a non-empty body
GET {{base_url}}/admin/access-log/download?format=xlsx&token=927100
Authorization: {{auth_edge_download}}
HTTP 200
[Asserts]
header "Content-Type" == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
header "Content-Disposition" matches /^attachment; filename="TSR_Admin_Access_Log_[0-9]{8}_[0-9]{6}\.xlsx"$/
bytes count > 1000

GET {{base_url}}/admin/access-log/download?format=xlsx&token=927101
Authorization: {{auth_edge_download}}
HTTP 200

# 7. A PDF: the type and the attachment name (PHP renders the four rows with Dompdf, the new API with Gotenberg)
GET {{base_url}}/admin/access-log/download?format=pdf&token=927100
Authorization: {{auth_edge_download}}
HTTP 200
[Asserts]
header "Content-Type" == "application/pdf"
header "Content-Disposition" matches /^attachment; filename="TSR_Admin_Access_Log_[0-9]{8}_[0-9]{6}\.pdf"$/
bytes startsWith hex,255044462d;

GET {{base_url}}/admin/access-log/download?format=pdf&token=999999999
Authorization: {{auth_edge_download}}
HTTP 404

GET {{base_url}}/admin/access-log/download?format=pdf
Authorization: {{auth_edge_gents}}
HTTP 403
