# POST /mcq/quizzes/{quiz_id}/responses, cases where PHP fails or pollutes its body (new API only). submit7 on 962438 (a quiz submit6 answers as another member).

# An answer longer than the column: PHP answers 500 "Failed to save responses"; here 400 and nothing is stored
POST {{base_url}}/mcq/quizzes/962438/responses
Authorization: {{auth_qz_submit7}}
{"responses": [{"questionId": 962545, "selectedText": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}]}
HTTP 400
[Asserts]
jsonpath "$.detail" == "selectedText is too long"

GET {{base_url}}/mcq/quizzes/962438/my-score
Authorization: {{auth_qz_submit7}}
HTTP 404

# A NUL character in the answer: PostgreSQL text cannot hold it, so it is dropped (and the answer "a" then scores)
POST {{base_url}}/mcq/quizzes/962438/responses
Authorization: {{auth_qz_submit7}}
{"responses": [{"questionId": 962545, "selectedText": "a\u0000"}]}
HTTP 200
[Asserts]
jsonpath "$.correct" == 1
jsonpath "$.responses[0].selectedText" == "a"

# An array for the text: PHP stores "Array" and prints warnings into the body; here the same stored text, a clean body (submit8 on 962437, another member than submit5)
POST {{base_url}}/mcq/quizzes/962437/responses
Authorization: {{auth_qz_submit8}}
{"responses": [{"questionId": 962540, "selectedText": ["a"]}, {"questionId": 962541, "selectedText": {"a": 1}}, {"questionId": 962542, "selectedText": true}, {"questionId": 962543}, {"questionId": 962544, "selectedText": false}]}
HTTP 200
[Asserts]
jsonpath "$.correct" == 1
jsonpath "$.responses[0].selectedText" == "Array"
jsonpath "$.responses[1].selectedText" == "Array"
jsonpath "$.responses[2].selectedText" == "1"
jsonpath "$.responses[2].isCorrect" == 1
jsonpath "$.responses[3].selectedText" == null
jsonpath "$.responses[4].selectedText" == null
