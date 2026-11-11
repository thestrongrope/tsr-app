# GET /reports/conduction/download-all contract: every week's raw rows of the summary window as CSV (level ignored), 404 when there is none. Runs against any implementation.
# Variables: base_url and auth_<alias>. B5A fixtures (see report-conduction.hurl): the coordinator rp_coord reaches 9581 and 9582 only. A class that held two sessions in a week has two rows, in no fixed order, so
# those rows are asserted one by one.

# 1. Without sign-in: 401; without reports:read: 403
GET {{base_url}}/reports/conduction/download-all?year=2025&week=45
HTTP 401

GET {{base_url}}/reports/conduction/download-all?year=2025&week=45
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. The file: headers, the columns of PHP's raw rows, cells with a space in quotes, empty cells for nothing
GET {{base_url}}/reports/conduction/download-all?year=2025&week=45
Authorization: {{auth_rp_coord}}
HTTP 200
Content-Type: text/csv;charset=UTF-8
[Asserts]
header "Content-Disposition" matches /^attachment; filename="Class_Report_All_\d{8}_\d{6}\.csv"$/
body startsWith "Id,Level,Gender,Class,Teacher,\"Started On\",Year,Week,From,To,Conducted,\"Conducted On\",\"Reason for Non-Conduction\",Duration,Attendance,Registered,Extra,\"%age Conduction\",\"Aqaed Topic\"\n9582,ABUZAR,Gents,RP-G-582,\"Rp Member 901413\",\"2025-01-06 00:00:00\",2025,43,2025-10-26,2025-11-01,\"Not Filled\",,,,,1,,,\n"
body contains "9582,ABUZAR,Gents,RP-G-582,\"Rp Member 901413\",\"2025-01-06 00:00:00\",2025,45,2025-11-09,2025-11-15,Yes,2025-11-11,,50,1,1,,,\"Aqaed Two\"\n"
body contains "9581,MIQDAD,Gents,RP-G-581,\"Rp Member 901411\",\"2025-01-06 00:00:00\",2025,44,2025-11-02,2025-11-08,No,2025-11-03,\"Rp rain\",,,2,1,,\n"
body contains "9581,MIQDAD,Gents,RP-G-581,\"Rp Member 901411\",\"2025-01-06 00:00:00\",2025,45,2025-11-09,2025-11-15,Yes,2025-11-10,,45,2,2,1,0.6667,\n"
body contains "9581,MIQDAD,Gents,RP-G-581,\"Rp Member 901411\",\"2025-01-06 00:00:00\",2025,45,2025-11-09,2025-11-15,Yes,2025-11-13,,30,1,2,1,0.3333,Tawhid\n"
body contains "9581,MIQDAD,Gents,RP-G-581,\"Rp Member 901411\",\"2025-01-06 00:00:00\",2025,46,2025-11-16,2025-11-22,Yes,2025-11-17,,60,3,2,1,1.0000,\n"
body contains "9581,MIQDAD,Gents,RP-G-581,\"Rp Member 901411\",\"2025-01-06 00:00:00\",2025,47,2025-11-23,2025-11-29,Yes,2025-11-24,,40,0,2,1,0.0000,\n"
body contains "9581,MIQDAD,Gents,RP-G-581,\"Rp Member 901411\",\"2025-01-06 00:00:00\",2025,47,2025-11-23,2025-11-29,No,2025-11-27,\"'=Rp formula\",,,2,1,,\n"
body contains "9581,MIQDAD,Gents,RP-G-581,\"Rp Member 901411\",\"2025-01-06 00:00:00\",2025,48,2025-11-30,2025-12-06,\"Not Filled\",,,,,2,1,,\n"

# 3. The level is not read; the coordinator's gender is its own whatever it asks for
GET {{base_url}}/reports/conduction/download-all?year=2025&week=45&level=ABUZAR&gender=2
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
body contains "RP-G-581"
body contains "RP-G-582"
body not contains "RP-L-583"

# 4. The ladies administrator gets ladies
GET {{base_url}}/reports/conduction/download-all?year=2025&week=45
Authorization: {{auth_en_ladmin}}
HTTP 200
[Asserts]
body contains "RP-L-583"
body not contains "RP-G-58"

# 5. Year and week out of range: 422
GET {{base_url}}/reports/conduction/download-all?year=2025&week=60
Authorization: {{auth_rp_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid year or week"

# 6. Nothing to send: 404 (week 1 of 2021 has no class: the classes began in 2025)
GET {{base_url}}/reports/conduction/download-all?year=2021&week=1
Authorization: {{auth_rp_coord}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "No data to download"
