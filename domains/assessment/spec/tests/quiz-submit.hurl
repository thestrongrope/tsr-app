# POST /mcq/quizzes/{quiz_id}/responses contract: the server scores the answers (the selected TEXT against the right option) and stores them. Runs against any implementation.
# Variables: base_url and auth_qz_<alias>. Fixtures: db/synthetic/assessment-a1-fixtures.sql, reset by tools/assessment-contract.sh on every run. Each member below answers a quiz only in this file.

# 1. Without sign-in: 401
POST {{base_url}}/mcq/quizzes/962431/responses
{"responses": []}
HTTP 401

# 2. A good submission (submit1 on 962431): scored by text, trimmed and case-folded; the correct text is returned after answering
POST {{base_url}}/mcq/quizzes/962431/responses
Authorization: {{auth_qz_submit1}}
{"responses": [
  {"questionId": 962533, "selectedText": "نعم", "option": 1},
  {"questionId": 962531, "selectedText": "  alpha ", "option": 1},
  {"questionId": 962532, "selectedText": "Red", "option": 2}
]}
HTTP 200
[Asserts]
jsonpath "$.total" == 3
jsonpath "$.answered" == 3
jsonpath "$.correct" == 2
jsonpath "$.percent" == 66.67
jsonpath "$.responses" count == 3
jsonpath "$.responses[0].questionId" == 962531
jsonpath "$.responses[0].questionText" == "First?"
jsonpath "$.responses[0].selected" == 1
jsonpath "$.responses[0].selectedText" == "  alpha "
jsonpath "$.responses[0].correctText" == "Alpha"
jsonpath "$.responses[0].isCorrect" == 1
jsonpath "$.responses[1].questionId" == 962532
jsonpath "$.responses[1].selected" == 2
jsonpath "$.responses[1].correctText" == "Green"
jsonpath "$.responses[1].isCorrect" == 0
jsonpath "$.responses[2].selectedText" == "نعم"
jsonpath "$.responses[2].isCorrect" == 1

# The answers are kept: a second submission is refused, the quiz shows as attempted, the result reads back, the questions are closed
POST {{base_url}}/mcq/quizzes/962431/responses
Authorization: {{auth_qz_submit1}}
{"responses": [{"questionId": 962531, "selectedText": "Alpha"}, {"questionId": 962532, "selectedText": "Green"}, {"questionId": 962533, "selectedText": "نعم"}]}
HTTP 409
[Asserts]
jsonpath "$.detail" == "Already attempted"

GET {{base_url}}/mcq/quizzes/962431
Authorization: {{auth_qz_submit1}}
HTTP 200
[Asserts]
jsonpath "$.attempted" == true
jsonpath "$.score" == 2

GET {{base_url}}/mcq/quizzes/962431/my-score
Authorization: {{auth_qz_submit1}}
HTTP 200
[Asserts]
jsonpath "$.correct" == 2
jsonpath "$.percent" == 66.67
jsonpath "$.responses[1].selectedText" == "Red"
jsonpath "$.responses[1].selected" == 0

GET {{base_url}}/mcq/quizzes/962431/questions
Authorization: {{auth_qz_submit1}}
HTTP 409
[Asserts]
jsonpath "$.detail" == "Quiz already attempted. Cannot retake."

