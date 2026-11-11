# PUT /classes/{class_id}/conduction/{session_id} contract: replace a record's fields and attendance within ten days of its making. Runs against any implementation.
# Variables: base_url and auth_<alias>. CONDUCTION fixtures: class 9475 (gents, teacher 900804 "cd_teacher4"; students 900831 and 900832; extra student "Put Extra") with sessions 947501 (2025-11-03, held, made 1 day ago;
# 900831 present with recitation 2, 900832 absent), 947502 (2025-11-04, not held, made 1 day ago), 947503 (2025-11-05, made 30 days ago); session 947401 belongs to class 9474 and 947101 to class 9471.

# 1. Without sign-in: 401. Unknown class: 404. A student, an outsider, another class's teacher, the ladies' admin: 403
PUT {{base_url}}/classes/9475/conduction/947501
{}
HTTP 401

PUT {{base_url}}/classes/999999/conduction/947501
Authorization: {{auth_cd_teacher4}}
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

PUT {{base_url}}/classes/9475/conduction/947501
Authorization: {{auth_cd_student}}
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage this class"

PUT {{base_url}}/classes/9475/conduction/947501
Authorization: {{auth_cd_outsider}}
{}
HTTP 403

PUT {{base_url}}/classes/9475/conduction/947501
Authorization: {{auth_cd_teacher}}
{}
HTTP 403

PUT {{base_url}}/classes/9475/conduction/947501
Authorization: {{auth_en_ladmin}}
{}
HTTP 403

# 2. A session that is not there, or is another class's, is 404 for the teacher of the class in the path
PUT {{base_url}}/classes/9475/conduction/999999999
Authorization: {{auth_cd_teacher4}}
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Session not found"

PUT {{base_url}}/classes/9475/conduction/947401
Authorization: {{auth_cd_teacher4}}
{}
HTTP 404

PUT {{base_url}}/classes/9475/conduction/947101
Authorization: {{auth_cd_teacher4}}
{"conductedOn": "2025-11-12", "conducted": false, "nonConductionReason": "Not this class"}
HTTP 404

GET {{base_url}}/classes/9471/conduction/947101
Authorization: {{auth_cd_teacher}}
HTTP 200
[Asserts]
jsonpath "$.session.conductedOn" == "2025-09-06"
jsonpath "$.session.nonConductionReason" == null

# 3. A record made more than ten days ago is not editable, for the teacher or an admin, and that is said before the body is read
PUT {{base_url}}/classes/9475/conduction/947503
Authorization: {{auth_cd_teacher4}}
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Session is not editable"

