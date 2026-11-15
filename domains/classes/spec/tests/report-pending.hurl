# GET /reports/pending contract: per teacher, the class forms not filled in the months and the standard MCQs copied but not conducted. Runs against any implementation.
# Variables: base_url and auth_<alias>. B5C fixtures (db/synthetic/classes-b5c-fixtures.sql): the coordinator rc_coord reaches the gents classes 9564 (MIQDAD) and 9565 (ABUZAR) and the ladies class 9567 (MIQDAD) only, so its
# answers are compared in full; it has classes of both genders, so the gender asked for decides. The months are fixed (October 2025) so a run does not depend on today. The MCQ figures ignore the months: MIQDAD has three
# standard MCQs (a fourth is deleted), ABUZAR one; 9564 copied M1 (two published copies, one deactivated copy ignored) and M2 (not published); 9567 copied "b5c-m1" (case-insensitive match) and M2 (not published).
# 9566 (SALMAN, outside the coordinator's reach, teacher 901912) and the closed class 9568 are seen only by the administrators.

# 1. Without sign-in: 401; without reports:read: 403
GET {{base_url}}/reports/pending
HTTP 401

GET {{base_url}}/reports/pending?from=10-2025&to=10-2025
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. The coordinator, gents (no gender lock: it holds classes of both genders): the teacher with the classes behind the totals, ABUZAR before MIQDAD (level order)
GET {{base_url}}/reports/pending?from=10-2025&to=10-2025
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.from" == "10-2025"
jsonpath "$.to" == "10-2025"
jsonpath "$.levels" count == 2
jsonpath "$.levels[0]" == "ABUZAR"
jsonpath "$.levels[1]" == "MIQDAD"
jsonpath "$.teachers" count == 1
jsonpath "$.teachers[0].teacherToken" == 901911
jsonpath "$.teachers[0].teacher" == "Rc Member 901911"
jsonpath "$.teachers[0].notFilled" == 8
jsonpath "$.teachers[0].mcqPending" == 1
jsonpath "$.teachers[0].classes" count == 2
jsonpath "$.teachers[0].classes[0].classId" == 9565
jsonpath "$.teachers[0].classes[0].level" == "ABUZAR"
jsonpath "$.teachers[0].classes[0].class" == "RC-G-565"
jsonpath "$.teachers[0].classes[0].notFilled" == 3
jsonpath "$.teachers[0].classes[0].mcqPending" == 0
jsonpath "$.teachers[0].classes[0].mcqConducted" == 0
jsonpath "$.teachers[0].classes[0].mcqExpected" == 1
jsonpath "$.teachers[0].classes[1].classId" == 9564
jsonpath "$.teachers[0].classes[1].level" == "MIQDAD"
jsonpath "$.teachers[0].classes[1].notFilled" == 5
jsonpath "$.teachers[0].classes[1].mcqPending" == 1
jsonpath "$.teachers[0].classes[1].mcqConducted" == 1
jsonpath "$.teachers[0].classes[1].mcqExpected" == 3

# 3. The same coordinator asking for ladies (two months): only the ladies class 9567, whose forms are all missing
GET {{base_url}}/reports/pending?from=10-2025&to=11-2025&gender=2
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.levels" count == 1
jsonpath "$.teachers" count == 1
jsonpath "$.teachers[0].teacherToken" == 901913
jsonpath "$.teachers[0].notFilled" == 8
jsonpath "$.teachers[0].mcqPending" == 1
jsonpath "$.teachers[0].classes" count == 1
jsonpath "$.teachers[0].classes[0].classId" == 9567
jsonpath "$.teachers[0].classes[0].notFilled" == 8
jsonpath "$.teachers[0].classes[0].mcqConducted" == 1
jsonpath "$.teachers[0].classes[0].mcqExpected" == 3

# 4. The level narrows the teachers after the levels are listed; the totals are recounted; the level is trimmed and compared exactly
GET {{base_url}}/reports/pending?from=10-2025&to=10-2025&level=MIQDAD
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.levels" count == 2
jsonpath "$.teachers" count == 1
jsonpath "$.teachers[0].notFilled" == 5
jsonpath "$.teachers[0].mcqPending" == 1
jsonpath "$.teachers[0].classes" count == 1
jsonpath "$.teachers[0].classes[0].classId" == 9564

GET {{base_url}}/reports/pending?from=10-2025&to=10-2025&level=%20ABUZAR%20
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.teachers[0].notFilled" == 3
jsonpath "$.teachers[0].mcqPending" == 0
jsonpath "$.teachers[0].classes" count == 1
jsonpath "$.teachers[0].classes[0].classId" == 9565

GET {{base_url}}/reports/pending?from=10-2025&to=10-2025&level=miqdad
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.levels" count == 2
jsonpath "$.teachers" count == 0

# 5. A year of months (the longest allowed) counts every missing form since the class began; a month ending with a line break is accepted and echoed
GET {{base_url}}/reports/pending?from=11-2024&to=10-2025
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.teachers[0].notFilled" == 119
jsonpath "$.teachers[0].classes[0].notFilled" == 40
jsonpath "$.teachers[0].classes[1].notFilled" == 79

GET {{base_url}}/reports/pending?from=10-2025&to=10-2025%0A
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.to" == "10-2025\n"
jsonpath "$.teachers[0].notFilled" == 8

# 6. Bad months are 422 in PHP's words
GET {{base_url}}/reports/pending?from=13-2025&to=10-2025
Authorization: {{auth_rc_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be months as MM-YYYY, from not after to"

GET {{base_url}}/reports/pending?from=11-2025&to=10-2025
Authorization: {{auth_rc_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be months as MM-YYYY, from not after to"

GET {{base_url}}/reports/pending?from=01-2025&to=02-2026
Authorization: {{auth_rc_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The range can cover at most 12 months"

# 7. The default months (last month to this month) are always valid
GET {{base_url}}/reports/pending
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.from" matches /^[0-9]{2}-[0-9]{4}$/
jsonpath "$.to" matches /^[0-9]{2}-[0-9]{4}$/
jsonpath "$.teachers" isCollection

# 8. A gender administrator is held to their gender; the closed class 9568 and the ladies class are not listed
GET {{base_url}}/reports/pending?from=10-2025&to=10-2025&gender=2
Authorization: {{auth_en_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.teachers[?(@.teacherToken==901911)].classes[?(@.classId==9564)].notFilled" == 5
jsonpath "$.teachers[?(@.teacherToken==901912)].classes[?(@.classId==9566)].mcqExpected" == 0
jsonpath "$..classId" not contains 9567
jsonpath "$..classId" not contains 9568

GET {{base_url}}/reports/pending?from=10-2025&to=10-2025&gender=1
Authorization: {{auth_en_ladmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.teachers[?(@.teacherToken==901913)].classes[?(@.classId==9567)].mcqConducted" == 1
jsonpath "$..classId" not contains 9564
