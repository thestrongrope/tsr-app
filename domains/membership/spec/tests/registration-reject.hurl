# POST /registrations/{registration_id}/reject contract: turn a waiting registrant down. Variables: base_url and auth_<alias>.
# Fixtures: registrant 901161 (rows 951301 and 951302; 951302 is the latest, so it is the registration a member answers to), 901162 (951303, validation only), 901163 (951304, already rejected),
# 901164 (951305, in a live class), 901165 (951306, ladies), 901166 (951307, email at thestrongrope.com). 901108 is a super admin, 901109 a gents admin (role 3: may read gents registrations, may not reject).

# 1. Without sign-in: 401
POST {{base_url}}/registrations/951302/reject
{"reason": "x"}
HTTP 401

# 2. A member who may read no registrations: 403, before the id is looked up
POST {{base_url}}/registrations/999999999/reject
Authorization: {{auth_b4b_plain}}
{"reason": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. A gents admin may read a gents registrant but not reject one; a ladies registrant is out of their reach altogether: 403 both
POST {{base_url}}/registrations/951303/reject
Authorization: {{auth_b4b_gents_admin}}
{"reason": "x"}
HTTP 403

POST {{base_url}}/registrations/951306/reject
Authorization: {{auth_b4b_gents_admin}}
{"reason": "x"}
HTTP 403

# 4. Nobody waiting under that id: 409 (unknown, not the member's latest row, already rejected, placed in a class, a placeholder email)
POST {{base_url}}/registrations/999999999/reject
Authorization: {{auth_b4b_reject_admin}}
{"reason": "x"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "This registrant is no longer waiting: they have been placed or rejected."

POST {{base_url}}/registrations/951301/reject
Authorization: {{auth_b4b_reject_admin}}
{"reason": "x"}
HTTP 409

POST {{base_url}}/registrations/951304/reject
Authorization: {{auth_b4b_reject_admin}}
{"reason": "x"}
HTTP 409

POST {{base_url}}/registrations/951305/reject
Authorization: {{auth_b4b_reject_admin}}
{"reason": "x"}
HTTP 409

POST {{base_url}}/registrations/951307/reject
Authorization: {{auth_b4b_reject_admin}}
{"reason": "x"}
HTTP 409

# 5. The reason is required, a string, at most 500 characters
POST {{base_url}}/registrations/951303/reject
Authorization: {{auth_b4b_reject_admin}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason is required, at most 500 characters"

POST {{base_url}}/registrations/951303/reject
Authorization: {{auth_b4b_reject_admin}}
{"reason": "   "}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason is required, at most 500 characters"

POST {{base_url}}/registrations/951303/reject
Authorization: {{auth_b4b_reject_admin}}
{"reason": 123}
HTTP 422

POST {{base_url}}/registrations/951303/reject
Authorization: {{auth_b4b_reject_admin}}
{"reason": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason is required, at most 500 characters"

POST {{base_url}}/registrations/951303/reject
Authorization: {{auth_b4b_reject_admin}}
Content-Type: application/json
`not json`
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

# 6. A super admin rejects the member's latest registration: 200; every row of the member is rejected, so the earlier row no longer waits either
POST {{base_url}}/registrations/951302/reject
Authorization: {{auth_b4b_reject_admin}}
{"reason": "  too far away  "}
HTTP 200
[Asserts]
jsonpath "$.rejected" == true
jsonpath "$.registrationId" == 951302

POST {{base_url}}/registrations/951302/reject
Authorization: {{auth_b4b_reject_admin}}
{"reason": "again"}
HTTP 409

POST {{base_url}}/registrations/951301/reject
Authorization: {{auth_b4b_reject_admin}}
{"reason": "again"}
HTTP 409
