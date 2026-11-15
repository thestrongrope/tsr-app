# POST /classes/{class_id}/conduction contract: record a class session; a repeat of the same request answers the record it made. Runs against any implementation.
# Variables: base_url and auth_<alias>. CONDUCTION fixtures: class 9472 (gents, teacher 900802 "cd_teacher2"; students 900821 "cd_student2" and 900822 active, 900823 removed; extra students "Seed Extra" (token 1) and "Second Extra";
# no session at the start); other members: 900811 (a student of class 9471), 900825 (a ladies member), 900826 (in no class); "admin" is a super admin; the ladies class 9473.

# 1. Without sign-in: 401. Unknown or closed class: 404. A student, an outsider, another class's teacher, the ladies' admin: 403 (before the body is read)
POST {{base_url}}/classes/9472/conduction
{}
HTTP 401

POST {{base_url}}/classes/999999/conduction
Authorization: {{auth_cd_teacher2}}
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

POST {{base_url}}/classes/9303/conduction
Authorization: {{auth_admin}}
{}
HTTP 404

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_student2}}
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage this class"

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_outsider}}
{}
HTTP 403

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher}}
{}
HTTP 403

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_en_ladmin}}
{}
HTTP 403

# 2. The body, in PHP's order of checks
POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "conductedOn is required and must be a valid date"

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "not a date"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "conductedOn is required and must be a valid date"

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2025-11-17", "conducted": false}
HTTP 422
[Asserts]
jsonpath "$.detail" == "nonConductionReason is required when the class was not conducted"

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2025-11-17", "conducted": "no", "nonConductionReason": "   "}
HTTP 422
[Asserts]
jsonpath "$.detail" == "nonConductionReason is required when the class was not conducted"

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2025-11-17"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "duration is required for a conducted class"

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2025-11-17", "duration": 0, "students": [{"token": 900821, "present": true}], "aqaedConducted": true, "aqaedTopic": "T"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "duration is required for a conducted class"

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2025-11-17", "duration": 30, "students": [{"token": 900821, "present": false}], "extraStudents": [{"name": "  ", "present": true}], "aqaedConducted": true, "aqaedTopic": "T"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "At least one student must be marked present"

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2025-11-17", "duration": 30, "students": [{"token": 900821, "present": true}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "At least one subject must be selected"

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2025-11-17", "duration": 30, "students": [{"token": 900821, "present": true}], "arabicConducted": true, "arabicTopic": " "}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Topic covered is required for Arabic"

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2025-11-17", "duration": 30, "students": [{"token": 900821, "present": true}], "aqaedConducted": true, "aqaedTopic": "T", "ahkamConducted": true}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Topic covered is required for Ahkam"

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2025-11-17", "duration": 30, "students": [{"token": 900821, "present": true}], "akhlaqConducted": true}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Topic covered is required for Akhlaq"

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2025-11-17", "duration": 30, "students": [{"token": 900821, "present": true}], "otherConducted": true}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Topic covered is required for Other"

