# PUT /mcq/manage/{quiz_id}: cases PHP gets wrong or answers with a PHP warning printed into the body; the new API only (tools/assessment-contract.sh skips *-new-api.hurl on PHP).
# Fixtures: db/synthetic/assessment-a2-fixtures.sql. Writes quiz 963425 only; 963405 only receives refused edits.

# 1. A name or topic too long for its column, a NUL byte, are 422 (PHP: 500 "Failed to save quiz", or it stores the NUL); nothing changes
PUT {{base_url}}/mcq/manage/963405
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"name": "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", "topic": "T"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "name is too long (at most 300 characters)"

PUT {{base_url}}/mcq/manage/963405
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"name": "a\u0000b", "topic": "T"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "name contains an invalid character"

PUT {{base_url}}/mcq/manage/963405
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"name": "N", "topic": "T", "questions": [{"question": "Q", "answer": "A", "option3": "x\u0000y"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Question 1 contains an invalid character"

GET {{base_url}}/mcq/manage/963405
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.name" == "A2 Quiz Edit Refused"
jsonpath "$.questions" count == 1

# 2. Wrong JSON types: `questions` that is not an array deletes the questions (as PHP, without its warning text in the body); a name that is a list is the text "Array" (the topic stays as fixed: topic lists of other files run in parallel)
PUT {{base_url}}/mcq/manage/963425
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"name": "A2 Edit Types", "topic": "A2 topic second", "questions": "abc"}
HTTP 200
[Asserts]
jsonpath "$.questionCount" == 0

GET {{base_url}}/mcq/manage/963425
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.questions" count == 0

PUT {{base_url}}/mcq/manage/963425
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"name": ["x"], "topic": "A2 topic second", "questions": [{"question": 7, "answer": true}]}
HTTP 200
[Asserts]
jsonpath "$.questionCount" == 1

GET {{base_url}}/mcq/manage/963425
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.name" == "Array"
jsonpath "$.topic" == "A2 topic second"
jsonpath "$.questions[0].question" == "7"
jsonpath "$.questions[0].answer" == "1"
