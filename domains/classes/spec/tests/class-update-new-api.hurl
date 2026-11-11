# PUT /classes/{class_id} on the NEW API only (skipped on PHP, which stores a NUL byte; PostgreSQL text cannot): a NUL byte in a text field is a 422, never a server error.
# Variables: base_url and auth_<alias>. WRITE fixtures: class 9403, the write admin.

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"format": "Online", "city": "Pu\u0000ne", "teacher": 900403, "schedules": []}
HTTP 422
[Asserts]
jsonpath "$.detail" == "city must not contain a NUL byte"
