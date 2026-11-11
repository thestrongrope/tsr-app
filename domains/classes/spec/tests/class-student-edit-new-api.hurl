# PUT /classes/{class_id}/students/{token}: a NUL character in a field is a 422 (PostgreSQL cannot store it; PHP stores it). New API only. Fixtures as class-student-edit.hurl.
PUT {{base_url}}/classes/9433/students/900622
Authorization: {{auth_en_gadmin}}
{"notes": "a\u0000b"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "notes must be text of at most 500 characters"
