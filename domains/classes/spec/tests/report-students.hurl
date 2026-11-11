# GET /reports/students contract: every student of every class the caller reaches with attendance, MCQ and recitation figures over a range of days, best score first. Runs against any implementation.
# Variables: base_url and auth_<alias>. B5C fixtures (db/synthetic/classes-b5c-fixtures.sql): the coordinator rc_coord reaches the gents classes 9564 (MIQDAD) and 9565 (ABUZAR) and the ladies class 9567 only, so its answers are compared in
# full. The ranges are fixed (October and early November 2025). Facts the fixtures carry: 901922 is in two classes (two rows, each with that class's figures, one recitation total); 901923 left 9564 (no row); 901924 has enrolment status I but
# is not removed (a row, but recitation 0: the leaderboard asks status A); 901926 is a ladies-class student whose own gender is gents (recitation 0 in the ladies report); the recitation is the token's whole range, held or not (901921 has
# 100000 marked in a session that was not held); a quiz published at noon on 5 November is in the range only when the range ends on the 6th. 9566 (901928, outside the coordinator's reach) and the closed class 9568 are seen only by administrators.

# 1. Without sign-in: 401; without reports:read: 403
GET {{base_url}}/reports/students
HTTP 401

GET {{base_url}}/reports/students?from=2025-10-01&to=2025-11-05
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. The coordinator, gents: best score first, the pickers by level order and class code
GET {{base_url}}/reports/students?from=2025-10-01&to=2025-11-05
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.from" == "2025-10-01"
jsonpath "$.to" == "2025-11-05"
jsonpath "$.levels" count == 2
jsonpath "$.levels[0]" == "ABUZAR"
jsonpath "$.levels[1]" == "MIQDAD"
jsonpath "$.classes" count == 2
jsonpath "$.classes[0].class" == "RC-G-565"
jsonpath "$.classes[0].level" == "ABUZAR"
jsonpath "$.classes[1].class" == "RC-G-564"
jsonpath "$.classes[1].level" == "MIQDAD"
jsonpath "$.students" count == 4
jsonpath "$.students[0].token" == "901921"
jsonpath "$.students[0].name" == "Rc Member 901921"
jsonpath "$.students[0].level" == "MIQDAD"
jsonpath "$.students[0].class" == "RC-G-564"
jsonpath "$.students[0].sessions" == 5
jsonpath "$.students[0].attendance" == 80
jsonpath "$.students[0].totalMcqs" == 2
jsonpath "$.students[0].mcqAttempted" == 100
jsonpath "$.students[0].mcqPerformance" == 80
jsonpath "$.students[0].recitation" == 110000
jsonpath "$.students[0].recitationAvg" == 22000.0
jsonpath "$.students[0].tsrScore" == 87
jsonpath "$.students[1].token" == "901922"
jsonpath "$.students[1].class" == "RC-G-564"
jsonpath "$.students[1].sessions" == 2
jsonpath "$.students[1].attendance" == 50
jsonpath "$.students[1].mcqAttempted" == 50
jsonpath "$.students[1].mcqPerformance" == 20
jsonpath "$.students[1].recitation" == 3000
jsonpath "$.students[1].recitationAvg" == 1500.0
jsonpath "$.students[1].tsrScore" == 40
jsonpath "$.students[2].token" == "901922"
jsonpath "$.students[2].class" == "RC-G-565"
jsonpath "$.students[2].attendance" == 100
jsonpath "$.students[2].totalMcqs" == 0
jsonpath "$.students[2].recitation" == 3000
jsonpath "$.students[2].tsrScore" == 33
jsonpath "$.students[3].token" == "901924"
jsonpath "$.students[3].attendance" == 50
jsonpath "$.students[3].totalMcqs" == 2
jsonpath "$.students[3].mcqAttempted" == 0
jsonpath "$.students[3].recitation" == 0
jsonpath "$.students[3].recitationAvg" == 0.0
jsonpath "$.students[3].tsrScore" == 17

# 3. The same coordinator asking for ladies: only the ladies class; the student whose own gender is gents has no recitation
GET {{base_url}}/reports/students?from=2025-10-01&to=2025-11-05&gender=2
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.levels" count == 1
jsonpath "$.classes" count == 1
jsonpath "$.students" count == 2
jsonpath "$.students[0].token" == "901925"
jsonpath "$.students[0].attendance" == 100
jsonpath "$.students[0].totalMcqs" == 1
jsonpath "$.students[0].mcqAttempted" == 100
jsonpath "$.students[0].mcqPerformance" == 50
jsonpath "$.students[0].recitation" == 3000
jsonpath "$.students[0].tsrScore" == 83
jsonpath "$.students[1].token" == "901926"
jsonpath "$.students[1].recitation" == 0
jsonpath "$.students[1].tsrScore" == 33

# 4. A quiz published at noon on the last day is not in the range; the next day it is (the two rows of 901922 tie on the score here, so they are found by class)
GET {{base_url}}/reports/students?from=2025-10-01&to=2025-11-06
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.students[0].totalMcqs" == 3
jsonpath "$.students[0].mcqPerformance" == 83
jsonpath "$.students[0].tsrScore" == 88
jsonpath "$.students[?(@.token=='901922' && @.class=='RC-G-564')].mcqAttempted" == 33

# 5. A narrow range: only the students with an attendance mark in it are listed (and the classes and levels of those)
GET {{base_url}}/reports/students?from=2025-11-01&to=2025-11-05
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.levels" count == 1
jsonpath "$.classes" count == 1
jsonpath "$.students" count == 1
jsonpath "$.students[0].token" == "901921"
jsonpath "$.students[0].sessions" == 1
jsonpath "$.students[0].recitation" == 5000

GET {{base_url}}/reports/students?from=2025-12-01&to=2025-12-05
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.levels" count == 0
jsonpath "$.classes" count == 0
jsonpath "$.students" count == 0

# 6. A day with a line break after it is accepted and echoed
GET {{base_url}}/reports/students?from=2025-10-01&to=2025-11-05%0A
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.to" == "2025-11-05\n"
jsonpath "$.students" count == 4

# 7. Bad days are 422 in PHP's words
GET {{base_url}}/reports/students?from=2025-02-30&to=2025-03-05
Authorization: {{auth_rc_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be dates as YYYY-MM-DD, from not after to"

GET {{base_url}}/reports/students?from=2025-11-05&to=2025-11-04
Authorization: {{auth_rc_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be dates as YYYY-MM-DD, from not after to"

GET {{base_url}}/reports/students?from=2024-01-01&to=2025-11-04
Authorization: {{auth_rc_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The range can cover at most a year"

GET {{base_url}}/reports/students?to=2025-11-04
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.from" == "2025-10-05"

# 8. The default range (the last 30 days) is always valid
GET {{base_url}}/reports/students
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.from" matches /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/
jsonpath "$.students" isCollection

# 9. A gender administrator is held to their gender: a student of an outside class (9566) is listed, never a ladies student or a student of the closed class
GET {{base_url}}/reports/students?from=2025-10-01&to=2025-11-05&gender=2
Authorization: {{auth_en_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.students[?(@.token=='901928')].class" == "RC-G-566"
jsonpath "$.students[?(@.token=='901928')].recitation" == 6000
jsonpath "$.students[*].token" not contains "901925"
jsonpath "$.students[*].token" not contains "901927"

GET {{base_url}}/reports/students?from=2025-10-01&to=2025-11-05&gender=1
Authorization: {{auth_en_ladmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.students[?(@.token=='901925')].class" == "RC-L-567"
jsonpath "$.students[*].token" not contains "901921"
jsonpath "$.students[*].token" not contains "901928"
