# MCQ adherence, cases only the new API runs. PHP is not run on this file: its report walks every class of the gender with a query each, so an administrator's list over the whole parity database is slow there. Also hostile input:
# NUL bytes and huge numbers are never a 500.
# Variables: base_url and auth_r2_<alias>. REPORTS2 fixtures (see report-mcq-adherence.hurl). Administrators also see the other fixtures' classes: only the fixture classes are asserted, by id.

# 1. The gents administrator: the gender lock wins over ?gender=2; 98103 (SALMAN, 0 percent, one MCQ pending) is listed, the closed 98105 and the ladies class are not
GET {{base_url}}/reports/mcq-adherence?gender=2
Authorization: {{auth_r2_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$..classId" contains 98103
jsonpath "$..classId" contains 98101
jsonpath "$..classId" not contains 98105
jsonpath "$..classId" not contains 98104
jsonpath "$.classes[?(@.classId==98103)].expected" == 2
jsonpath "$.classes[?(@.classId==98103)].pending" == 1
jsonpath "$.classes[?(@.classId==98103)].adherencePercent" == 0.0

# 2. The ladies administrator: her gender whatever is asked
GET {{base_url}}/reports/mcq-adherence?gender=1
Authorization: {{auth_r2_ladmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.classes[?(@.classId==98104)].expected" == 3
jsonpath "$.classes[?(@.classId==98101)]" not exists

# 3. An administrator's class routes: 98103 by id, the other gender's class empty
GET {{base_url}}/reports/mcq-adherence/98103
Authorization: {{auth_r2_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.expected" == 2
jsonpath "$.pending" == 1
jsonpath "$.skipped" == 1
jsonpath "$.mcqs[0].name" == "R2 MCQ seven"
jsonpath "$.mcqs[0].status" == "pending"

GET {{base_url}}/reports/mcq-adherence/98104
Authorization: {{auth_r2_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.expected" == 0

GET {{base_url}}/reports/mcq-adherence/download-all?classIds=98103
Authorization: {{auth_r2_gadmin}}
HTTP 200
[Asserts]
body contains "R2-G-103,SALMAN,\"R2 Member 921012\",\"R2 Hall\",2,0,1,1,0,R2-S1,"

# 4. NUL bytes and huge numbers are never a 500
GET {{base_url}}/reports/mcq-adherence?gender=%00
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1

GET {{base_url}}/reports/mcq-adherence/download-all?classIds=%00
Authorization: {{auth_r2_coord}}
HTTP 200

GET {{base_url}}/reports/mcq-adherence/download-all?classIds=99999999999999999999999,98101
Authorization: {{auth_r2_coord}}
HTTP 200

GET {{base_url}}/reports/mcq-adherence/9223372036854775808
Authorization: {{auth_r2_coord}}
HTTP 200

# 5. A hostile class id in the file name is cut to safe characters (PHP echoes the raw text)
GET {{base_url}}/reports/mcq-adherence/a%20b%0Ac/download?format=xlsx
Authorization: {{auth_r2_coord}}
HTTP 200
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="MCQ-adherence-a b_c.xlsx"
[Asserts]
bytes startsWith hex,504b;
