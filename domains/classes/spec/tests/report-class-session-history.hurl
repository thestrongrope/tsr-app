# GET /reports/class-sessions/{class_id} contract: the class's sessions, newest day first. A class that is missing, closed or out of the caller's reach is 200 with no sessions. Runs against any implementation.
# Variables: base_url and auth_<alias>. B5A fixtures (see report-conduction.hurl). 9581 has 6 sessions (3, 10, 13, 17, 24 and 27 Nov 2025); the quran text is the surah and ":verse" whenever the verse is not empty (a verse of 0 shows
# as ":0"). 9584 is gents in another city, 9585 is closed, 9583 is a ladies class.

# 1. Without sign-in: 401; without reports:read: 403
GET {{base_url}}/reports/class-sessions/9581
HTTP 401

GET {{base_url}}/reports/class-sessions/9581
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. The coordinator reads its class: newest first
GET {{base_url}}/reports/class-sessions/9581
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.sessions" count == 6
jsonpath "$.sessions[0].date" == "2025-11-27"
jsonpath "$.sessions[0].held" == false
jsonpath "$.sessions[0].reason" == "=Rp formula"
jsonpath "$.sessions[0].quran" == "2:0"
jsonpath "$.sessions[1].date" == "2025-11-24"
jsonpath "$.sessions[1].held" == true
jsonpath "$.sessions[1].reason" == null
jsonpath "$.sessions[1].quran" == ""
jsonpath "$.sessions[1].arabic" == ""
jsonpath "$.sessions[2].date" == "2025-11-17"
jsonpath "$.sessions[2].quran" == "3"
jsonpath "$.sessions[2].arabic" == "Alif"
jsonpath "$.sessions[3].date" == "2025-11-13"
jsonpath "$.sessions[3].arabic" == "Hidden"
jsonpath "$.sessions[3].aqaed" == "Tawhid"
jsonpath "$.sessions[3].ahkam" == "Wudu"
jsonpath "$.sessions[3].akhlaq" == ""
jsonpath "$.sessions[3].other" == ""
jsonpath "$.sessions[4].date" == "2025-11-10"
jsonpath "$.sessions[4].quran" == "2:5"
jsonpath "$.sessions[5].date" == "2025-11-03"
jsonpath "$.sessions[5].held" == false
jsonpath "$.sessions[5].reason" == "Rp rain"

# 3. A class outside the coordinator's reach (another city, closed, ladies, missing, text): 200, no sessions
GET {{base_url}}/reports/class-sessions/9584
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.sessions" count == 0

GET {{base_url}}/reports/class-sessions/9585
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.sessions" count == 0

GET {{base_url}}/reports/class-sessions/9583
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.sessions" count == 0

GET {{base_url}}/reports/class-sessions/999999
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.sessions" count == 0

GET {{base_url}}/reports/class-sessions/abc
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.sessions" count == 0

# 4. Reach goes by the class's own gender: the gender administrators read their gender's classes only
GET {{base_url}}/reports/class-sessions/9581
Authorization: {{auth_en_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.sessions" count == 6

GET {{base_url}}/reports/class-sessions/9581
Authorization: {{auth_en_ladmin}}
HTTP 200
[Asserts]
jsonpath "$.sessions" count == 0

GET {{base_url}}/reports/class-sessions/9583
Authorization: {{auth_en_ladmin}}
HTTP 200
[Asserts]
jsonpath "$.sessions" count == 1
jsonpath "$.sessions[0].date" == "2025-11-12"

# 5. The super administrator reads every class's sessions, the other city's class too, but not the closed class
GET {{base_url}}/reports/class-sessions/9584
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.sessions" count == 1
jsonpath "$.sessions[0].date" == "2025-11-10"
