# GET /reports/this-week contract: the coordinator's review of the last completed week. Runs against any implementation.
# Variables: base_url and auth_<alias>. B5B fixtures (db/synthetic/classes-b5b-fixtures.sql): the sessions are dated relative to the load time (W0 is the week before this one), so the file passes on any day; the coordinator rb_coord
# reaches 9591 to 9594 only and is compared in full. 9591 met twice in W0 (cell "Yes (2)"), arabic left out for 2 weeks, attendance 2 of 2; 9592 not held for 2 weeks; 9593 filled no form in W0; 9594 (teacher 901513 is a LADIES
# member) met with attendance 1 of 3. The teacher's mobile is shown only where the caller may see that teacher: rb_coord sees the gents teachers' and not the ladies member's.

# 1. Without sign-in: 401; without reports:read: 403
GET {{base_url}}/reports/this-week
HTTP 401

GET {{base_url}}/reports/this-week
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. The coordinator: summary, the week, and every stage
GET {{base_url}}/reports/this-week
Authorization: {{auth_rb_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.week.from" matches /^\d{4}-\d{2}-\d{2}$/
jsonpath "$.week.to" matches /^\d{4}-\d{2}-\d{2}$/
jsonpath "$.summary.met" == 2
jsonpath "$.summary.of" == 3
jsonpath "$.summary.formsMissing" == 1
jsonpath "$.summary.attendance" == 0.67
jsonpath "$.summary.flagged" == 4
jsonpath "$.stages.cform" count == 1
jsonpath "$.stages.cform[0].classId" == 9593
jsonpath "$.stages.cform[0].code" == "RB-G-593"
jsonpath "$.stages.cform[0].level" == "SALMAN"
jsonpath "$.stages.cform[0].teacher" == "Rb Member 901512"
jsonpath "$.stages.cform[0].teacherToken" == 901512
jsonpath "$.stages.cform[0].teacherMobile" == "+910000151512"
jsonpath "$.stages.cform[0].detail" == "Form not submitted"
jsonpath "$.stages.cform[0].action" == "message"
jsonpath "$.stages.cform[0].quiet" count == 0
jsonpath "$.stages.conduction" count == 2
jsonpath "$.stages.conduction[0].classId" == 9592
jsonpath "$.stages.conduction[0].detail" == "No class for 2 weeks"
jsonpath "$.stages.conduction[0].action" == "message"
jsonpath "$.stages.conduction[0].quiet" count == 0
jsonpath "$.stages.conduction[1].classId" == 9591
jsonpath "$.stages.conduction[1].detail" == ""
jsonpath "$.stages.conduction[1].action" == "message"
jsonpath "$.stages.conduction[1].quiet" count == 1
jsonpath "$.stages.conduction[1].quiet[0].subject" == "arabic"
jsonpath "$.stages.conduction[1].quiet[0].weeks" == 2
jsonpath "$.stages.attendance" count == 1
jsonpath "$.stages.attendance[0].classId" == 9594
jsonpath "$.stages.attendance[0].detail" == "Attendance 33%"
jsonpath "$.stages.attendance[0].teacherMobile" == null
jsonpath "$.stages.alignment" count == 4
jsonpath "$.stages.alignment[0].classId" == 9593
jsonpath "$.stages.alignment[1].classId" == 9592
jsonpath "$.stages.alignment[2].classId" == 9591
jsonpath "$.stages.alignment[3].classId" == 9594
jsonpath "$.stages.alignment[3].teacherMobile" == null
jsonpath "$.stages.alignment[2].teacherMobile" == "+910000151511"
jsonpath "$.stages.alignment[2].action" == null
jsonpath "$.stages.met" count == 2
jsonpath "$.stages.met[0].classId" == 9591
jsonpath "$.stages.met[0].detail" == "Met"
jsonpath "$.stages.met[0].teacherMobile" == null
jsonpath "$.stages.met[1].classId" == 9594
jsonpath "$.stages.attended" count == 2
jsonpath "$.stages.attended[0].detail" == "Attendance 100%"
jsonpath "$.stages.attended[1].detail" == "Attendance 33%"

# 3. The coordinator's classes are all gents: asking for ladies changes nothing
GET {{base_url}}/reports/this-week?gender=2
Authorization: {{auth_rb_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.summary.of" == 3
jsonpath "$.stages.alignment" count == 4

# 4. A gender administrator is held to their gender; the other gender's class is never in the lists
GET {{base_url}}/reports/this-week?gender=2
Authorization: {{auth_en_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.stages.alignment[?(@.classId==9591)]" exists
jsonpath "$.stages.alignment[?(@.classId==9595)]" not exists
jsonpath "$.stages.alignment[?(@.classId==9596)]" not exists

GET {{base_url}}/reports/this-week?gender=1
Authorization: {{auth_en_ladmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.stages.alignment[?(@.classId==9595)]" exists
jsonpath "$.stages.alignment[?(@.classId==9591)]" not exists
jsonpath "$.stages.met[?(@.classId==9595)].detail" == "Met"

# 5. The super administrator: gents by default (the closed class 9596 never), ladies for the text 2
GET {{base_url}}/reports/this-week
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.stages.alignment[?(@.classId==9592)]" exists
jsonpath "$.stages.alignment[?(@.classId==9596)]" not exists
jsonpath "$.stages.alignment[?(@.classId==9595)]" not exists
jsonpath "$.stages.conduction[?(@.classId==9592)].detail" == "No class for 2 weeks"
jsonpath "$.stages.conduction[?(@.classId==9592)].teacherMobile" == "+910000151511"
jsonpath "$.stages.cform[?(@.classId==9593)].detail" == "Form not submitted"

GET {{base_url}}/reports/this-week?gender=2
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.stages.alignment[?(@.classId==9595)]" exists
jsonpath "$.stages.alignment[?(@.classId==9591)]" not exists
