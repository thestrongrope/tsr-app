# GET /mcq/quizzes/{quiz_id} contract: one quiz the caller may see, with their own attempt. Runs against any implementation.
# Variables: base_url and auth_qz_<alias> (tools/assessment-contract.sh). Fixtures: db/synthetic/assessment-a1-fixtures.sql (read its header).

# 1. Without sign-in: 401
GET {{base_url}}/mcq/quizzes/962401
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A student who has not answered: the quiz, not attempted, no score
GET {{base_url}}/mcq/quizzes/962401
Authorization: {{auth_qz_fresh}}
HTTP 200
[Asserts]
jsonpath "$.id" == 962401
jsonpath "$.code" == "A1Q962401"
jsonpath "$.name" == "A1 Quiz Live Answered"
jsonpath "$.topic" == "A1 topic one"
jsonpath "$.classId" == 9621
jsonpath "$.publishedAt" == "2026-01-10T10:00:00"
jsonpath "$.questionCount" == 4
jsonpath "$.attempted" == false
jsonpath "$.score" == null
# Nothing of a question or an answer is on the wire
jsonpath "$.questions" not exists
jsonpath "$.correctText" not exists

# 3. A student who answered: attempted, and their own score (not another member's 4 of 4)
GET {{base_url}}/mcq/quizzes/962401
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.attempted" == true
jsonpath "$.score" == 3
jsonpath "$.questionCount" == 4

# 4. A quiz with no topic has a null topic; a score of 0 stays 0
GET {{base_url}}/mcq/quizzes/962402
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.topic" == null
jsonpath "$.attempted" == false
jsonpath "$.questionCount" == 3

GET {{base_url}}/mcq/quizzes/962406
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.attempted" == true
jsonpath "$.score" == 0

# 5. A deactivated quiz is still visible (the student who answered sees the result); a closed class's quiz is visible too
GET {{base_url}}/mcq/quizzes/962404
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.attempted" == true
jsonpath "$.score" == 2

GET {{base_url}}/mcq/quizzes/962421
Authorization: {{auth_qz_closed}}
HTTP 200
[Asserts]
jsonpath "$.classId" == 9623

# 6. A draft is not visible, to a student or the class's teacher
GET {{base_url}}/mcq/quizzes/962403
Authorization: {{auth_qz_reader}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

# 7. A quiz of a class the caller is not a current student of: 404 (another class, left, status I, a teacher, a stranger)
GET {{base_url}}/mcq/quizzes/962431
Authorization: {{auth_qz_reader}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

GET {{base_url}}/mcq/quizzes/962401
Authorization: {{auth_qz_removed}}
HTTP 404

GET {{base_url}}/mcq/quizzes/962401
Authorization: {{auth_qz_inactive}}
HTTP 404

GET {{base_url}}/mcq/quizzes/962401
Authorization: {{auth_qz_teacher}}
HTTP 404

GET {{base_url}}/mcq/quizzes/962401
Authorization: {{auth_qz_stranger}}
HTTP 404

# 8. A member with no gender is refused before the quiz is looked up
GET {{base_url}}/mcq/quizzes/962401
Authorization: {{auth_qz_nogender}}
HTTP 400
[Asserts]
jsonpath "$.detail" == "User gender not set; update profile first"

# 9. An id that matches nothing: 404, never a 500
GET {{base_url}}/mcq/quizzes/99999999
Authorization: {{auth_qz_reader}}
HTTP 404

GET {{base_url}}/mcq/quizzes/abc
Authorization: {{auth_qz_reader}}
HTTP 404

GET {{base_url}}/mcq/quizzes/99999999999999999999999
Authorization: {{auth_qz_reader}}
HTTP 404

