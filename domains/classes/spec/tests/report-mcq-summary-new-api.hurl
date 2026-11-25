# MCQ summary, cases only the new API runs. PHP is not run on this file: its summary walks EVERY class of the gender with three queries each, so an administrator's list over the parity database (hundreds of classes) takes
# longer than 30 seconds there; the new API answers it in five queries. Also hostile input: a NUL byte or a huge number is never a 500 (PHP answers the same where it can).
# Variables: base_url and auth_r2_<alias>. REPORTS2 fixtures (see report-mcq-summary.hurl). Administrators also see the other fixtures' classes: only the fixture classes are asserted, by id.

# 1. The gents administrator: the gender lock wins over ?gender=2; the fixture classes with a quiz in the range, 98103 (SALMAN) first in class order; the closed 98105 and the ladies class never
GET {{base_url}}/reports/mcq-summary?from=2019-03-01&to=2019-03-31&gender=2
Authorization: {{auth_r2_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$..classId" contains 98103
jsonpath "$.classes[?(@.classId==98103)].students" == 1
jsonpath "$.classes[?(@.classId==98101)].mcqs" == 7
jsonpath "$..classId" contains 98107
jsonpath "$..classId" not contains 98105
jsonpath "$..classId" not contains 98104
jsonpath "$.classes[0].classId" == 98103

# 2. The ladies administrator: her gender whatever is asked
GET {{base_url}}/reports/mcq-summary?from=2019-03-01&to=2019-03-31&gender=1
Authorization: {{auth_r2_ladmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.classes[0].classId" == 98104
jsonpath "$.classes" count == 1

# 3. The super administrator: either gender by asking
GET {{base_url}}/reports/mcq-summary?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$..classId" contains 98103

GET {{base_url}}/reports/mcq-summary?from=2019-03-01&to=2019-03-31&gender=2
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.classes[0].classId" == 98104

# 4. The first class of the whole report for an administrator is 98103 (zero and a word); the other gender's class is the empty class
GET {{base_url}}/reports/mcq-summary/0?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.mcqs" == 1
jsonpath "$.maxMarks" == 5
jsonpath "$.students[0].name" == "R2 Member 921026"
jsonpath "$.students[0].percent" == 100

GET {{base_url}}/reports/mcq-summary/98104?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.mcqs" == 0

# 5. The CSV for an administrator holds the other lanes' students too: only the fixture class is asserted
GET {{base_url}}/reports/mcq-summary/download-all?from=2019-03-01&to=2019-03-31&classIds=98103
Authorization: {{auth_r2_gadmin}}
HTTP 200
[Asserts]
body contains "R2-G-103,SALMAN,\"R2 Member 921012\",\"R2 Hall\",\"R2 Member 921026\",1,1,0,5,5,100,5,5"

# 6. NUL bytes and huge numbers are never a 500
GET {{base_url}}/reports/mcq-summary?from=%00&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 422

GET {{base_url}}/reports/mcq-summary?from=2019-03-01&to=2019-03-31&gender=%00
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1

GET {{base_url}}/reports/mcq-summary/download-all?from=2019-03-01&to=2019-03-31&classIds=%00
Authorization: {{auth_r2_coord}}
HTTP 200

GET {{base_url}}/reports/mcq-summary/download-all?from=2019-03-01&to=2019-03-31&classIds=99999999999999999999999,98101
Authorization: {{auth_r2_coord}}
HTTP 200

GET {{base_url}}/reports/mcq-summary/9223372036854775808?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200

GET {{base_url}}/reports/mcq-summary/-9223372036854775809?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200

# 7. A hostile class id in the file name is cut to safe characters (PHP echoes the raw text)
GET {{base_url}}/reports/mcq-summary/a%20b%0Ac/download?format=xlsx&from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="MCQ-summary-a b_c-2019-03-01-to-2019-03-31.xlsx"
[Asserts]
bytes startsWith hex,504b;
