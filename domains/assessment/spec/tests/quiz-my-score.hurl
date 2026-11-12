# GET /mcq/quizzes/{quiz_id}/my-score contract: the caller's own answers to a quiz and the result. Runs against any implementation.
# Variables: base_url and auth_qz_<alias>. Fixtures: db/synthetic/assessment-a1-fixtures.sql. Reader answered 962401 (3 of 4), 962404 (2 of 2, deactivated now) and 962406 (0 of 2); another member answered 962401 4 of 4.

# 1. Without sign-in: 401
GET {{base_url}}/mcq/quizzes/962401/my-score
HTTP 401

# 2. The caller's answers, in question order; the selected index is always 0; the percent is a float over the question count
GET {{base_url}}/mcq/quizzes/962401/my-score
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.total" == 4
jsonpath "$.answered" == 4
jsonpath "$.correct" == 3
jsonpath "$.percent" == 75.0
jsonpath "$.responses" count == 4
jsonpath "$.responses[0].questionId" == 962501
jsonpath "$.responses[0].questionText" == "A1 q1"
jsonpath "$.responses[0].selected" == 0
jsonpath "$.responses[0].selectedText" == "a"
jsonpath "$.responses[0].correctText" == "a"
jsonpath "$.responses[0].isCorrect" == 1
jsonpath "$.responses[2].questionId" == 962503
jsonpath "$.responses[2].selectedText" == "b"
jsonpath "$.responses[2].correctText" == "a"
jsonpath "$.responses[2].isCorrect" == 0

# 3. A deactivated quiz the caller answered still shows the result; a score of 0 is 0.0
GET {{base_url}}/mcq/quizzes/962404/my-score
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.correct" == 2
jsonpath "$.percent" == 100.0

GET {{base_url}}/mcq/quizzes/962406/my-score
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.correct" == 0
jsonpath "$.answered" == 2
jsonpath "$.percent" == 0.0

# The closed class's student sees their own result
GET {{base_url}}/mcq/quizzes/962421/my-score
Authorization: {{auth_qz_closed}}
HTTP 200
[Asserts]
jsonpath "$.total" == 1
jsonpath "$.percent" == 100.0

# 4. Visible but not answered: 404 "No attempt found"
GET {{base_url}}/mcq/quizzes/962402/my-score
Authorization: {{auth_qz_reader}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "No attempt found"

GET {{base_url}}/mcq/quizzes/962401/my-score
Authorization: {{auth_qz_fresh}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "No attempt found"

# 5. Not visible: a draft, another class's quiz, left, status I, teacher, stranger, an id that matches nothing
GET {{base_url}}/mcq/quizzes/962403/my-score
Authorization: {{auth_qz_reader}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

GET {{base_url}}/mcq/quizzes/962431/my-score
Authorization: {{auth_qz_reader}}
HTTP 404

GET {{base_url}}/mcq/quizzes/962401/my-score
Authorization: {{auth_qz_removed}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

GET {{base_url}}/mcq/quizzes/962401/my-score
Authorization: {{auth_qz_inactive}}
HTTP 404

GET {{base_url}}/mcq/quizzes/962401/my-score
Authorization: {{auth_qz_teacher}}
HTTP 404

GET {{base_url}}/mcq/quizzes/962401/my-score
Authorization: {{auth_qz_stranger}}
HTTP 404

GET {{base_url}}/mcq/quizzes/99999999/my-score
Authorization: {{auth_qz_reader}}
HTTP 404

GET {{base_url}}/mcq/quizzes/abc/my-score
Authorization: {{auth_qz_reader}}
HTTP 404

# 6. A member with no gender is refused first (even though this member answered 962401)
GET {{base_url}}/mcq/quizzes/962401/my-score
Authorization: {{auth_qz_nogender}}
HTTP 400
[Asserts]
jsonpath "$.detail" == "User gender not set; update profile first"
