# GET /classes/{class_id}/mcq/standard contract: the standard MCQs a class may copy, grouped by topic then subject, with a copied flag. Runs against any implementation.
# Variables: base_url and auth_qm_<alias> (tools/assessment-contract.sh). Fixtures: db/synthetic/assessment-a2-fixtures.sql (read its header).
# Quirks copied (found by running PHP): groups come in the order of the standard MCQ code (A2S-1, A2S-2, ...), not alphabetically; a deactivated copy still counts as copied;
# questionCount is multiplied by the number of quizzes of the class made from it (A2S-2 has 1 question and 2 copies in class 9631: 2); a class no standard fits says languageId 1.

# 1. Without sign-in: 401
GET {{base_url}}/classes/9631/mcq/standard
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A missing or closed class is 404 before the permission check
GET {{base_url}}/classes/99999999/mcq/standard
Authorization: {{auth_qm_nobody}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/classes/9634/mcq/standard
Authorization: {{auth_qm_teacher}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 3. Refused: a plain student, the admin of another class, a removed admin, a member of no class, the teacher of another class, a gender admin, a coordinator
GET {{base_url}}/classes/9631/mcq/standard
Authorization: {{auth_qm_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

GET {{base_url}}/classes/9631/mcq/standard
Authorization: {{auth_qm_other_admin}}
HTTP 403

GET {{base_url}}/classes/9631/mcq/standard
Authorization: {{auth_qm_removed_admin}}
HTTP 403

GET {{base_url}}/classes/9631/mcq/standard
Authorization: {{auth_qm_nobody}}
HTTP 403

GET {{base_url}}/classes/9631/mcq/standard
Authorization: {{auth_qm_teacher2}}
HTTP 403

GET {{base_url}}/classes/9631/mcq/standard
Authorization: {{auth_qm_gents_admin}}
HTTP 403

GET {{base_url}}/classes/9631/mcq/standard
Authorization: {{auth_qm_coord}}
HTTP 403

# 4. The teacher: the standard MCQs of the class's level and language (A2S-4 and A2S-5 are not shown), grouped in first-seen order
GET {{base_url}}/classes/9631/mcq/standard
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.class.code" == "A2-G-631"
jsonpath "$.class.languageId" == 7
jsonpath "$.topics" count == 2
jsonpath "$.topics[0].topic" == "A2 Topic Beta"
jsonpath "$.topics[0].subjects" count == 2
jsonpath "$.topics[0].subjects[0].subject" == "A2 Subject Two"
jsonpath "$.topics[0].subjects[0].quizzes" count == 1
jsonpath "$.topics[0].subjects[0].quizzes[0].id" == 963701
jsonpath "$.topics[0].subjects[0].quizzes[0].code" == "A2S-1"
jsonpath "$.topics[0].subjects[0].quizzes[0].topic" == "A2 Topic Beta"
jsonpath "$.topics[0].subjects[0].quizzes[0].subject" == "A2 Subject Two"
jsonpath "$.topics[0].subjects[0].quizzes[0].lesson" == "A2 lesson 1"
jsonpath "$.topics[0].subjects[0].quizzes[0].name" == "A2 standard one"
jsonpath "$.topics[0].subjects[0].quizzes[0].questionCount" == 2
jsonpath "$.topics[0].subjects[0].quizzes[0].copied" == true
jsonpath "$.topics[0].subjects[1].subject" == "A2 Subject One"
jsonpath "$.topics[0].subjects[1].quizzes[0].code" == "A2S-2"
jsonpath "$.topics[0].subjects[1].quizzes[0].questionCount" == 2
jsonpath "$.topics[0].subjects[1].quizzes[0].copied" == true
jsonpath "$.topics[1].topic" == "A2 Topic Alpha"
jsonpath "$.topics[1].subjects[0].subject" == "A2 Subject One"
jsonpath "$.topics[1].subjects[0].quizzes[0].code" == "A2S-3"
jsonpath "$.topics[1].subjects[0].quizzes[0].questionCount" == 1
jsonpath "$.topics[1].subjects[0].quizzes[0].copied" == false

# 5. A class admin and a super admin read it too; the copied flag is per class
GET {{base_url}}/classes/9631/mcq/standard
Authorization: {{auth_qm_admin}}
HTTP 200
[Asserts]
jsonpath "$.topics" count == 2

GET {{base_url}}/classes/9632/mcq/standard
Authorization: {{auth_qm_super}}
HTTP 200
[Asserts]
jsonpath "$.topics[0].subjects[0].quizzes[0].copied" == false
jsonpath "$.topics[0].subjects[1].quizzes[0].copied" == false
jsonpath "$.topics[0].subjects[1].quizzes[0].questionCount" == 1

# 6. A class no standard MCQ fits (another level): no topics; the language is reported as 1
GET {{base_url}}/classes/9637/mcq/standard
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.class.code" == "A2-G-637"
jsonpath "$.class.languageId" == 1
jsonpath "$.topics" count == 0
