# GET /reports/class-sessions contract: every active class the caller reaches with how many sessions it has recorded and what the last one covered. Runs against any implementation.
# Variables: base_url and auth_<alias>. B5A fixtures (see report-conduction.hurl). 9581 has 6 sessions, the last on 27 Nov 2025 (not held, surah 2 verse 0: the quran text is "2" here, a verse of 0 is dropped); 9582 has one (11 Nov,
# aqaed "Aqaed Two").

# 1. Without sign-in: 401; without reports:read: 403
GET {{base_url}}/reports/class-sessions
HTTP 401

GET {{base_url}}/reports/class-sessions
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. The coordinator: its two classes in level order
GET {{base_url}}/reports/class-sessions
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.levels" count == 2
jsonpath "$.levels[0]" == "ABUZAR"
jsonpath "$.levels[1]" == "MIQDAD"
jsonpath "$.classes" count == 2
jsonpath "$.classes[0].classId" == 9582
jsonpath "$.classes[0].class" == "RP-G-582"
jsonpath "$.classes[0].level" == "ABUZAR"
jsonpath "$.classes[0].teacher" == "Rp Member 901413"
jsonpath "$.classes[0].totalSessions" == 1
jsonpath "$.classes[0].lastDate" == "2025-11-11"
jsonpath "$.classes[0].lastQuran" == null
jsonpath "$.classes[0].lastArabic" == null
jsonpath "$.classes[0].lastAqaed" == "Aqaed Two"
jsonpath "$.classes[0].lastAhkam" == null
jsonpath "$.classes[1].classId" == 9581
jsonpath "$.classes[1].class" == "RP-G-581"
jsonpath "$.classes[1].level" == "MIQDAD"
jsonpath "$.classes[1].totalSessions" == 6
jsonpath "$.classes[1].lastDate" == "2025-11-27"
jsonpath "$.classes[1].lastQuran" == "2"
jsonpath "$.classes[1].lastArabic" == null
jsonpath "$.classes[1].lastAqaed" == null
jsonpath "$.classes[1].lastAkhlaq" == null
jsonpath "$.classes[1].lastOther" == null

# 3. The level narrows the classes, not the levels
GET {{base_url}}/reports/class-sessions?level=MIQDAD
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.levels" count == 2
jsonpath "$.classes" count == 1
jsonpath "$.classes[0].classId" == 9581

# 4. Gender: the ladies administrator is held to ladies, the gents administrator to gents, the coordinator to its own
GET {{base_url}}/reports/class-sessions?gender=1
Authorization: {{auth_en_ladmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.classes[?(@.classId==9583)].totalSessions" == 1
jsonpath "$.classes[?(@.classId==9581)]" not exists

GET {{base_url}}/reports/class-sessions?gender=2
Authorization: {{auth_en_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.classes[?(@.classId==9581)].totalSessions" == 6
jsonpath "$.classes[?(@.classId==9583)]" not exists

GET {{base_url}}/reports/class-sessions?gender=2
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.classes" count == 2

# 5. The super administrator: gents by default (the other city's class too, never the closed class or the demo class), ladies for the text 2
GET {{base_url}}/reports/class-sessions
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.classes[?(@.classId==9584)].totalSessions" == 1
jsonpath "$.classes[?(@.classId==9585)]" not exists
jsonpath "$.classes[?(@.classId==9586)]" not exists
jsonpath "$.classes[?(@.class=='AYD1')]" not exists
jsonpath "$.classes[?(@.classId==9583)]" not exists

GET {{base_url}}/reports/class-sessions?gender=2
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.classes[?(@.classId==9583)].class" == "RP-L-583"
