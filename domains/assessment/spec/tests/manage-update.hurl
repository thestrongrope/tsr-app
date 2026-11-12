# PUT /mcq/manage/{quiz_id} contract: save a quiz's name, topic and restriction and REPLACE its questions. Runs against any implementation.
# Variables: base_url and auth_qm_<alias> (tools/assessment-contract.sh). Fixtures: db/synthetic/assessment-a2-fixtures.sql (read its header).
# Keeps every topic as the fixture has it (the topic lists of other files run in parallel). Writes quizzes 963404, 963405 (refusals only: it is never changed), 963423 and 963424 only (963422, the answered one, is in manage-update-php-only.hurl and manage-update-new-api.hurl) (no other file does); a second run needs the fixtures again (tools/assessment-contract.sh does that on every run).
# A PHP warning is printed into the body when `questions` or `name` has the wrong JSON type: those cases are in manage-update-new-api.hurl.

# 1. Without sign-in: 401
PUT {{base_url}}/mcq/manage/963405
Content-Type: application/json
{"name": "N", "topic": "T"}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A missing quiz is 404 before any permission check; a non-number is a quiz that does not exist; a quiz of a closed class is a class 404
PUT {{base_url}}/mcq/manage/99999999
Authorization: {{auth_qm_nobody}}
Content-Type: application/json
{"name": "N", "topic": "T"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

PUT {{base_url}}/mcq/manage/abc
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"name": "N", "topic": "T"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

PUT {{base_url}}/mcq/manage/963441
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"name": "N", "topic": "T"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 3. Refused: a plain student, the admin of another class, a removed admin, a member of no class, the teacher of another class, a gender admin, a coordinator
PUT {{base_url}}/mcq/manage/963405
Authorization: {{auth_qm_student}}
Content-Type: application/json
{"name": "Hacked", "topic": "T", "questions": []}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

PUT {{base_url}}/mcq/manage/963405
Authorization: {{auth_qm_other_admin}}
Content-Type: application/json
{"name": "Hacked", "topic": "T", "questions": []}
HTTP 403

PUT {{base_url}}/mcq/manage/963405
Authorization: {{auth_qm_removed_admin}}
Content-Type: application/json
{"name": "Hacked", "topic": "T", "questions": []}
HTTP 403

PUT {{base_url}}/mcq/manage/963405
Authorization: {{auth_qm_nobody}}
Content-Type: application/json
{"name": "Hacked", "topic": "T", "questions": []}
HTTP 403

PUT {{base_url}}/mcq/manage/963405
Authorization: {{auth_qm_teacher2}}
Content-Type: application/json
{"name": "Hacked", "topic": "T", "questions": []}
HTTP 403

PUT {{base_url}}/mcq/manage/963405
Authorization: {{auth_qm_gents_admin}}
Content-Type: application/json
{"name": "Hacked", "topic": "T", "questions": []}
HTTP 403

PUT {{base_url}}/mcq/manage/963405
Authorization: {{auth_qm_coord}}
Content-Type: application/json
{"name": "Hacked", "topic": "T", "questions": []}
HTTP 403

# 4. Validation, in PHP's order; nothing is written (the quiz keeps its name and its one question)
PUT {{base_url}}/mcq/manage/963405
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
"just text"
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

PUT {{base_url}}/mcq/manage/963405
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"topic": "T"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "name is required"

PUT {{base_url}}/mcq/manage/963405
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"name": "   ", "topic": ""}
HTTP 422
[Asserts]
jsonpath "$.detail" == "name is required"

PUT {{base_url}}/mcq/manage/963405
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"name": "N", "topic": "   "}
HTTP 422
[Asserts]
jsonpath "$.detail" == "topic is required"

