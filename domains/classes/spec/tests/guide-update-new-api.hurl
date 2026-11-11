# PUT /guides/{level_id} on the NEW API only (skipped on PHP, which stores a NUL byte; PostgreSQL text cannot): a NUL byte in the guide is a 422, never a server error.
PUT {{base_url}}/guides/2
Authorization: {{auth_wr_admin}}
{"guide": "a\u0000b"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "guide must not contain a NUL byte"