# 3. Nothing was written by the refusals
GET {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
HTTP 200
[Asserts]
jsonpath "$.totalRecords" == 0

# 4. A held class: topics trimmed, a topic of an unselected subject dropped, a surah. Attendance: the roster students (a member who left too) in order, absent forced to recitation 0, strangers dropped
#    (a student of another class, a ladies member, a member of no class), a blank extra skipped
POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{
  "conductedOn": "2025-11-17",
  "duration": 45,
  "students": [
    {"token": 900821, "present": true, "recitation": 7},
    {"token": 900822, "present": false, "recitation": 9},
    {"token": 900811, "present": true, "recitation": 4},
    {"token": 900825, "present": true, "recitation": 4},
    {"token": 900826, "present": true},
    {"token": 900823, "present": "yes", "recitation": 1}
  ],
  "extraStudents": [
    {"name": "Seed Extra", "token": 1, "present": true},
    {"name": "  ", "token": 2, "present": true},
    {"name": "New Extra", "token": 3, "present": false}
  ],
  "aqaedConducted": true, "aqaedTopic": "  Wudu  ",
  "ahkamConducted": "true", "ahkamTopic": "Ghusl",
  "arabicConducted": false, "arabicTopic": "dropped",
  "quranRecitationSurah": 2, "quranRecitationVerse": 7
}
HTTP 201
[Captures]
held_id: jsonpath "$.id"
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.id" isInteger
jsonpath "$.conductedOn" == "2025-11-17"
jsonpath "$.conducted" == true
jsonpath "$.duration" == 45
jsonpath "$.attendance" == 3
jsonpath "$.quranRecitationSurah" == 2
jsonpath "$.quranRecitationVerse" == 7
jsonpath "$.aqaedConducted" == true
jsonpath "$.aqaedTopic" == "Wudu"
jsonpath "$.ahkamConducted" == true
jsonpath "$.ahkamTopic" == "Ghusl"
jsonpath "$.arabicConducted" == false
jsonpath "$.arabicTopic" == null
jsonpath "$.akhlaqConducted" == false
jsonpath "$.otherConducted" == false
jsonpath "$.nonConductionReason" == null
jsonpath "$.editable" == true

# 5. The record, its attendance and the screens that read it
GET {{base_url}}/classes/9472/conduction/{{held_id}}
Authorization: {{auth_cd_teacher2}}
HTTP 200
[Asserts]
jsonpath "$.session.id" == {{held_id}}
jsonpath "$.session.attendance" == 3
jsonpath "$.attendance" count == 5
jsonpath "$.attendance[0].token" == 900821
jsonpath "$.attendance[0].name" == "Cd Member 900821"
jsonpath "$.attendance[0].present" == true
jsonpath "$.attendance[0].recitation" == 7
jsonpath "$.attendance[0].extra" == false
jsonpath "$.attendance[1].token" == 900822
jsonpath "$.attendance[1].present" == false
jsonpath "$.attendance[1].recitation" == 0
jsonpath "$.attendance[2].token" == 900823
jsonpath "$.attendance[2].name" == "Cd Member 900823"
jsonpath "$.attendance[2].present" == true
jsonpath "$.attendance[2].recitation" == 1
jsonpath "$.attendance[3].token" == 1
jsonpath "$.attendance[3].name" == "Seed Extra"
jsonpath "$.attendance[3].present" == true
jsonpath "$.attendance[3].extra" == true
jsonpath "$.attendance[4].token" == 3
jsonpath "$.attendance[4].name" == "New Extra"
jsonpath "$.attendance[4].present" == false
jsonpath "$.attendance[4].extra" == true

GET {{base_url}}/classes/9472/sessions
Authorization: {{auth_cd_student2}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].id" == {{held_id}}
jsonpath "$[0].conductedOn" == "2025-11-17"
jsonpath "$[0].attendance" == 3
jsonpath "$[0].aqaedConducted" == true
jsonpath "$[0].ahkamConducted" == true
jsonpath "$[0].aqaedTopic" == "Wudu"

GET {{base_url}}/classes/9472/my-attendance
Authorization: {{auth_cd_student2}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].sessionId" == {{held_id}}
jsonpath "$[0].present" == true
jsonpath "$[0].recitation" == 7

GET {{base_url}}/classes/9472/conduction/check
Authorization: {{auth_cd_teacher2}}
[QueryStringParams]
date: 2025-11-17
HTTP 200
[Asserts]
jsonpath "$.alreadyConducted" == true
jsonpath "$.sameWeek" == true

# (class 9472 has no schedule, so PHP's parity stack prints warnings before this JSON: the body is matched as text)
GET {{base_url}}/classes/9472/conduction/new
Authorization: {{auth_cd_teacher2}}
HTTP 200
[Asserts]
body contains "\"lastSessionDate\":\"2025-11-17\""
body contains "\"aqaedTopic\":\"Wudu\""
body contains "\"ahkamTopic\":\"Ghusl\""
body contains "\"arabicTopic\":null"
body contains "\"latestSurah\":2"

# 6. The same day again is refused, whoever asks
POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2025-11-17", "duration": 30, "students": [{"token": 900821, "present": true}], "aqaedConducted": true, "aqaedTopic": "T"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "A conduction record already exists for this date"

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_admin}}
{"conductedOn": "17-11-2025", "conducted": false, "nonConductionReason": "Other spelling of the day"}
HTTP 409

