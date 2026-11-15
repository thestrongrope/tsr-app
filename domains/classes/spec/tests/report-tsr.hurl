# GET /reports/tsr contract: TSR at a glance, per level and per class: classes that held a session or set an MCQ, their attendance and Quran recitation in the range. Runs against any implementation.
# Variables: base_url and auth_<alias>. B5C fixtures (db/synthetic/classes-b5c-fixtures.sql): the coordinator rc_coord reaches the gents classes 9564 (MIQDAD, code MK) and 9565 (ABUZAR, AG) and the ladies class 9567 (MK) only, so its answers
# are compared in full; it holds classes of both genders, so the gender asked for decides, but the LEVEL rows count every gender of its reach (a level with no class of the asked gender still shows, with a total of 0). The ranges are fixed
# (October and early November 2025). Ties are not asserted in order (PHP leaves them to the database). 9566 (SALMAN, outside the coordinator's reach) and the closed class 9568 (recitation 9000) are seen only by the administrators.

# 1. Without sign-in: 401; without reports:read: 403
GET {{base_url}}/reports/tsr
HTTP 401

GET {{base_url}}/reports/tsr?from=2025-10-01&to=2025-11-05
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. The coordinator, gents, over the whole range
GET {{base_url}}/reports/tsr?from=2025-10-01&to=2025-11-05
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.from" == "2025-10-01"
jsonpath "$.to" == "2025-11-05"
jsonpath "$.conduction.levels" count == 2
jsonpath "$.conduction.levels[0].levelId" == 2
jsonpath "$.conduction.levels[0].level" == "AG"
jsonpath "$.conduction.levels[0].conducted" == 1
jsonpath "$.conduction.levels[0].total" == 1
jsonpath "$.conduction.levels[0].percent" == 100.0
jsonpath "$.conduction.levels[1].level" == "MK"
jsonpath "$.conduction.levels[1].total" == 1
jsonpath "$.conduction.classes" count == 2
jsonpath "$.conduction.classes[0].class" == "RC-G-564"
jsonpath "$.conduction.classes[0].level" == "MK"
jsonpath "$.conduction.classes[0].teacher" == "Rc Member 901911"
jsonpath "$.conduction.classes[0].lastConducted" == "2025-11-03"
jsonpath "$.conduction.classes[1].class" == "RC-G-565"
jsonpath "$.conduction.classes[1].lastConducted" == "2025-10-14"
jsonpath "$.mcq.levels[0].conducted" == 0
jsonpath "$.mcq.levels[0].total" == 1
jsonpath "$.mcq.levels[0].percent" == 0.0
jsonpath "$.mcq.levels[1].conducted" == 1
jsonpath "$.mcq.levels[1].percent" == 100.0
jsonpath "$.mcq.classes[0].class" == "RC-G-564"
jsonpath "$.mcq.classes[0].lastConducted" == "2025-10-20 10:00:00"
jsonpath "$.mcq.classes[1].class" == "RC-G-565"
jsonpath "$.mcq.classes[1].lastConducted" == null
jsonpath "$.attendance.levels[0].level" == "AG"
jsonpath "$.attendance.levels[0].percent" == 100
jsonpath "$.attendance.levels[1].level" == "MK"
jsonpath "$.attendance.levels[1].percent" == 70
jsonpath "$.attendance.classes[0].class" == "RC-G-565"
jsonpath "$.attendance.classes[0].percent" == 100
jsonpath "$.attendance.classes[1].class" == "RC-G-564"
jsonpath "$.attendance.classes[1].percent" == 70
jsonpath "$.recitation.levels[0].level" == "AG"
jsonpath "$.recitation.levels[0].total" == 2000
jsonpath "$.recitation.levels[1].total" == 21000
jsonpath "$.recitation.classes[0].class" == "RC-G-564"
jsonpath "$.recitation.classes[0].total" == 21000
jsonpath "$.recitation.classes[1].class" == "RC-G-565"
jsonpath "$.recitation.classes[1].total" == 2000

# 3. The same coordinator asking for ladies: the one ladies class, and the ABUZAR level shows with a total of 0 (levels are not narrowed to the gender)
GET {{base_url}}/reports/tsr?from=2025-10-01&to=2025-11-05&gender=2
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.conduction.levels" count == 2
jsonpath "$.conduction.levels[0].level" == "AG"
jsonpath "$.conduction.levels[0].total" == 0
jsonpath "$.conduction.levels[0].percent" == 0.0
jsonpath "$.conduction.levels[1].conducted" == 1
jsonpath "$.conduction.levels[1].total" == 1
jsonpath "$.conduction.classes" count == 1
jsonpath "$.conduction.classes[0].class" == "RC-L-567"
jsonpath "$.conduction.classes[0].lastConducted" == "2025-10-15"
jsonpath "$.mcq.classes[0].lastConducted" == "2025-10-12 10:00:00"
jsonpath "$.attendance.levels[0].percent" == 0
jsonpath "$.attendance.levels[1].percent" == 100
jsonpath "$.attendance.classes" count == 1
jsonpath "$.recitation.levels" count == 2
jsonpath "$.recitation.levels[0].total" == 0
jsonpath "$.recitation.levels[1].total" == 10000
jsonpath "$.recitation.classes" count == 1
jsonpath "$.recitation.classes[0].total" == 10000

