# GET /mcq/quizzes/{quiz_id}/questions contract: a page of a quiz's questions, options shuffled (the tests assert the set of options, never their order). Runs against any implementation.
# Variables: base_url and auth_qz_<alias>. Fixtures: db/synthetic/assessment-a1-fixtures.sql. Quiz 962402 has 3 questions: five options, an Arabic one with two, one with a blank second option.

# 1. Without sign-in: 401
GET {{base_url}}/mcq/quizzes/962402/questions
HTTP 401

# 2. A student who has not answered: every question, the options plus "I don't know", and nothing that says which is right
GET {{base_url}}/mcq/quizzes/962402/questions
Authorization: {{auth_qz_fresh}}
HTTP 200
[Asserts]
jsonpath "$.total" == 3
jsonpath "$.page" == 1
jsonpath "$.pageSize" == 20
jsonpath "$.items" count == 3
jsonpath "$.items[0].id" == 962505
jsonpath "$.items[0].text" == "Which is first?"
jsonpath "$.items[0].isArabic" == false
jsonpath "$.items[0].options" count == 6
jsonpath "$.items[0].options" includes "Alpha"
jsonpath "$.items[0].options" includes "Beta"
jsonpath "$.items[0].options" includes "Gamma"
jsonpath "$.items[0].options" includes "Delta"
jsonpath "$.items[0].options" includes "Epsilon"
jsonpath "$.items[0].options" includes "I don't know"
jsonpath "$.items[1].id" == 962506
jsonpath "$.items[1].text" == "ما هو؟"
jsonpath "$.items[1].isArabic" == true
jsonpath "$.items[1].options" count == 3
jsonpath "$.items[1].options" includes "نعم"
jsonpath "$.items[1].options" includes "لا"
jsonpath "$.items[1].options" includes "I don't know"
jsonpath "$.items[2].options" count == 2
jsonpath "$.items[2].options" includes "Solo"
jsonpath "$.items[2].options" includes "I don't know"
jsonpath "$.items[0].answer" not exists
jsonpath "$.items[0].correctText" not exists
jsonpath "$.items[0].correct" not exists
jsonpath "$.items[0].optionDisplayOrder" not exists

# 3. Paging as PHP reads it: page at least 1, size 1 to 100 (default 20), text read as its numeric prefix
GET {{base_url}}/mcq/quizzes/962402/questions?page=2&pageSize=1
Authorization: {{auth_qz_fresh}}
HTTP 200
[Asserts]
jsonpath "$.total" == 3
jsonpath "$.page" == 2
jsonpath "$.pageSize" == 1
jsonpath "$.items" count == 1
jsonpath "$.items[0].id" == 962506

GET {{base_url}}/mcq/quizzes/962402/questions?page=-5&pageSize=0
Authorization: {{auth_qz_fresh}}
HTTP 200
[Asserts]
jsonpath "$.page" == 1
jsonpath "$.pageSize" == 1
jsonpath "$.items[0].id" == 962505

GET {{base_url}}/mcq/quizzes/962402/questions?page=abc&pageSize=500
Authorization: {{auth_qz_fresh}}
HTTP 200
[Asserts]
jsonpath "$.page" == 1
jsonpath "$.pageSize" == 100
jsonpath "$.items" count == 3

GET {{base_url}}/mcq/quizzes/962402/questions?page=5
Authorization: {{auth_qz_fresh}}
HTTP 200
[Asserts]
jsonpath "$.total" == 3
jsonpath "$.items" count == 0

# 4. A quiz with no questions is an empty page
GET {{base_url}}/mcq/quizzes/962407/questions
Authorization: {{auth_qz_fresh}}
HTTP 200
[Asserts]
jsonpath "$.total" == 0
jsonpath "$.items" count == 0

# 5. PHP's asymmetry, copied: a score of 0 does not block the questions (submit would refuse the second attempt); a score above 0 does
GET {{base_url}}/mcq/quizzes/962406/questions
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.total" == 2

GET {{base_url}}/mcq/quizzes/962401/questions
Authorization: {{auth_qz_reader}}
HTTP 409
[Asserts]
jsonpath "$.detail" == "Quiz already attempted. Cannot retake."

# The attempt check comes before the deactivated check: an answered deactivated quiz is "already attempted"
GET {{base_url}}/mcq/quizzes/962404/questions
Authorization: {{auth_qz_reader}}
HTTP 409
[Asserts]
jsonpath "$.detail" == "Quiz already attempted. Cannot retake."

# 6. A deactivated quiz nobody answered: visible but not takeable
GET {{base_url}}/mcq/quizzes/962405/questions
Authorization: {{auth_qz_fresh}}
HTTP 409
[Asserts]
jsonpath "$.detail" == "This quiz is not currently available"

# 7. Not visible: a draft, another class's quiz, a student who left, one whose enrolment is not active, a teacher, a stranger
GET {{base_url}}/mcq/quizzes/962403/questions
Authorization: {{auth_qz_fresh}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

GET {{base_url}}/mcq/quizzes/962431/questions
Authorization: {{auth_qz_fresh}}
HTTP 404

GET {{base_url}}/mcq/quizzes/962402/questions
Authorization: {{auth_qz_removed}}
HTTP 404

GET {{base_url}}/mcq/quizzes/962402/questions
Authorization: {{auth_qz_inactive}}
HTTP 404

GET {{base_url}}/mcq/quizzes/962402/questions
Authorization: {{auth_qz_teacher}}
HTTP 404

GET {{base_url}}/mcq/quizzes/962402/questions
Authorization: {{auth_qz_stranger}}
HTTP 404

GET {{base_url}}/mcq/quizzes/99999999/questions
Authorization: {{auth_qz_fresh}}
HTTP 404

GET {{base_url}}/mcq/quizzes/abc/questions
Authorization: {{auth_qz_fresh}}
HTTP 404

GET {{base_url}}/mcq/quizzes/99999999999999999999999/questions
Authorization: {{auth_qz_fresh}}
HTTP 404

# 8. A quiz of a closed class is still takeable (PHP does not look at the class's status)
GET {{base_url}}/mcq/quizzes/962421/questions
Authorization: {{auth_qz_closed_fresh}}
HTTP 200
[Asserts]
jsonpath "$.total" == 1

# 9. A member with no gender is refused first
GET {{base_url}}/mcq/quizzes/962402/questions
Authorization: {{auth_qz_nogender}}
HTTP 400
[Asserts]
jsonpath "$.detail" == "User gender not set; update profile first"
