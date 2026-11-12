# GET /classes/{class_id}/my-scores contract: the quizzes of a class the caller answered, with their score. Runs against any implementation.
# Variables: base_url and auth_qz_<alias>. Fixtures: db/synthetic/assessment-a1-fixtures.sql. Reader answered 962401 (3 of 4, last response 2026-02-01 09:00:04), 962404 (2 of 2, 2026-02-02 10:00:00, deactivated now)
# and 962406 (0 of 2, 2026-02-03 11:00:00); another member answered 962401 4 of 4.

# 1. Without sign-in: 401
GET {{base_url}}/classes/9621/my-scores
HTTP 401

# 2. Newest attempt first, the caller's own figures, a bare array
GET {{base_url}}/classes/9621/my-scores
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$" count == 3
jsonpath "$[0].quizId" == 962406
jsonpath "$[0].quizName" == "A1 Quiz Zero Score"
jsonpath "$[0].topic" == "A1 topic three"
jsonpath "$[0].attemptedAt" == "2026-02-03T11:00:00"
jsonpath "$[0].score" == 0
jsonpath "$[0].total" == 2
jsonpath "$[0].percent" == 0.0
jsonpath "$[1].quizId" == 962404
jsonpath "$[1].score" == 2
jsonpath "$[1].percent" == 100.0
jsonpath "$[2].quizId" == 962401
jsonpath "$[2].attemptedAt" == "2026-02-01T09:00:04"
jsonpath "$[2].score" == 3
jsonpath "$[2].total" == 4
jsonpath "$[2].percent" == 75.0
jsonpath "$[2].questions" not exists
jsonpath "$[2].correctText" not exists

# 3. A student with no answers: an empty list; the closed class's student sees their quiz
GET {{base_url}}/classes/9621/my-scores
Authorization: {{auth_qz_fresh}}
HTTP 200
[Asserts]
jsonpath "$" count == 0

GET {{base_url}}/classes/9623/my-scores
Authorization: {{auth_qz_closed}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].quizId" == 962421

# 4. Dates bound each response's own time; a quiz is in when one response is in, with its whole score
GET {{base_url}}/classes/9621/my-scores?start_date=2026-02-02
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$" count == 2
jsonpath "$[0].quizId" == 962406
jsonpath "$[1].quizId" == 962404

GET {{base_url}}/classes/9621/my-scores?end_date=2026-02-01
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$" count == 0

GET {{base_url}}/classes/9621/my-scores?end_date=2026-02-01%2009:00:02
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].quizId" == 962401
jsonpath "$[0].score" == 3
jsonpath "$[0].attemptedAt" == "2026-02-01T09:00:04"

GET {{base_url}}/classes/9621/my-scores?start_date=2026-02-03&end_date=2026-02-03
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$" count == 0

GET {{base_url}}/classes/9621/my-scores?start_date=2026-02-03%2011:00:00&end_date=2026-02-03T11:00:00
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].quizId" == 962406

GET {{base_url}}/classes/9621/my-scores?start_date=20260202
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$" count == 2

GET {{base_url}}/classes/9621/my-scores?start_date=2026-2-2
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$" count == 2

# Text that is not a date reads as the zero date: as a start it bounds nothing, as an end it lists nothing; an empty value is no bound
GET {{base_url}}/classes/9621/my-scores?start_date=abc
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$" count == 3

GET {{base_url}}/classes/9621/my-scores?start_date=2026-13-45
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$" count == 3

GET {{base_url}}/classes/9621/my-scores?end_date=abc
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$" count == 0

GET {{base_url}}/classes/9621/my-scores?start_date=&end_date=
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$" count == 3

# 5. Not a current student of that class: 404 (permission quiz-scores:read has no class target, so access lets everyone in): left, status I, a teacher, a stranger, another class, no such class
GET {{base_url}}/classes/9621/my-scores
Authorization: {{auth_qz_removed}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found or not enrolled"

GET {{base_url}}/classes/9621/my-scores
Authorization: {{auth_qz_inactive}}
HTTP 404

GET {{base_url}}/classes/9621/my-scores
Authorization: {{auth_qz_teacher}}
HTTP 404

GET {{base_url}}/classes/9621/my-scores
Authorization: {{auth_qz_stranger}}
HTTP 404

GET {{base_url}}/classes/9622/my-scores
Authorization: {{auth_qz_reader}}
HTTP 404

GET {{base_url}}/classes/99999999/my-scores
Authorization: {{auth_qz_reader}}
HTTP 404

GET {{base_url}}/classes/abc/my-scores
Authorization: {{auth_qz_reader}}
HTTP 404

# 6. A member with no gender is refused before the class is looked at
GET {{base_url}}/classes/9621/my-scores
Authorization: {{auth_qz_nogender}}
HTTP 400
[Asserts]
jsonpath "$.detail" == "User gender not set; update profile first"
