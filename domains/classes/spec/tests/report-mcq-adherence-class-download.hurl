# GET /reports/mcq-adherence/{class_id}/download?format=xlsx|pdf&gender contract: the class's MCQs in the screen's order with their status. Runs against any implementation
# (the xlsx cells are compared with PHP by tools/export-parity.sh, cases in tools/export-parity.cases).
# Variables: base_url and auth_r2_<alias>. REPORTS2 fixtures (see report-mcq-adherence.hurl). The format is checked BEFORE the sign-in (422 first).

# 1. A bad format is 422 first, then sign-in (401) and permission (403)
GET {{base_url}}/reports/mcq-adherence/98101/download
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be xlsx or pdf"

GET {{base_url}}/reports/mcq-adherence/98101/download?format=Pdf
Authorization: {{auth_r2_coord}}
HTTP 422

GET {{base_url}}/reports/mcq-adherence/98101/download?format=xlsx
HTTP 401

GET {{base_url}}/reports/mcq-adherence/98101/download?format=xlsx
Authorization: {{auth_r2_nobody}}
HTTP 403

# 2. xlsx and pdf, file names
GET {{base_url}}/reports/mcq-adherence/98101/download?format=xlsx
Authorization: {{auth_r2_coord}}
HTTP 200
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="MCQ-adherence-98101.xlsx"
[Asserts]
bytes startsWith hex,504b;

GET {{base_url}}/reports/mcq-adherence/98101/download?format=pdf
Authorization: {{auth_r2_coord}}
HTTP 200
Content-Type: application/pdf
Content-Disposition: attachment; filename="MCQ-adherence-98101.pdf"
[Asserts]
bytes startsWith hex,25504446;

# 3. A class outside reach, unknown, 0 and a word are files too (the empty class, or the worst class in reach)
GET {{base_url}}/reports/mcq-adherence/98103/download?format=xlsx
Authorization: {{auth_r2_coord}}
HTTP 200
Content-Disposition: attachment; filename="MCQ-adherence-98103.xlsx"

GET {{base_url}}/reports/mcq-adherence/0/download?format=xlsx
Authorization: {{auth_r2_coord}}
HTTP 200
Content-Disposition: attachment; filename="MCQ-adherence-0.xlsx"

GET {{base_url}}/reports/mcq-adherence/abc/download?format=pdf
Authorization: {{auth_r2_coord}}
HTTP 200
Content-Disposition: attachment; filename="MCQ-adherence-abc.pdf"

GET {{base_url}}/reports/mcq-adherence/98104/download?format=xlsx&gender=2
Authorization: {{auth_r2_coord}}
HTTP 200
