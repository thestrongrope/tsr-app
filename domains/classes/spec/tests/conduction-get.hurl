# GET /classes/{class_id}/conduction/{session_id} contract: one record for editing, with its attendance rows. Runs against any implementation.
# Variables: base_url and auth_<alias>. CONDUCTION fixtures: class 9471 (teacher 900801) with sessions 947101 (made 30 days ago), 947102 (not held) and 947103 (made 2 days ago by 900802: attendance for 900811 present with
# recitation 5, 900812 absent, the extra student "Extra One", and 900813 who has left); class 9474 holds session 947401; class 9472 is another gents class (teacher 900802).

# 1. Without sign-in: 401. Unknown class: 404. A student, an outsider, another class's teacher, the ladies' admin: 403
GET {{base_url}}/classes/9471/conduction/947103
HTTP 401

GET {{base_url}}/classes/999999/conduction/947103
Authorization: {{auth_cd_teacher}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/classes/9471/conduction/947103
Authorization: {{auth_cd_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage this class"

GET {{base_url}}/classes/9471/conduction/947103
Authorization: {{auth_cd_outsider}}
HTTP 403

GET {{base_url}}/classes/9471/conduction/947103
Authorization: {{auth_cd_teacher2}}
HTTP 403

GET {{base_url}}/classes/9471/conduction/947103
Authorization: {{auth_en_ladmin}}
HTTP 403

# 2. A session that is not there, or is another class's, is 404 for the teacher of the class in the path
GET {{base_url}}/classes/9471/conduction/999999999
Authorization: {{auth_cd_teacher}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Session not found"

GET {{base_url}}/classes/9471/conduction/abc
Authorization: {{auth_cd_teacher}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Session not found"

GET {{base_url}}/classes/9471/conduction/947401
Authorization: {{auth_cd_teacher}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Session not found"

GET {{base_url}}/classes/9472/conduction/947103
Authorization: {{auth_cd_teacher2}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Session not found"

# 3. The teacher reads a held session: the session, every stored attendance row with the member's name (a member who left included), the extra student by its stored name
GET {{base_url}}/classes/9471/conduction/947103
Authorization: {{auth_cd_teacher}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.class.id" == 9471
jsonpath "$.class.students" count == 2
jsonpath "$.class.extraStudents" count == 2
jsonpath "$.session.id" == 947103
jsonpath "$.session.conductedOn" == "2025-09-20"
jsonpath "$.session.conducted" == true
jsonpath "$.session.duration" == 30
jsonpath "$.session.attendance" == 3
jsonpath "$.session.quranRecitationSurah" == null
jsonpath "$.session.aqaedConducted" == true
jsonpath "$.session.ahkamConducted" == true
jsonpath "$.session.arabicConducted" == false
jsonpath "$.session.ahkamTopic" == "Ahkam Newest"
jsonpath "$.session.nonConductionReason" == null
jsonpath "$.session.editable" == true
jsonpath "$.attendance" count == 4
jsonpath "$.attendance[0].token" == 900811
jsonpath "$.attendance[0].name" == "Cd Member 900811"
jsonpath "$.attendance[0].present" == true
jsonpath "$.attendance[0].recitation" == 5
jsonpath "$.attendance[0].extra" == false
jsonpath "$.attendance[1].token" == 900812
jsonpath "$.attendance[1].present" == false
jsonpath "$.attendance[2].token" == 1
jsonpath "$.attendance[2].name" == "Extra One"
jsonpath "$.attendance[2].present" == true
jsonpath "$.attendance[2].extra" == true
jsonpath "$.attendance[3].token" == 900813
jsonpath "$.attendance[3].name" == "Cd Member 900813"
jsonpath "$.attendance[3].recitation" == 2
jsonpath "$.holyQuran" isCollection

# 4. An old record (30 days) is readable but not editable; a not-held one has no attendance
GET {{base_url}}/classes/9471/conduction/947101
Authorization: {{auth_cd_teacher}}
HTTP 200
[Asserts]
jsonpath "$.session.editable" == false
jsonpath "$.session.quranRecitationSurah" == 2
jsonpath "$.session.quranRecitationVerse" == 5
jsonpath "$.session.arabicTopic" == "Arabic Seed"
jsonpath "$.attendance" count == 2

GET {{base_url}}/classes/9471/conduction/947102
Authorization: {{auth_cd_teacher}}
HTTP 200
[Asserts]
jsonpath "$.session.conducted" == false
jsonpath "$.session.nonConductionReason" == "Seed unwell"
jsonpath "$.session.duration" == null
jsonpath "$.attendance" count == 0

# 5. A super admin and the gents' admin may read it
GET {{base_url}}/classes/9471/conduction/947103
Authorization: {{auth_admin}}
HTTP 200

GET {{base_url}}/classes/9471/conduction/947103
Authorization: {{auth_en_gadmin}}
HTTP 200
