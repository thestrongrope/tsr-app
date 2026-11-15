# GET /classes/{class_id}/conduction contract: a class's conduction records for the teacher's screen, newest day first, with the class header and roster. Runs against any implementation.
# Variables: base_url and auth_<alias>. CONDUCTION fixtures (reset by tools/classes-contract.sh): class 9471 (gents, MIQDAD, teacher 900801 "cd_teacher"; students 900811 "cd_student" and 900812, 900813 removed; extra students
# "Extra One" and "Extra Two"; sessions 2025-09-20 (made 2 days ago, by 900802, flags '1' and 'Y'), 2025-09-13 (not held), 2025-09-06 (made 30 days ago, surah 2:5)); 9472 is another gents class (teacher 900802).

# 1. Without sign-in: 401
GET {{base_url}}/classes/9471/conduction
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Unknown or closed class: 404 before the permission check
GET {{base_url}}/classes/999999/conduction
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/classes/9303/conduction
Authorization: {{auth_admin}}
HTTP 404

# 3. A student, an outsider, another class's teacher and the ladies' admin: 403
GET {{base_url}}/classes/9471/conduction
Authorization: {{auth_cd_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage this class"

GET {{base_url}}/classes/9471/conduction
Authorization: {{auth_cd_outsider}}
HTTP 403

GET {{base_url}}/classes/9471/conduction
Authorization: {{auth_cd_teacher2}}
HTTP 403

GET {{base_url}}/classes/9471/conduction
Authorization: {{auth_en_ladmin}}
HTTP 403

# 4. The teacher: the header, the roster and three sessions, newest first
GET {{base_url}}/classes/9471/conduction
Authorization: {{auth_cd_teacher}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.class.id" == 9471
jsonpath "$.class.code" == "CD-G-071"
jsonpath "$.class.name" == "Cd Read Class"
jsonpath "$.class.level" == 3
jsonpath "$.class.levelName" == "MIQDAD"
jsonpath "$.class.gender" == 1
jsonpath "$.class.status" == "A"
jsonpath "$.class.teacherName" == "Cd Member 900801"
jsonpath "$.class.students" count == 2
jsonpath "$.class.students[0].token" == 900811
jsonpath "$.class.students[0].name" == "Cd Member 900811"
jsonpath "$.class.students[0].present" == false
jsonpath "$.class.students[0].recitation" == 0
jsonpath "$.class.students[0].extra" == false
jsonpath "$.class.students[1].token" == 900812
jsonpath "$.class.extraStudents" count == 2
jsonpath "$.class.extraStudents[0].token" == 1
jsonpath "$.class.extraStudents[0].name" == "Extra One"
jsonpath "$.class.extraStudents[0].extra" == true
jsonpath "$.class.extraStudents[1].token" == 2
jsonpath "$.class.extraStudents[1].name" == "Extra Two"
jsonpath "$.class.totalStudents" == 4
jsonpath "$.totalRecords" == 3
jsonpath "$.page" == 1
jsonpath "$.sessions" count == 3
jsonpath "$.sessions[0].conductedOn" == "2025-09-20"
jsonpath "$.sessions[0].conducted" == true
jsonpath "$.sessions[0].duration" == 30
jsonpath "$.sessions[0].attendance" == 3
jsonpath "$.sessions[0].quranRecitationSurah" == null
jsonpath "$.sessions[0].quranRecitationVerse" == null
jsonpath "$.sessions[0].arabicConducted" == false
jsonpath "$.sessions[0].aqaedConducted" == true
jsonpath "$.sessions[0].ahkamConducted" == true
jsonpath "$.sessions[0].akhlaqConducted" == false
jsonpath "$.sessions[0].otherConducted" == false
jsonpath "$.sessions[0].arabicTopic" == null
jsonpath "$.sessions[0].ahkamTopic" == "Ahkam Newest"
jsonpath "$.sessions[0].nonConductionReason" == null
jsonpath "$.sessions[0].editable" == true
jsonpath "$.sessions[1].conductedOn" == "2025-09-13"
jsonpath "$.sessions[1].conducted" == false
jsonpath "$.sessions[1].duration" == null
jsonpath "$.sessions[1].attendance" == null
jsonpath "$.sessions[1].nonConductionReason" == "Seed unwell"
jsonpath "$.sessions[1].editable" == true
jsonpath "$.sessions[2].conductedOn" == "2025-09-06"
jsonpath "$.sessions[2].duration" == 45
jsonpath "$.sessions[2].quranRecitationSurah" == 2
jsonpath "$.sessions[2].quranRecitationVerse" == 5
jsonpath "$.sessions[2].arabicConducted" == true
jsonpath "$.sessions[2].aqaedConducted" == true
jsonpath "$.sessions[2].arabicTopic" == "Arabic Seed"
jsonpath "$.sessions[2].aqaedTopic" == "Aqaed Old"
jsonpath "$.sessions[2].editable" == false
body matches /"totalPages":1\.0[,}]/

# 5. Others who may record for the class: the gents' admin and a super admin
GET {{base_url}}/classes/9471/conduction
Authorization: {{auth_en_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.totalRecords" == 3

GET {{base_url}}/classes/9471/conduction
Authorization: {{auth_admin}}
HTTP 200

# 6. Paging: pageSize and page are clamped; totalPages is a float
GET {{base_url}}/classes/9471/conduction?pageSize=2&page=2
Authorization: {{auth_cd_teacher}}
HTTP 200
[Asserts]
jsonpath "$.sessions" count == 1
jsonpath "$.sessions[0].conductedOn" == "2025-09-06"
jsonpath "$.page" == 2
jsonpath "$.totalRecords" == 3
body matches /"totalPages":2\.0[,}]/

GET {{base_url}}/classes/9471/conduction?pageSize=0&page=0
Authorization: {{auth_cd_teacher}}
HTTP 200
[Asserts]
jsonpath "$.sessions" count == 1
jsonpath "$.page" == 1
body matches /"totalPages":3\.0[,}]/

GET {{base_url}}/classes/9471/conduction?pageSize=1000&page=abc
Authorization: {{auth_cd_teacher}}
HTTP 200
[Asserts]
jsonpath "$.sessions" count == 3
jsonpath "$.page" == 1

# 7. A class with no session: an empty list and zero pages
GET {{base_url}}/classes/9476/conduction
Authorization: {{auth_cd_teacher}}
HTTP 200
[Asserts]
jsonpath "$.sessions" count == 0
jsonpath "$.totalRecords" == 0
jsonpath "$.class.students" count == 0
jsonpath "$.class.totalStudents" == 0
body matches /"totalPages":0\.0[,}]/

# 8. The sessions list a student reads shows the same flags: '1' and 'Y' both mean held
GET {{base_url}}/classes/9471/sessions
Authorization: {{auth_cd_student}}
HTTP 200
[Asserts]
jsonpath "$[0].aqaedConducted" == true
jsonpath "$[0].ahkamConducted" == true
jsonpath "$[0].arabicConducted" == false
jsonpath "$[2].arabicConducted" == true
jsonpath "$[2].aqaedConducted" == true
