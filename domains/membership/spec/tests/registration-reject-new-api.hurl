# POST /registrations/{registration_id}/reject: behaviour only the new API has. Variables: base_url and auth_<alias>.
# PostgreSQL text cannot hold a NUL byte; PHP stores it. The new API answers 422 instead of a server error (a recorded deviation). 951303 (member 901162) is only ever refused, never rejected.

POST {{base_url}}/registrations/951303/reject
Authorization: {{auth_b4b_reject_admin}}
Content-Type: application/json
{"reason": "a\u0000b"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason is required, at most 500 characters"
