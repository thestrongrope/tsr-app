# PUT /mcq/manage/{quiz_id}: what only PHP does, an edit of a quiz that students answered. The new API refuses it (409, see manage-update-new-api.hurl, owner's decision of 12 Nov 2026), so run this file on PHP only.
# Fixtures: db/synthetic/assessment-a2-fixtures.sql (tools/parity-php/assessment-a2-fixtures.sql on PHP). Writes quiz 963422 only.

# 8. FLAGGED PHP behaviour copied: editing a PUBLISHED quiz that students already answered replaces its questions and leaves their answers behind.
#    The student's stored answers stay (2 correct) but now point at deleted questions: the total follows the NEW question count (3) and the percent drops.
GET {{base_url}}/mcq/quizzes/963422/my-score
Authorization: {{auth_qm_student}}
HTTP 200
[Asserts]
jsonpath "$.total" == 2
jsonpath "$.correct" == 2
jsonpath "$.percent" == 100.0

PUT {{base_url}}/mcq/manage/963422
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"name": "Edited after answers", "topic": "A2 topic second", "questions": [{"question": "New q1", "answer": "A1"}, {"question": "New q2", "answer": "A2", "option2": "B2"}, {"question": "New q3", "answer": "A3"}]}
HTTP 200
[Asserts]
jsonpath "$.questionCount" == 3

GET {{base_url}}/mcq/quizzes/963422/my-score
Authorization: {{auth_qm_student}}
HTTP 200
[Asserts]
jsonpath "$.total" == 3
jsonpath "$.answered" == 2
jsonpath "$.correct" == 2
jsonpath "$.percent" == 66.67
jsonpath "$.responses[0].questionId" == 963515
jsonpath "$.responses[0].questionText" == null

GET {{base_url}}/mcq/manage/963422
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.publishedAt" == "2026-01-10T10:00:00"
jsonpath "$.questions[0].id" != 963515
jsonpath "$.questions" count == 3
