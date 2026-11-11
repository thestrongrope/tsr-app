# POST /classes/{class_id}/students/{token}/remove, the case PHP gets wrong (the new API only): a NUL byte in the reason is a 422, not stored text. Same fixtures as class-student-remove.hurl;
# it removes nobody (the student 900532 of class 9412 stays).
POST {{base_url}}/classes/9412/students/900532/remove
Authorization: {{auth_wr_admin}}
Content-Type: application/json
{"reason": "bad \u0000 reason"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason is required and must be at most 500 characters"

GET {{base_url}}/classes/9412/students
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students[?(@.token==900532)].name" == "En Member 900532"
