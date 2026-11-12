# GET /mcq/quizzes/{quiz_id}/questions, cases PHP gets wrong (new API only). A page number too large for PHP's SQL makes PHP answer 200 with a fatal error page; here it is an empty page.

GET {{base_url}}/mcq/quizzes/962402/questions?page=99999999999999999999
Authorization: {{auth_qz_fresh}}
HTTP 200
[Asserts]
jsonpath "$.total" == 3
jsonpath "$.items" count == 0

GET {{base_url}}/mcq/quizzes/962402/questions?page=9223372036854775807&pageSize=100
Authorization: {{auth_qz_fresh}}
HTTP 200
[Asserts]
jsonpath "$.items" count == 0

# The options of one question differ between calls only in order: the set is stable over many requests
GET {{base_url}}/mcq/quizzes/962402/questions?pageSize=1
Authorization: {{auth_qz_fresh}}
HTTP 200
[Asserts]
jsonpath "$.items[0].options" count == 6
jsonpath "$.items[0].options" includes "Gamma"
