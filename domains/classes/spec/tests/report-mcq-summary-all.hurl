# GET /reports/mcq-summary/download-all?gender&from&to&classIds contract: every class in view with its students, as one CSV. Runs against any implementation.
# Variables: base_url and auth_r2_<alias>. REPORTS2 fixtures (see report-mcq-summary.hurl), March 2019. The Score and Max columns of "R2 Topic A" for 98101 are NOT compared (PHP and the new API keep different spellings of the case-differing
# topic, so the header may carry an extra "r2 topic a" pair); the lines are matched by their first eleven cells. The CSV prints a student's NAME: every reports:read holder for the gender gets the names of every class in reach (finding 6).
# PHP quirks copied: classIds is only a filter over the scoped report (an id outside reach adds nothing; 0, words and repeats are dropped); a percent that is null is printed 0; nothing to send (no student left) is a 404.

# 1. Sign-in, permission, dates
GET {{base_url}}/reports/mcq-summary/download-all?from=2019-03-01&to=2019-03-31
HTTP 401

GET {{base_url}}/reports/mcq-summary/download-all?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_nobody}}
HTTP 403

GET {{base_url}}/reports/mcq-summary/download-all?from=2019-03-01
Authorization: {{auth_r2_coord}}
HTTP 422

# 2. The ladies class: header, rows, file name; topic columns in ordinal order, a student with no answers prints 0
GET {{base_url}}/reports/mcq-summary/download-all?from=2019-03-01&to=2019-03-31&classIds=98104&gender=2
Authorization: {{auth_r2_coord}}
HTTP 200
Content-Type: text/csv;charset=UTF-8
Content-Disposition: attachment; filename="MCQ_summary_2019-03-01_to_2019-03-31.csv"
[Asserts]
body == "\"Class Code\",Level,Teacher,Location,\"Student Name\",Attempted,\"Total MCQs\",Pending,Score,\"Max Score\",\"Score %\",\"R2 Topic A Score\",\"R2 Topic A Max\"\nR2-L-104,MIQDAD,\"R2 Member 921013\",\"R2 Hall\",\"R2 Member 921025\",1,1,0,23,40,57,23,40\nR2-L-104,MIQDAD,\"R2 Member 921013\",\"R2 Hall\",\"R2 Member 921029\",0,1,1,0,40,0,0,40\n"

# 3. The gents classes of the coordinator: only the classes in reach, one line per live student; 98103 (SALMAN) and the closed 98105 never
GET {{base_url}}/reports/mcq-summary/download-all?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
body contains "R2-G-101,MIQDAD,\"R2 Member 921011\",\"R2 Hall\",\"R2 Member 921021\",5,7,2,6,9,67,"
body contains "R2-G-101,MIQDAD,\"R2 Member 921011\",\"R2 Hall\",\"R2 Member 921034\",4,7,3,5,9,56,"
body contains "R2-G-101,MIQDAD,\"R2 Member 921011\",\"R2 Hall\",\"R2 Member 921032\",2,7,5,4,9,44,"
body contains "R2-G-101,MIQDAD,\"R2 Member 921011\",\"R2 Hall\",\"R2 Member 921023\",1,7,6,2,9,22,"
body contains "R2-G-101,MIQDAD,\"R2 Member 921011\",\"R2 Hall\",\"R2 Member 921033\",1,7,6,1,9,11,"
body contains "R2-G-101,MIQDAD,\"R2 Member 921011\",\"R2 Hall\",\"R2 Member 921028\",0,7,7,0,9,0,"
body not contains "R2-G-103"
body not contains "R2-G-105"
body not contains "R2-L-104"
body not contains "R2 Member 921024"
body not contains "R2 Member 921030"
body not contains "R2 Member 921035"
body not contains "R2 Member 921026"

GET {{base_url}}/reports/mcq-summary/download-all?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_one}}
HTTP 200
[Asserts]
body contains "R2 Member 921021"
body not contains "R2-L-104"

# 4. classIds narrows; ids outside reach, 0, words and repeats add nothing; a class with no live student sends nothing (404)
GET {{base_url}}/reports/mcq-summary/download-all?from=2019-03-01&to=2019-03-31&classIds=0,abc,98101,98101,98103
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
body contains "R2 Member 921021"
body not contains "R2-G-103"
body not contains "R2 Member 921026"

GET {{base_url}}/reports/mcq-summary/download-all?from=2019-03-01&to=2019-03-31&classIds=98107
Authorization: {{auth_r2_coord}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "No MCQ summary to download"

GET {{base_url}}/reports/mcq-summary/download-all?from=2019-03-01&to=2019-03-31&classIds=98103
Authorization: {{auth_r2_coord}}
HTTP 404

GET {{base_url}}/reports/mcq-summary/download-all?from=2019-04-01&to=2019-04-30
Authorization: {{auth_r2_coord}}
HTTP 404