# 7. A class that did not meet: the reason is stored, the flags and topics are not, the present students still count. A super admin may record
POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_admin}}
{"conductedOn": "2025-11-18", "conducted": "false", "nonConductionReason": "  Rain  ", "students": [{"token": 900821, "present": true, "recitation": 3}], "aqaedConducted": true, "aqaedTopic": "dropped"}
HTTP 201
[Captures]
missed_id: jsonpath "$.id"
[Asserts]
jsonpath "$.conducted" == false
jsonpath "$.nonConductionReason" == "Rain"
jsonpath "$.duration" == null
jsonpath "$.attendance" == 1
jsonpath "$.aqaedConducted" == false
jsonpath "$.aqaedTopic" == null
jsonpath "$.editable" == true

GET {{base_url}}/classes/9472/conduction/{{missed_id}}
Authorization: {{auth_cd_teacher2}}
HTTP 200
[Asserts]
jsonpath "$.attendance" count == 1
jsonpath "$.attendance[0].recitation" == 3

# 8. A repeat of one request (the app sent it twice): the record it made, with 200; another time or another caller is a second record, refused
POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2025-11-19", "recordedAt": "2020-01-06T10:00:00Z", "duration": 20, "students": [{"token": 900822, "present": true}], "otherConducted": true, "otherTopic": "Replay"}
HTTP 201
[Captures]
replay_id: jsonpath "$.id"
[Asserts]
jsonpath "$.editable" == false
jsonpath "$.otherTopic" == "Replay"

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2025-11-19", "recordedAt": "2020-01-06T10:00:00Z", "duration": 20, "students": [{"token": 900822, "present": true}], "otherConducted": true, "otherTopic": "Replay"}
HTTP 200
[Asserts]
jsonpath "$.id" == {{replay_id}}

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2025-11-19", "recordedAt": "2020-01-06T10:00:01Z", "duration": 20, "students": [{"token": 900822, "present": true}], "otherConducted": true, "otherTopic": "Replay"}
HTTP 409

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_admin}}
{"conductedOn": "2025-11-19", "recordedAt": "2020-01-06T10:00:00Z", "duration": 20, "students": [{"token": 900822, "present": true}], "otherConducted": true, "otherTopic": "Replay"}
HTTP 409

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2025-11-19", "duration": 20, "students": [{"token": 900822, "present": true}], "otherConducted": true, "otherTopic": "Replay"}
HTTP 409

GET {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
HTTP 200
[Asserts]
jsonpath "$.totalRecords" == 3
jsonpath "$.sessions[0].conductedOn" == "2025-11-19"
jsonpath "$.sessions[0].editable" == false

# 9. A recorded time that cannot be read is ignored; one in the future is taken as now (so the record is editable)
POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2025-11-20", "recordedAt": "garbage", "duration": 20, "students": [{"token": 900822, "present": true}], "otherConducted": true, "otherTopic": "T"}
HTTP 201
[Asserts]
jsonpath "$.editable" == true

POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2025-11-21", "recordedAt": "2099-01-01T00:00:00Z", "duration": 20, "students": [{"token": 900822, "present": true}], "otherConducted": true, "otherTopic": "T"}
HTTP 201
[Asserts]
jsonpath "$.editable" == true

# 10. No mass assignment: the class, teacher and author come from the path and the caller, whatever the body says; the record is the class's own
POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2025-11-22", "duration": 20, "students": [{"token": 900822, "present": true}], "otherConducted": true, "otherTopic": "T", "classId": 9471, "class_id": 9471, "teacher": 900801, "createdBy": 900801, "created_by": 900801, "id": 947103}
HTTP 201
[Captures]
mass_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" != 947103

GET {{base_url}}/classes/9472/conduction/{{mass_id}}
Authorization: {{auth_cd_teacher2}}
HTTP 200

GET {{base_url}}/classes/9471/conduction/{{mass_id}}
Authorization: {{auth_cd_teacher}}
HTTP 404

GET {{base_url}}/classes/9471/conduction
Authorization: {{auth_cd_teacher}}
HTTP 200
[Asserts]
jsonpath "$.totalRecords" == 3

# 11. A date far ahead is accepted (PHP has no future-date rule)
POST {{base_url}}/classes/9472/conduction
Authorization: {{auth_cd_teacher2}}
{"conductedOn": "2099-12-31", "conducted": false, "nonConductionReason": "Far ahead"}
HTTP 201
[Asserts]
jsonpath "$.conductedOn" == "2099-12-31"
