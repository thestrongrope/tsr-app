# GET /reports/class-sessions/download-all contract: every session of every class the caller reaches as CSV (level ignored), 404 when there is none. Runs against any implementation.
# Variables: base_url and auth_<alias>. B5A fixtures (see report-conduction.hurl): the coordinator rp_coord reaches 9581 (6 sessions) and 9582 (1) only, so its file is compared in full. The quran cell is the surah and
# ":verse" whenever the verse is not null (":0" too); a reason that starts with = gets a leading quote.

# 1. Without sign-in: 401; without reports:read: 403
GET {{base_url}}/reports/class-sessions/download-all
HTTP 401

GET {{base_url}}/reports/class-sessions/download-all
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. The coordinator's file, line for line
GET {{base_url}}/reports/class-sessions/download-all
Authorization: {{auth_rp_coord}}
HTTP 200
Content-Type: text/csv;charset=UTF-8
[Asserts]
header "Content-Disposition" matches /^attachment; filename="Class_Sessions_Report_Gents_\d{8}_\d{6}\.csv"$/
body == "\"Class Code\",\"Class Name\",Level,Teacher,Date,Conducted,\"Non-Conduction Reason\",Quran,Arabic,Aqaed,Ahkam,Akhlaq,Other,Attendance,Duration\nRP-G-582,\"Rp Second Class\",ABUZAR,\"Rp Member 901413\",2025-11-11,Yes,,,,\"Aqaed Two\",,,,1,50\nRP-G-581,\"Rp Main Class\",MIQDAD,\"Rp Member 901411\",2025-11-03,No,\"Rp rain\",,,,,,,,\nRP-G-581,\"Rp Main Class\",MIQDAD,\"Rp Member 901411\",2025-11-10,Yes,,2:5,Alif,,,,,2,45\nRP-G-581,\"Rp Main Class\",MIQDAD,\"Rp Member 901411\",2025-11-13,Yes,,,Hidden,Tawhid,Wudu,,,1,30\nRP-G-581,\"Rp Main Class\",MIQDAD,\"Rp Member 901411\",2025-11-17,Yes,,3,Alif,,,,,3,60\nRP-G-581,\"Rp Main Class\",MIQDAD,\"Rp Member 901411\",2025-11-24,Yes,,,,,,,,0,40\nRP-G-581,\"Rp Main Class\",MIQDAD,\"Rp Member 901411\",2025-11-27,No,\"'=Rp formula\",2:0,,,,,,,\n"

# 3. The coordinator asking for ladies is held to gents (the name says so)
GET {{base_url}}/reports/class-sessions/download-all?gender=2&level=ABUZAR
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
header "Content-Disposition" matches /Class_Sessions_Report_Gents_/
body contains "RP-G-581"
body contains "RP-G-582"

# 4. The ladies administrator: ladies, whatever they ask for
GET {{base_url}}/reports/class-sessions/download-all?gender=1
Authorization: {{auth_en_ladmin}}
HTTP 200
[Asserts]
header "Content-Disposition" matches /Class_Sessions_Report_Ladies_/
body contains "RP-L-583,\"Rp Ladies Class\",MIQDAD,\"Rp Member 901412\",2025-11-12,Yes,,,,,,,,1,20\n"
body not contains "RP-G-58"

# 5. The gents administrator and the super administrator: the other city's class is in, the closed class and the demo class never
GET {{base_url}}/reports/class-sessions/download-all?gender=2
Authorization: {{auth_en_gadmin}}
HTTP 200
[Asserts]
header "Content-Disposition" matches /Class_Sessions_Report_Gents_/
body contains "RP-G-584,"
body not contains "RP-G-585"
body not contains "RP-L-583"
body not contains "AYD1"

GET {{base_url}}/reports/class-sessions/download-all?gender=2
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
header "Content-Disposition" matches /Class_Sessions_Report_Ladies_/
body contains "RP-L-583,"
body not contains "RP-G-58"