PUT {{base_url}}/mcq/manage/963405
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"name": "N", "topic": "T", "questions": [{"question": "ok", "answer": "ok"}, {"question": "no answer"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Question 2 needs both a question and an answer"

PUT {{base_url}}/mcq/manage/963405
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"name": "N", "topic": "T", "questions": [{"question": "ok", "answer": "ok"}, {"answer": "no question"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Question 2 needs both a question and an answer"

GET {{base_url}}/mcq/manage/963405
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.name" == "A2 Quiz Edit Refused"
jsonpath "$.questions" count == 1
jsonpath "$.questions[0].question" == "A2 refuse q1"

# 5. The teacher replaces name, topic, restriction and questions: option1 is the answer, options are trimmed, an empty or "null" option reads back null, blank rows are skipped
PUT {{base_url}}/mcq/manage/963404
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"name": "  Edited name ", "topic": " A2 topic edit ", "restrictToClass": 0, "questions": [
  {"question": " Which? ", "answer": " Right ", "option2": "W2", "option3": " W3 ", "option4": "null", "option5": "W5"},
  {"question": "ما هو؟", "answer": "نعم", "option2": "لا"},
  {"question": "", "answer": ""},
  {"question": "  ", "answer": " "},
  17,
  {"question": "Last", "answer": "A", "option2": "", "option3": "null"}]}
HTTP 200
[Asserts]
jsonpath "$.id" == 963404
jsonpath "$.questionCount" == 3

GET {{base_url}}/mcq/manage/963404
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.name" == "Edited name"
jsonpath "$.topic" == "A2 topic edit"
jsonpath "$.restrictToClass" == 0
jsonpath "$.questions" count == 3
jsonpath "$.questions[0].question" == "Which?"
jsonpath "$.questions[0].answer" == "Right"
jsonpath "$.questions[0].option2" == "W2"
jsonpath "$.questions[0].option3" == "W3"
jsonpath "$.questions[0].option4" == null
jsonpath "$.questions[0].option5" == "W5"
jsonpath "$.questions[1].question" == "ما هو؟"
jsonpath "$.questions[1].answer" == "نعم"
jsonpath "$.questions[1].option2" == "لا"
jsonpath "$.questions[1].option3" == null
jsonpath "$.questions[2].question" == "Last"
jsonpath "$.questions[2].option2" == null
jsonpath "$.questions[2].option3" == null

# the questions have new ids (deleted and inserted again), none of the fixture's 963507 and 963508
GET {{base_url}}/mcq/manage/963404
Authorization: {{auth_qm_admin}}
HTTP 200
[Asserts]
jsonpath "$.questions[0].id" != 963507
jsonpath "$.questions[0].id" != 963508

# the restriction is left alone when absent, and 0 for anything PHP reads as 0; a class admin and a super admin may edit
PUT {{base_url}}/mcq/manage/963404
Authorization: {{auth_qm_admin}}
Content-Type: application/json
{"name": "Edited name", "topic": "A2 topic edit", "questions": [{"question": "Q", "answer": "A"}]}
HTTP 200
[Asserts]
jsonpath "$.questionCount" == 1

GET {{base_url}}/mcq/manage/963404
Authorization: {{auth_qm_super}}
HTTP 200
[Asserts]
jsonpath "$.restrictToClass" == 0
jsonpath "$.questions" count == 1

PUT {{base_url}}/mcq/manage/963404
Authorization: {{auth_qm_super}}
Content-Type: application/json
{"name": "Edited name", "topic": "A2 topic edit", "restrictToClass": 5, "questions": [{"question": "Q", "answer": "A"}]}
HTTP 200

GET {{base_url}}/mcq/manage/963404
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.restrictToClass" == 1

# 6. Quirk copied: no `questions` at all deletes every question of the quiz
PUT {{base_url}}/mcq/manage/963423
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"name": "A2 Edit Wipe", "topic": "A2 topic second"}
HTTP 200
[Asserts]
jsonpath "$.id" == 963423
jsonpath "$.questionCount" == 0

GET {{base_url}}/mcq/manage/963423
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.questions" count == 0

# 7. Quirk copied: a question whose text is "0" is counted in questionCount but never stored; the text "null" as the answer stores no answer
PUT {{base_url}}/mcq/manage/963424
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"name": "A2 Edit Quirks", "topic": "A2 topic second", "questions": [{"question": "0", "answer": "x"}, {"question": "Real", "answer": "null", "option2": "kept"}]}
HTTP 200
[Asserts]
jsonpath "$.questionCount" == 2

GET {{base_url}}/mcq/manage/963424
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.questions" count == 1
jsonpath "$.questions[0].question" == "Real"
jsonpath "$.questions[0].answer" == null
jsonpath "$.questions[0].option2" == "kept"
