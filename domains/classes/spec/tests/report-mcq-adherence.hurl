# GET /reports/mcq-adherence?gender contract: a line per class with standard MCQs, worst adherence first. Runs against any implementation.
# Variables: base_url and auth_r2_<alias>. REPORTS2 fixtures (db/synthetic/reports2-fixtures.sql): standard MCQs of language 71 (MIQDAD: M1 M2 M3, a fourth is deleted; ABUZAR: A1 A2; SALMAN: S1 S2). r2_coord reaches the gents classes
# 98101 (M1 conducted by two published copies and a newer unpublished one, M2 pending, M3 skipped by a deactivated copy: 33.3), 98102 (A1 conducted, A2 pending: 50), 98106 (all three conducted: 100, a teacher with no member row),
# 98107 (nothing copied: 0) and the ladies class 98104 (a lower-case copy of M1 and M2 conducted, M3 pending: 66.7); NOT 98103 (SALMAN, worst: 0) or the closed 98105. The percent is a float: 0.0 and 50.0, never 0 and 50.

# 1. Sign-in (401), permission (403)
GET {{base_url}}/reports/mcq-adherence
HTTP 401

GET {{base_url}}/reports/mcq-adherence
Authorization: {{auth_r2_nobody}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/reports/mcq-adherence
Authorization: {{auth_r2_named}}
HTTP 403

# 2. The coordinator, gents: worst first, ties in class order, the null teacher, floats printed with their decimal point
GET {{base_url}}/reports/mcq-adherence
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.levels" count == 2
jsonpath "$.levels[0]" == "ABUZAR"
jsonpath "$.levels[1]" == "MIQDAD"
jsonpath "$.classes" count == 4
jsonpath "$.classes[0].classId" == 98107
jsonpath "$.classes[0].class" == "R2-G-107"
jsonpath "$.classes[0].level" == "ABUZAR"
jsonpath "$.classes[0].teacher" == "R2 Member 921011"
jsonpath "$.classes[0].expected" == 2
jsonpath "$.classes[0].conducted" == 0
jsonpath "$.classes[0].pending" == 0
jsonpath "$.classes[0].skipped" == 2
jsonpath "$.classes[0].adherencePercent" == 0.0
jsonpath "$.classes[1].classId" == 98101
jsonpath "$.classes[1].expected" == 3
jsonpath "$.classes[1].conducted" == 1
jsonpath "$.classes[1].pending" == 1
jsonpath "$.classes[1].skipped" == 1
jsonpath "$.classes[1].adherencePercent" == 33.3
jsonpath "$.classes[2].classId" == 98102
jsonpath "$.classes[2].adherencePercent" == 50.0
jsonpath "$.classes[3].classId" == 98106
jsonpath "$.classes[3].teacher" == null
jsonpath "$.classes[3].conducted" == 3
jsonpath "$.classes[3].adherencePercent" == 100.0
body contains "\"adherencePercent\":0.0}"
body contains "\"adherencePercent\":50.0}"
body contains "\"adherencePercent\":100.0}"
body contains "\"teacher\":null"

# 3. The ladies class by asking for ladies; one coordinator limited to one class; the closed class and 98103 never
GET {{base_url}}/reports/mcq-adherence?gender=2
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.classes" count == 1
jsonpath "$.classes[0].classId" == 98104
jsonpath "$.classes[0].expected" == 3
jsonpath "$.classes[0].conducted" == 2
jsonpath "$.classes[0].pending" == 1
jsonpath "$.classes[0].skipped" == 0
jsonpath "$.classes[0].adherencePercent" == 66.7

GET {{base_url}}/reports/mcq-adherence
Authorization: {{auth_r2_one}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.classes" count == 1
jsonpath "$.classes[0].classId" == 98101

GET {{base_url}}/reports/mcq-adherence?gender=2
Authorization: {{auth_r2_one}}
HTTP 200
[Asserts]
jsonpath "$.classes" count == 1
jsonpath "$.classes[0].classId" == 98101

# 4. A gender other than "2" is gents
GET {{base_url}}/reports/mcq-adherence?gender=abc
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.classes" count == 4
