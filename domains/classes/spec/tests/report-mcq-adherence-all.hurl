# GET /reports/mcq-adherence/download-all?gender&classIds contract: every class in view with its standard MCQs, as one CSV. Runs against any implementation.
# Variables: base_url and auth_r2_<alias>. REPORTS2 fixtures (see report-mcq-adherence.hurl). "Published At" prints the copy's publish time as YYYY-MM-DD HH:MM:SS (the fixtures' time zone is UTC on both sides), empty for a copy not published and for a skipped MCQ.
# PHP quirks copied: classIds is only a filter over the scoped report (0, words, repeats and ids outside reach add nothing); nothing to send is a 404.

# 1. Sign-in, permission
GET {{base_url}}/reports/mcq-adherence/download-all
HTTP 401

GET {{base_url}}/reports/mcq-adherence/download-all
Authorization: {{auth_r2_nobody}}
HTTP 403

# 2. The ladies class, whole body (file name, header, order of the MCQs, the percent printed as PHP prints it)
GET {{base_url}}/reports/mcq-adherence/download-all?gender=2
Authorization: {{auth_r2_coord}}
HTTP 200
Content-Type: text/csv;charset=UTF-8
Content-Disposition: attachment; filename="MCQ_adherence.csv"
[Asserts]
body == "\"Class Code\",Level,Teacher,Location,Expected,Conducted,Pending,Skipped,\"Adherence %\",\"MCQ Code\",Topic,Subject,Lesson,\"MCQ Name\",Status,\"Published At\"\nR2-L-104,MIQDAD,\"R2 Member 921013\",\"R2 Hall\",3,2,1,0,66.7,R2-M2,\"R2 Topic\",\"R2 Subject A\",\"R2 lesson 2\",\"R2 MCQ two\",conducted,\"2019-05-02 10:00:00\"\nR2-L-104,MIQDAD,\"R2 Member 921013\",\"R2 Hall\",3,2,1,0,66.7,R2-M3,\"R2 Topic\",\"R2 Subject A\",\"R2 lesson 3\",\"R2 MCQ three\",pending,\nR2-L-104,MIQDAD,\"R2 Member 921013\",\"R2 Hall\",3,2,1,0,66.7,R2-M1,\"R2 Topic\",\"R2 Subject B\",\"R2 lesson 1\",\"R2 MCQ one\",conducted,\"2019-03-08 11:00:00\"\n"

# 3. The gents classes of the coordinator: worst first, the latest publish time of two published copies, a null teacher is empty; 98103 and 98105 never
GET {{base_url}}/reports/mcq-adherence/download-all
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
body contains "R2-G-107,ABUZAR,\"R2 Member 921011\",\"R2 Hall\",2,0,0,2,0,R2-A1,"
body contains "R2-G-101,MIQDAD,\"R2 Member 921011\",\"R2 Hall\",3,1,1,1,33.3,R2-M1,\"R2 Topic\",\"R2 Subject B\",\"R2 lesson 1\",\"R2 MCQ one\",conducted,\"2019-03-10 10:00:00\""
body contains "R2-G-101,MIQDAD,\"R2 Member 921011\",\"R2 Hall\",3,1,1,1,33.3,R2-M3,\"R2 Topic\",\"R2 Subject A\",\"R2 lesson 3\",\"R2 MCQ three\",skipped,\n"
body contains "R2-G-102,ABUZAR,\"R2 Member 921011\",\"R2 Hall\",2,1,1,0,50,R2-A2,"
body contains "R2-G-106,MIQDAD,,\"R2 Hall\",3,3,0,0,100,R2-M2,"
body not contains "R2-G-103"
body not contains "R2-G-105"
body not contains "R2-L-104"

# 4. classIds narrows; ids outside reach, 0, words and repeats add nothing; nothing left is a 404
GET {{base_url}}/reports/mcq-adherence/download-all?classIds=0,abc,98101,98101,98103
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
body contains "R2-G-101"
body not contains "R2-G-102"
body not contains "R2-G-103"

GET {{base_url}}/reports/mcq-adherence/download-all?classIds=98103
Authorization: {{auth_r2_coord}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "No MCQ adherence to download"

GET {{base_url}}/reports/mcq-adherence/download-all?classIds=98101
Authorization: {{auth_r2_one}}
HTTP 200

GET {{base_url}}/reports/mcq-adherence/download-all?classIds=98102
Authorization: {{auth_r2_one}}
HTTP 404
