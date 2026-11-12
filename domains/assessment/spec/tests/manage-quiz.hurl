# GET /mcq/manage/{quiz_id} contract: a quiz and its questions WITH the answer, for its teacher or class admin. Runs against any implementation.
# Variables: base_url and auth_qm_<alias> (tools/assessment-contract.sh). Fixtures: db/synthetic/assessment-a2-fixtures.sql (read its header).

# 1. Without sign-in: 401
GET {{base_url}}/mcq/manage/963401
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A missing quiz is 404 before any permission check; a non-number or a huge id is a quiz that does not exist; a quiz of a closed class is a class 404
GET {{base_url}}/mcq/manage/99999999
Authorization: {{auth_qm_nobody}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

GET {{base_url}}/mcq/manage/abc
Authorization: {{auth_qm_teacher}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

GET {{base_url}}/mcq/manage/99999999999999999999
Authorization: {{auth_qm_teacher}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

GET {{base_url}}/mcq/manage/963441
Authorization: {{auth_qm_teacher}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 3. Refused (the answers are in this reply): a plain student, the admin of another class, a removed admin, a member of no class, the teacher of another class,
#    a class admin of a different class of the same teacher, a gender admin and a coordinator
GET {{base_url}}/mcq/manage/963401
Authorization: {{auth_qm_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"
jsonpath "$.questions" not exists

GET {{base_url}}/mcq/manage/963401
Authorization: {{auth_qm_other_admin}}
HTTP 403

GET {{base_url}}/mcq/manage/963401
Authorization: {{auth_qm_removed_admin}}
HTTP 403

GET {{base_url}}/mcq/manage/963401
Authorization: {{auth_qm_nobody}}
HTTP 403

GET {{base_url}}/mcq/manage/963401
Authorization: {{auth_qm_teacher2}}
HTTP 403

GET {{base_url}}/mcq/manage/963401
Authorization: {{auth_qm_admin2}}
HTTP 403

GET {{base_url}}/mcq/manage/963401
Authorization: {{auth_qm_gents_admin}}
HTTP 403

GET {{base_url}}/mcq/manage/963401
Authorization: {{auth_qm_coord}}
HTTP 403

# 4. The class teacher: a draft with five options, an Arabic question and an empty option (null); the answer is option1 under the name answer
GET {{base_url}}/mcq/manage/963401
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.id" == 963401
jsonpath "$.code" == "A2Q963401"
jsonpath "$.name" == "A2 Quiz Draft"
jsonpath "$.topic" == "A2 topic one"
jsonpath "$.classId" == 9631
jsonpath "$.classCode" == "A2-G-631"
jsonpath "$.className" == "A2 Class Main"
jsonpath "$.restrictToClass" == 1
jsonpath "$.publishedAt" == null
jsonpath "$.deactivatedAt" == null
jsonpath "$.link" == null
jsonpath "$.questions" count == 3
jsonpath "$.questions[0].id" == 963501
jsonpath "$.questions[0].question" == "A2 draft q1"
jsonpath "$.questions[0].answer" == "Right a"
jsonpath "$.questions[0].option2" == "Wrong b"
jsonpath "$.questions[0].option3" == "Wrong c"
jsonpath "$.questions[0].option4" == "Wrong d"
jsonpath "$.questions[0].option5" == "Wrong e"
jsonpath "$.questions[0].option1" not exists
jsonpath "$.questions[1].question" == "ما هو؟"
jsonpath "$.questions[1].answer" == "نعم"
jsonpath "$.questions[1].option3" == null
jsonpath "$.questions[2].option3" == null

# 5. A class admin student and a super admin read it too; a published quiz has a link and its dates
GET {{base_url}}/mcq/manage/963402
Authorization: {{auth_qm_admin}}
HTTP 200
[Asserts]
jsonpath "$.restrictToClass" == 0
jsonpath "$.publishedAt" == "2026-01-10T10:00:00"
jsonpath "$.link" endsWith "/mcq/A2Q963402"
jsonpath "$.questions" count == 2

GET {{base_url}}/mcq/manage/963403
Authorization: {{auth_qm_super}}
HTTP 200
[Asserts]
jsonpath "$.deactivatedAt" == "2026-01-15T10:00:00"

# 5b. PHP's predicate for a class admin is mcq_admin = 1 on a row that is not removed: a member whose enrolment status is I but who was never removed still counts (902513; copied)
GET {{base_url}}/mcq/manage/963402
Authorization: {{auth_qm_inactive_admin}}
HTTP 200
[Asserts]
jsonpath "$.questions" count == 2

# 6. A quiz with no questions has an empty list
GET {{base_url}}/mcq/manage/963411
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.questions" count == 0