# Another member of the class is not blocked by that answer
GET {{base_url}}/mcq/quizzes/962431/my-score
Authorization: {{auth_qz_submit9}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "No attempt found"

# 3. A repeat of the same submission is refused (submit2 on 962432)
POST {{base_url}}/mcq/quizzes/962432/responses
Authorization: {{auth_qz_submit2}}
{"responses": [{"questionId": 962534, "selectedText": "a"}, {"questionId": 962535, "selectedText": "b"}]}
HTTP 200
[Asserts]
jsonpath "$.correct" == 1
jsonpath "$.percent" == 50.0

POST {{base_url}}/mcq/quizzes/962432/responses
Authorization: {{auth_qz_submit2}}
{"responses": [{"questionId": 962534, "selectedText": "a"}, {"questionId": 962535, "selectedText": "b"}]}
HTTP 409
[Asserts]
jsonpath "$.detail" == "Already attempted"

# 4. Bad bodies (submit3 on 962433, questions 962536 and 962537): nothing is stored
POST {{base_url}}/mcq/quizzes/962433/responses
Authorization: {{auth_qz_submit3}}
{}
HTTP 400
[Asserts]
jsonpath "$.detail" == "Payload requires non-empty responses"

POST {{base_url}}/mcq/quizzes/962433/responses
Authorization: {{auth_qz_submit3}}
```
abc
```
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

POST {{base_url}}/mcq/quizzes/962433/responses
Authorization: {{auth_qz_submit3}}
{"responses": "x"}
HTTP 400
[Asserts]
jsonpath "$.detail" == "Payload requires non-empty responses"

POST {{base_url}}/mcq/quizzes/962433/responses
Authorization: {{auth_qz_submit3}}
{"responses": []}
HTTP 400

POST {{base_url}}/mcq/quizzes/962433/responses
Authorization: {{auth_qz_submit3}}
{"responses": null}
HTTP 400

POST {{base_url}}/mcq/quizzes/962433/responses
Authorization: {{auth_qz_submit3}}
{"responses": [1, "a", {"selectedText": "x"}, {"questionId": null}]}
HTTP 400
[Asserts]
jsonpath "$.detail.missing" count == 2
jsonpath "$.detail.missing[0]" == 962536
jsonpath "$.detail.missing[1]" == 962537
jsonpath "$.detail.extra" count == 0

POST {{base_url}}/mcq/quizzes/962433/responses
Authorization: {{auth_qz_submit3}}
{"responses": [{"questionId": 962536, "selectedText": "a"}]}
HTTP 400
[Asserts]
jsonpath "$.detail.missing" count == 1
jsonpath "$.detail.missing[0]" == 962537
jsonpath "$.detail.extra" count == 0

POST {{base_url}}/mcq/quizzes/962433/responses
Authorization: {{auth_qz_submit3}}
{"responses": [{"questionId": 962536, "selectedText": "a"}, {"questionId": 962537, "selectedText": "a"}, {"questionId": 5, "selectedText": "a"}, {"questionId": "abc"}, {"questionId": 962431}]}
HTTP 400
[Asserts]
jsonpath "$.detail.missing" count == 0
jsonpath "$.detail.extra" count == 3
jsonpath "$.detail.extra[0]" == 5
jsonpath "$.detail.extra[1]" == 0
jsonpath "$.detail.extra[2]" == 962431

GET {{base_url}}/mcq/quizzes/962433/my-score
Authorization: {{auth_qz_submit3}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "No attempt found"

# 5. Refusals before the body is read (submit4): a deactivated quiz, a draft, a quiz without questions, another class's quiz
POST {{base_url}}/mcq/quizzes/962434/responses
Authorization: {{auth_qz_submit4}}
{"responses": [{"questionId": 962538, "selectedText": "a"}]}
HTTP 409
[Asserts]
jsonpath "$.detail" == "This quiz is not currently available"

POST {{base_url}}/mcq/quizzes/962435/responses
Authorization: {{auth_qz_submit4}}
{"responses": [{"questionId": 962539, "selectedText": "a"}]}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

POST {{base_url}}/mcq/quizzes/962436/responses
Authorization: {{auth_qz_submit4}}
{"responses": [{"questionId": 1, "selectedText": "a"}]}
HTTP 400
[Asserts]
jsonpath "$.detail" == "Quiz has no questions"

# Invalid JSON on a quiz that is not visible is a 404 (the quiz is looked up before the body is read)
POST {{base_url}}/mcq/quizzes/962402/responses
Authorization: {{auth_qz_submit4}}
```
abc
```
HTTP 404

POST {{base_url}}/mcq/quizzes/99999999/responses
Authorization: {{auth_qz_submit4}}
{"responses": [{"questionId": 1, "selectedText": "a"}]}
HTTP 404

POST {{base_url}}/mcq/quizzes/abc/responses
Authorization: {{auth_qz_submit4}}
{"responses": [{"questionId": 1, "selectedText": "a"}]}
HTTP 404

# 6. Who may not answer: not enrolled in the class (a student of another class, a student who left, a status I enrolment, a teacher, a stranger), answered already, no gender
POST {{base_url}}/mcq/quizzes/962431/responses
Authorization: {{auth_qz_reader}}
{"responses": [{"questionId": 962531, "selectedText": "Alpha"}]}
HTTP 404

POST {{base_url}}/mcq/quizzes/962402/responses
Authorization: {{auth_qz_removed}}
{"responses": [{"questionId": 962505, "selectedText": "Gamma"}]}
HTTP 404

POST {{base_url}}/mcq/quizzes/962402/responses
Authorization: {{auth_qz_inactive}}
{"responses": [{"questionId": 962505, "selectedText": "Gamma"}]}
HTTP 404

POST {{base_url}}/mcq/quizzes/962402/responses
Authorization: {{auth_qz_teacher}}
{"responses": [{"questionId": 962505, "selectedText": "Gamma"}]}
HTTP 404

POST {{base_url}}/mcq/quizzes/962402/responses
Authorization: {{auth_qz_stranger}}
{"responses": [{"questionId": 962505, "selectedText": "Gamma"}]}
HTTP 404

POST {{base_url}}/mcq/quizzes/962401/responses
Authorization: {{auth_qz_reader}}
{"responses": [{"questionId": 962501, "selectedText": "a"}]}
HTTP 409
[Asserts]
jsonpath "$.detail" == "Already attempted"

POST {{base_url}}/mcq/quizzes/962402/responses
Authorization: {{auth_qz_nogender}}
{"responses": [{"questionId": 962505, "selectedText": "Gamma"}]}
HTTP 400
[Asserts]
jsonpath "$.detail" == "User gender not set; update profile first"

# 7. Scoring (submit5 on 962437): case and edge spaces do not matter; entities, "1.0" for "1" and the wrong option do
POST {{base_url}}/mcq/quizzes/962437/responses
Authorization: {{auth_qz_submit5}}
{"responses": [
  {"questionId": 962540, "selectedText": "ALPHA "},
  {"questionId": 962541, "selectedText": "Rock&amp;Roll"},
  {"questionId": 962542, "selectedText": "1.0"},
  {"questionId": 962543, "selectedText": " نعم"},
  {"questionId": 962544, "selectedText": "tea"}
]}
HTTP 200
[Asserts]
jsonpath "$.total" == 5
jsonpath "$.correct" == 2
jsonpath "$.percent" == 40.0
jsonpath "$.responses[0].isCorrect" == 1
jsonpath "$.responses[1].isCorrect" == 0
jsonpath "$.responses[1].correctText" == "Rock&Roll"
jsonpath "$.responses[2].isCorrect" == 0
jsonpath "$.responses[3].isCorrect" == 0
jsonpath "$.responses[4].isCorrect" == 1
jsonpath "$.responses[4].correctText" == "Tea"

# 8. Odd values, as PHP stores them (submit6 on 962438): a number for the text, a word for the option index
POST {{base_url}}/mcq/quizzes/962438/responses
Authorization: {{auth_qz_submit6}}
{"responses": [{"questionId": 962545, "selectedText": 123, "option": "x"}]}
HTTP 200
[Asserts]
jsonpath "$.correct" == 0
jsonpath "$.responses[0].selectedText" == "123"
jsonpath "$.responses[0].selected" == 0
jsonpath "$.responses[0].correctText" == "a"
