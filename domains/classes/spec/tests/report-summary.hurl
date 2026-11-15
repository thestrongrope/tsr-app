# GET /reports/summary contract: per class over the months, the sessions expected (schedule slots of the weeks that are over), held, not filled, not held, the averages and the subjects taught. Runs against any implementation.
# Variables: base_url and auth_<alias>. B5A fixtures (see report-conduction.hurl), months 11-2025 to 11-2025 (weeks 26 Oct to 6 Dec, six weeks). 9581 has two slots a week (12 expected), 6 sessions, 4 held, 7 marks (5 present);
# 9582 has one slot (6 expected) and one held session. A class with no schedule slot does not appear (9584 has one, so it does, for the super administrator).

# 1. Without sign-in: 401; without reports:read: 403
GET {{base_url}}/reports/summary?from=11-2025&to=11-2025
HTTP 401

GET {{base_url}}/reports/summary?from=11-2025&to=11-2025
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. The coordinator: its two classes, level order; every figure a whole number
GET {{base_url}}/reports/summary?from=11-2025&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.from" == "11-2025"
jsonpath "$.to" == "11-2025"
jsonpath "$.levels" count == 2
jsonpath "$.classes" count == 2
jsonpath "$.classes[0].classId" == 9582
jsonpath "$.classes[0].level" == "ABUZAR"
jsonpath "$.classes[0].class" == "RP-G-582"
jsonpath "$.classes[0].teacher" == "Rp Member 901413"
jsonpath "$.classes[0].expected" == 6
jsonpath "$.classes[0].conducted" == 1
jsonpath "$.classes[0].notFilled" == 5
jsonpath "$.classes[0].notConducted" == 0
jsonpath "$.classes[0].avgStudents" == 1
jsonpath "$.classes[0].avgDuration" == 50
jsonpath "$.classes[0].percentNotFilled" == 83
jsonpath "$.classes[0].percentConduction" == 17
jsonpath "$.classes[0].percentAttendance" == 100
jsonpath "$.classes[0].subjects.aqaed.count" == 1
jsonpath "$.classes[0].subjects.aqaed.percent" == 100
jsonpath "$.classes[0].subjects.arabic.count" == 0
jsonpath "$.classes[0].subjects.arabic.percent" == 0
jsonpath "$.classes[1].classId" == 9581
jsonpath "$.classes[1].class" == "RP-G-581"
jsonpath "$.classes[1].expected" == 12
jsonpath "$.classes[1].conducted" == 4
jsonpath "$.classes[1].notFilled" == 6
jsonpath "$.classes[1].notConducted" == 2
jsonpath "$.classes[1].avgStudents" == 2
jsonpath "$.classes[1].avgDuration" == 44
jsonpath "$.classes[1].percentNotFilled" == 50
jsonpath "$.classes[1].percentConduction" == 33
jsonpath "$.classes[1].percentAttendance" == 86
jsonpath "$.classes[1].subjects.arabic.count" == 2
jsonpath "$.classes[1].subjects.arabic.percent" == 50
jsonpath "$.classes[1].subjects.aqaed.count" == 2
jsonpath "$.classes[1].subjects.ahkam.count" == 1
jsonpath "$.classes[1].subjects.ahkam.percent" == 25
jsonpath "$.classes[1].subjects.akhlaq.count" == 0
jsonpath "$.classes[1].subjects.other.count" == 1
jsonpath "$.classes[1].subjects.other.percent" == 25

# 3. The level narrows the classes, not the levels
GET {{base_url}}/reports/summary?from=11-2025&to=11-2025&level=ABUZAR
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.levels" count == 2
jsonpath "$.classes" count == 1
jsonpath "$.classes[0].classId" == 9582

# 4. A month before the classes began: no class; a month wholly in the future: no class, not an error
GET {{base_url}}/reports/summary?from=02-2021&to=02-2021
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.classes" count == 0
jsonpath "$.levels" count == 0

GET {{base_url}}/reports/summary?from=12-2099&to=12-2099
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.classes" count == 0

# 5. Gender: the ladies administrator is held to ladies, the gents administrator to gents, the coordinator to its own
GET {{base_url}}/reports/summary?from=11-2025&to=11-2025&gender=1
Authorization: {{auth_en_ladmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.classes[?(@.classId==9583)].expected" == 6
jsonpath "$.classes[?(@.classId==9581)]" not exists

GET {{base_url}}/reports/summary?from=11-2025&to=11-2025&gender=2
Authorization: {{auth_en_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.classes[?(@.classId==9581)].expected" == 12

GET {{base_url}}/reports/summary?from=11-2025&to=11-2025&gender=2
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.classes" count == 2

# 6. The super administrator: the other city's class is listed, the closed class and the demo class never
GET {{base_url}}/reports/summary?from=11-2025&to=11-2025
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.classes[?(@.classId==9581)].expected" == 12
jsonpath "$.classes[?(@.classId==9584)].expected" == 6
jsonpath "$.classes[?(@.classId==9585)]" not exists
jsonpath "$.classes[?(@.classId==9586)]" not exists
jsonpath "$.classes[?(@.class=='AYD1')]" not exists

# 7. Months wrong: 422. There is no 12-month limit here, and "from" has no default (PHP builds its default with a date text that is not valid, so a request without "from" is always refused)
GET {{base_url}}/reports/summary?to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be months as MM-YYYY, from not after to"

GET {{base_url}}/reports/summary?from=12-2025&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 422

GET {{base_url}}/reports/summary?from=11-2020&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.classes[?(@.classId==9581)].expected" >= 12

GET {{base_url}}/reports/summary?from=11-2025
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.to" matches /^(0[1-9]|1[0-2])-20\d\d$/
jsonpath "$.classes[?(@.classId==9581)].expected" >= 12