PUT {{base_url}}/classes/9475/conduction/947503
Authorization: {{auth_admin}}
{"conductedOn": "2025-11-12", "conducted": false, "nonConductionReason": "Too late"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Session is not editable"

# 4. The body: the same rules and words as POST, in the same order
PUT {{base_url}}/classes/9475/conduction/947501
Authorization: {{auth_cd_teacher4}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "conductedOn is required and must be a valid date"

PUT {{base_url}}/classes/9475/conduction/947501
Authorization: {{auth_cd_teacher4}}
{"conductedOn": "2025-11-10", "conducted": false}
HTTP 422
[Asserts]
jsonpath "$.detail" == "nonConductionReason is required when the class was not conducted"

PUT {{base_url}}/classes/9475/conduction/947501
Authorization: {{auth_cd_teacher4}}
{"conductedOn": "2025-11-10"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "duration is required for a conducted class"

PUT {{base_url}}/classes/9475/conduction/947501
Authorization: {{auth_cd_teacher4}}
{"conductedOn": "2025-11-10", "duration": 30, "students": [{"token": 900831, "present": false}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "At least one student must be marked present"

PUT {{base_url}}/classes/9475/conduction/947501
Authorization: {{auth_cd_teacher4}}
{"conductedOn": "2025-11-10", "duration": 30, "students": [{"token": 900831, "present": true}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "At least one subject must be selected"

PUT {{base_url}}/classes/9475/conduction/947501
Authorization: {{auth_cd_teacher4}}
{"conductedOn": "2025-11-10", "duration": 30, "students": [{"token": 900831, "present": true}], "otherConducted": true}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Topic covered is required for Other"

# 5. Another session on the new day is 409; the record's own day is fine
PUT {{base_url}}/classes/9475/conduction/947501
Authorization: {{auth_cd_teacher4}}
{"conductedOn": "2025-11-04", "duration": 30, "students": [{"token": 900831, "present": true}], "aqaedConducted": true, "aqaedTopic": "T"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "Another session already exists for this date"

PUT {{base_url}}/classes/9475/conduction/947501
Authorization: {{auth_cd_teacher4}}
{"conductedOn": "2025-11-05", "duration": 30, "students": [{"token": 900831, "present": true}], "aqaedConducted": true, "aqaedTopic": "T"}
HTTP 409

# 6. Nothing was written by the refusals
GET {{base_url}}/classes/9475/conduction/947501
Authorization: {{auth_cd_teacher4}}
HTTP 200
[Asserts]
jsonpath "$.session.conductedOn" == "2025-11-03"
jsonpath "$.session.duration" == 40
jsonpath "$.attendance" count == 2
jsonpath "$.attendance[0].recitation" == 2

# 7. The edit: a new day, new figures, a new subject; the old attendance is replaced whole (a stranger is dropped, an absent student's recitation forced to 0); the body cannot move the record or change its author
PUT {{base_url}}/classes/9475/conduction/947501
Authorization: {{auth_cd_teacher4}}
{
  "conductedOn": "2025-11-10",
  "duration": 55,
  "students": [
    {"token": 900831, "present": false, "recitation": 9},
    {"token": 900832, "present": true, "recitation": 4},
    {"token": 900811, "present": true, "recitation": 8}
  ],
  "extraStudents": [{"name": "Put Extra", "token": 1, "present": true}],
  "akhlaqConducted": true, "akhlaqTopic": " Adab ",
  "aqaedConducted": false, "aqaedTopic": "dropped",
  "quranRecitationSurah": 3,
  "classId": 9471, "class_id": 9471, "teacher": 900801, "createdBy": 900801, "id": 947103
}
HTTP 200
[Asserts]
jsonpath "$.id" == 947501
jsonpath "$.conductedOn" == "2025-11-10"
jsonpath "$.conducted" == true
jsonpath "$.duration" == 55
jsonpath "$.attendance" == 2
jsonpath "$.quranRecitationSurah" == 3
jsonpath "$.quranRecitationVerse" == null
jsonpath "$.aqaedConducted" == false
jsonpath "$.aqaedTopic" == null
jsonpath "$.akhlaqConducted" == true
jsonpath "$.akhlaqTopic" == "Adab"
jsonpath "$.editable" == true

GET {{base_url}}/classes/9475/conduction/947501
Authorization: {{auth_cd_teacher4}}
HTTP 200
[Asserts]
jsonpath "$.session.conductedOn" == "2025-11-10"
jsonpath "$.attendance" count == 3
jsonpath "$.attendance[0].token" == 900831
jsonpath "$.attendance[0].present" == false
jsonpath "$.attendance[0].recitation" == 0
jsonpath "$.attendance[1].token" == 900832
jsonpath "$.attendance[1].present" == true
jsonpath "$.attendance[1].recitation" == 4
jsonpath "$.attendance[2].token" == 1
jsonpath "$.attendance[2].name" == "Put Extra"
jsonpath "$.attendance[2].extra" == true

GET {{base_url}}/classes/9475/conduction
Authorization: {{auth_cd_teacher4}}
HTTP 200
[Asserts]
jsonpath "$.totalRecords" == 3
jsonpath "$.sessions[0].conductedOn" == "2025-11-10"

GET {{base_url}}/classes/9471/conduction
Authorization: {{auth_cd_teacher}}
HTTP 200
[Asserts]
jsonpath "$.totalRecords" == 3

GET {{base_url}}/classes/9475/conduction/check
Authorization: {{auth_cd_teacher4}}
[QueryStringParams]
date: 2025-11-03
HTTP 200
[Asserts]
jsonpath "$.alreadyConducted" == false

# 8. A super admin edits a record that did not meet, to one that did not meet for another reason, with no attendance
PUT {{base_url}}/classes/9475/conduction/947502
Authorization: {{auth_admin}}
{"conductedOn": "2025-11-04", "conducted": "0", "nonConductionReason": " Updated reason "}
HTTP 200
[Asserts]
jsonpath "$.conducted" == false
jsonpath "$.nonConductionReason" == "Updated reason"
jsonpath "$.attendance" == 0
jsonpath "$.duration" == null

GET {{base_url}}/classes/9475/conduction/947502
Authorization: {{auth_cd_teacher4}}
HTTP 200
[Asserts]
jsonpath "$.attendance" count == 0
