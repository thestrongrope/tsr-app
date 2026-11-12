# GET /reports/mcq-summary/{class_id}/download?format=xlsx|pdf&gender&from&to contract: one class's students in the screen's columns, a column per topic after them. Runs against any implementation
# (the xlsx cells are compared with PHP by tools/export-parity.sh, cases in tools/export-parity.cases, the Topic A column of 98101 ignored: see report-mcq-summary-class.hurl).
# Variables: base_url and auth_r2_<alias>. REPORTS2 fixtures (see report-mcq-summary.hurl), March 2019. The format is checked BEFORE the sign-in (422 first).

# 1. A bad format is 422 first, then sign-in (401), permission (403), dates (422)
GET {{base_url}}/reports/mcq-summary/98101/download?from=2019-03-01&to=2019-03-31
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be xlsx or pdf"

GET {{base_url}}/reports/mcq-summary/98101/download?format=XLSX&from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 422

GET {{base_url}}/reports/mcq-summary/98101/download?format=csv&from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 422

GET {{base_url}}/reports/mcq-summary/98101/download?format=xlsx&from=2019-03-01&to=2019-03-31
HTTP 401

GET {{base_url}}/reports/mcq-summary/98101/download?format=pdf&from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_nobody}}
HTTP 403

GET {{base_url}}/reports/mcq-summary/98101/download?format=xlsx&from=2019-03-02&to=2019-03-01
Authorization: {{auth_r2_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be dates as YYYY-MM-DD, from not after to"

# 2. xlsx and pdf, file names
GET {{base_url}}/reports/mcq-summary/98101/download?format=xlsx&from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="MCQ-summary-98101-2019-03-01-to-2019-03-31.xlsx"
[Asserts]
bytes startsWith hex,504b;

GET {{base_url}}/reports/mcq-summary/98101/download?format=pdf&from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
Content-Type: application/pdf
Content-Disposition: attachment; filename="MCQ-summary-98101-2019-03-01-to-2019-03-31.pdf"
[Asserts]
bytes startsWith hex,25504446;

# 3. A class outside reach, unknown, 0 and a word are files too (the empty class, or the first class in reach); the name carries the id as asked
GET {{base_url}}/reports/mcq-summary/98103/download?format=xlsx&from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
Content-Disposition: attachment; filename="MCQ-summary-98103-2019-03-01-to-2019-03-31.xlsx"

GET {{base_url}}/reports/mcq-summary/0/download?format=xlsx&from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
Content-Disposition: attachment; filename="MCQ-summary-0-2019-03-01-to-2019-03-31.xlsx"

GET {{base_url}}/reports/mcq-summary/abc/download?format=xlsx&from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
Content-Disposition: attachment; filename="MCQ-summary-abc-2019-03-01-to-2019-03-31.xlsx"

GET {{base_url}}/reports/mcq-summary/98104/download?format=xlsx&from=2019-03-01&to=2019-03-31&gender=2
Authorization: {{auth_r2_coord}}
HTTP 200
