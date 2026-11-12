# GET /classes/{class_id}/mcq/quizzes, cases PHP gets wrong (new API only): a page number too large for PHP's SQL makes PHP answer 200 with a fatal error page; here an empty page.

GET {{base_url}}/classes/9621/mcq/quizzes?page=99999999999999999999
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.total" == 6
jsonpath "$.hasNext" == false
jsonpath "$.items" count == 0