# 4. A second range: only 9564 held a session (a day in it), no attendance mark falls in it; a session that was not held is not counted
GET {{base_url}}/reports/tsr?from=2025-10-16&to=2025-10-31
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.conduction.levels[0].conducted" == 0
jsonpath "$.conduction.levels[1].conducted" == 1
jsonpath "$.conduction.classes[0].class" == "RC-G-564"
jsonpath "$.conduction.classes[0].lastConducted" == "2025-10-27"
jsonpath "$.conduction.classes[1].lastConducted" == null
jsonpath "$.mcq.classes[0].lastConducted" == "2025-10-20 10:00:00"
jsonpath "$.attendance.classes[0].percent" == 0
jsonpath "$.recitation.classes" count == 1
jsonpath "$.recitation.classes[0].total" == 0
jsonpath "$.recitation.levels" count == 1

# 5. A quiz is in the range only when published before midnight of the last day: one published at noon on 5 November shows only when the range ends on the 6th
GET {{base_url}}/reports/tsr?from=2025-11-01&to=2025-11-05
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.mcq.levels[0].conducted" == 0
jsonpath "$.mcq.levels[1].conducted" == 0
jsonpath "$.recitation.classes" count == 1
jsonpath "$.recitation.classes[0].total" == 5000

GET {{base_url}}/reports/tsr?from=2025-11-01&to=2025-11-06
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.mcq.levels[1].conducted" == 1
jsonpath "$.mcq.classes[0].class" == "RC-G-564"
jsonpath "$.mcq.classes[0].lastConducted" == "2025-11-05 12:00:00"

# 6. A range with nothing in it: every level and class is still listed, no recitation
GET {{base_url}}/reports/tsr?from=2025-12-01&to=2025-12-02
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.conduction.levels" count == 2
jsonpath "$.conduction.classes" count == 2
jsonpath "$.attendance.classes" count == 2
jsonpath "$.attendance.classes[0].percent" == 0
jsonpath "$.recitation.levels" count == 0
jsonpath "$.recitation.classes" count == 0

# 7. A day with a line break after it is accepted and echoed
GET {{base_url}}/reports/tsr?from=2025-10-01&to=2025-11-05%0A
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.to" == "2025-11-05\n"
jsonpath "$.conduction.classes" count == 2

# 8. Bad days are 422 in PHP's words
GET {{base_url}}/reports/tsr?from=2025-02-30&to=2025-03-05
Authorization: {{auth_rc_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be dates as YYYY-MM-DD, from not after to"

GET {{base_url}}/reports/tsr?from=2025-11-05&to=2025-11-04
Authorization: {{auth_rc_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be dates as YYYY-MM-DD, from not after to"

GET {{base_url}}/reports/tsr?from=10-2025&to=2025-11-04
Authorization: {{auth_rc_coord}}
HTTP 422

GET {{base_url}}/reports/tsr?from=2024-01-01&to=2025-11-04
Authorization: {{auth_rc_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The range can cover at most a year"

GET {{base_url}}/reports/tsr?to=2025-11-04
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.from" == "2025-10-21"

# 9. The default range (the last 14 days) is always valid
GET {{base_url}}/reports/tsr
Authorization: {{auth_rc_coord}}
HTTP 200
[Asserts]
jsonpath "$.from" matches /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/
jsonpath "$.conduction.levels" count == 2

# 10. A gender administrator is held to their gender: the closed class 9568 is not in the conduction list but its recitation is in the recitation list (PHP has no status condition there)
GET {{base_url}}/reports/tsr?from=2025-10-01&to=2025-11-05&gender=2
Authorization: {{auth_en_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.conduction.classes[?(@.class=='RC-G-566')].lastConducted" == "2025-10-06"
jsonpath "$.conduction.classes[*].class" not contains "RC-G-568"
jsonpath "$.conduction.classes[*].class" not contains "RC-L-567"
jsonpath "$.recitation.classes[?(@.class=='RC-G-566')].total" == 6000
jsonpath "$.recitation.classes[?(@.class=='RC-G-568')].total" == 9000
jsonpath "$.recitation.classes[*].class" not contains "RC-L-567"
jsonpath "$.attendance.classes[?(@.class=='RC-G-566')].percent" == 0

GET {{base_url}}/reports/tsr?from=2025-10-01&to=2025-11-05&gender=1
Authorization: {{auth_en_ladmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.conduction.classes[?(@.class=='RC-L-567')].lastConducted" == "2025-10-15"
jsonpath "$.conduction.classes[*].class" not contains "RC-G-564"
jsonpath "$.recitation.classes[*].class" not contains "RC-G-568"
