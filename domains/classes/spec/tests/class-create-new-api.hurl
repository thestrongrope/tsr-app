# POST /classes on the NEW API only (skipped on PHP, which stores a NUL byte; PostgreSQL text cannot): a NUL byte in a text field is a 422, never a server error.
POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
{"gender": 1, "levelId": 3, "location": "Hall\u0000", "city": "Pune", "country": "India", "teacher": 900404, "schedules": [{"day": 1, "hour": 5, "minute": 0, "timezone": "Asia/Kolkata"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "location must not contain a NUL byte"
