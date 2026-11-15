# GET /reports/subject-conduction contract: per class and week of the months, the date it last met and the topics each subject covered. Runs against any implementation.
# Variables: base_url and auth_<alias>. B5A fixtures (see report-conduction.hurl), month 11-2025. 9581 held on 10 and 13 Nov (week label 2025-W46: its arabic topic "Alif", aqaed "Conducted; Tawhid" (the 10 Nov session
# taught aqaed with no topic), ahkam "Wudu"), 17 Nov (2025-W47) and 24 Nov (2025-W48, "other" taught with no topic: "Conducted"); 9582 on 11 Nov. The sessions not held are not listed.

# 1. Without sign-in: 401; without reports:read: 403
GET {{base_url}}/reports/subject-conduction?from=11-2025&to=11-2025
HTTP 401

GET {{base_url}}/reports/subject-conduction?from=11-2025&to=11-2025
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. The coordinator: the classes it may choose from and one row per class and week
GET {{base_url}}/reports/subject-conduction?from=11-2025&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.from" == "11-2025"
jsonpath "$.to" == "11-2025"
jsonpath "$.levels" count == 2
jsonpath "$.classes" count == 2
jsonpath "$.classes[0].classId" == 9582
jsonpath "$.classes[0].class" == "RP-G-582"
jsonpath "$.classes[0].level" == "ABUZAR"
jsonpath "$.classes[0].teacher" == "Rp Member 901413"
jsonpath "$.classes[1].classId" == 9581
jsonpath "$.rows" count == 4
jsonpath "$.rows[0].class" == "RP-G-582"
jsonpath "$.rows[0].week" == "2025-W46"
jsonpath "$.rows[0].heldOn" == "11 Nov 2025"
jsonpath "$.rows[0].aqaed" == "Aqaed Two"
jsonpath "$.rows[0].arabic" == ""
jsonpath "$.rows[1].class" == "RP-G-581"
jsonpath "$.rows[1].level" == "MIQDAD"
jsonpath "$.rows[1].teacher" == "Rp Member 901411"
jsonpath "$.rows[1].week" == "2025-W46"
jsonpath "$.rows[1].heldOn" == "13 Nov 2025"
jsonpath "$.rows[1].arabic" == "Alif"
jsonpath "$.rows[1].aqaed" == "Conducted; Tawhid"
jsonpath "$.rows[1].ahkam" == "Wudu"
jsonpath "$.rows[1].akhlaq" == ""
jsonpath "$.rows[1].other" == ""
jsonpath "$.rows[2].week" == "2025-W47"
jsonpath "$.rows[2].heldOn" == "17 Nov 2025"
jsonpath "$.rows[2].arabic" == "Alif"
jsonpath "$.rows[3].week" == "2025-W48"
jsonpath "$.rows[3].heldOn" == "24 Nov 2025"
jsonpath "$.rows[3].other" == "Conducted"

# 3. The level and the class narrow the rows, not the levels or the choices
GET {{base_url}}/reports/subject-conduction?from=11-2025&to=11-2025&level=ABUZAR
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.levels" count == 2
jsonpath "$.classes" count == 2
jsonpath "$.rows" count == 1

GET {{base_url}}/reports/subject-conduction?from=11-2025&to=11-2025&classId=9581
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.levels" count == 2
jsonpath "$.rows" count == 3
jsonpath "$.rows[0].class" == "RP-G-581"

# 4. A class the caller does not reach is 403, and so is one that does not exist or is closed
GET {{base_url}}/reports/subject-conduction?from=11-2025&to=11-2025&classId=9584
Authorization: {{auth_rp_coord}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/reports/subject-conduction?from=11-2025&to=11-2025&classId=9585
Authorization: {{auth_rp_coord}}
HTTP 403

GET {{base_url}}/reports/subject-conduction?from=11-2025&to=11-2025&classId=999999
Authorization: {{auth_rp_coord}}
HTTP 403

# 5. The months are read before the class: a bad month wins over a class that is not reachable
GET {{base_url}}/reports/subject-conduction?from=13-2025&classId=9584
Authorization: {{auth_rp_coord}}
HTTP 422

# 6. Gender: the ladies administrator is held to ladies, the gents administrator to gents
GET {{base_url}}/reports/subject-conduction?from=11-2025&to=11-2025&gender=1
Authorization: {{auth_en_ladmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.rows[?(@.class=='RP-L-583')].heldOn" == "12 Nov 2025"
jsonpath "$.rows[?(@.class=='RP-G-581')]" not exists

GET {{base_url}}/reports/subject-conduction?from=11-2025&to=11-2025&gender=2
Authorization: {{auth_en_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.rows[?(@.class=='RP-G-582')].heldOn" == "11 Nov 2025"
jsonpath "$.rows[?(@.class=='RP-L-583')]" not exists

# 7. The super administrator: the other city's class is there, never the closed class or the demo class
GET {{base_url}}/reports/subject-conduction?from=11-2025&to=11-2025
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.classes[?(@.classId==9584)].class" == "RP-G-584"
jsonpath "$.classes[?(@.classId==9585)]" not exists
jsonpath "$.classes[?(@.classId==9586)]" not exists
jsonpath "$.classes[?(@.class=='AYD1')]" not exists
jsonpath "$.rows[?(@.class=='RP-G-584')].heldOn" == "10 Nov 2025"
jsonpath "$.rows[?(@.class=='RP-G-585')]" not exists
jsonpath "$.rows[?(@.class=='AYD1')]" not exists

# 8. Two months: October has none of the fixtures' sessions; no months: this month
GET {{base_url}}/reports/subject-conduction?from=10-2025&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.rows" count == 4

GET {{base_url}}/reports/subject-conduction
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.from" matches /^(0[1-9]|1[0-2])-20\d\d$/
jsonpath "$.to" matches /^(0[1-9]|1[0-2])-20\d\d$/
jsonpath "$.classes" count == 2

# 9. Months wrong: 422
GET {{base_url}}/reports/subject-conduction?from=12-2025&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be months as MM-YYYY, from not after to"

GET {{base_url}}/reports/subject-conduction?from=11-2024&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The range can cover at most 12 months"
