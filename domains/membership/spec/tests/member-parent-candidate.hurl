# GET /members/{child_token}/parents/candidate/{parent_token} contract: the display name of a member, for staff to confirm before a direct add. Variables: base_url and auth_<alias>.
# PHP counts 30 lookups an hour per caller in a file that survives runs, so this file makes few counted calls: 901102 three, 901109 two (a call refused for the permission is not counted).
# Fixtures: child 901144 (gents), 901145 (ladies); parents 901151 (one member) and 901153 (a token two members hold); 901109 is a gents admin (role 3: reach by gender).

# 1. Without sign-in: 401
GET {{base_url}}/members/901144/parents/candidate/901151
HTTP 401

# 2. A member without parents:add-direct: 403 (not counted)
GET {{base_url}}/members/901144/parents/candidate/901151
Authorization: {{auth_b4b_plain}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. Staff in reach get the name and nothing else
GET {{base_url}}/members/901144/parents/candidate/901151
Authorization: {{auth_b4b_candidate_admin}}
HTTP 200
[Asserts]
jsonpath "$.name" == "B4B Member 901151"
jsonpath "$.email" not exists

# 4. A token two members hold: 422 with a code, told to staff in reach
GET {{base_url}}/members/901144/parents/candidate/901153
Authorization: {{auth_b4b_candidate_admin}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "More than one member has that token number. Please contact an admin."
jsonpath "$.code" == "ambiguous_token"

# 5. An unknown member: 404
GET {{base_url}}/members/901144/parents/candidate/999999999
Authorization: {{auth_b4b_candidate_admin}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Member not found"

# 6. A gents admin reaches a gents child by gender, and learns nothing about a ladies child's candidates: 404
GET {{base_url}}/members/901144/parents/candidate/901151
Authorization: {{auth_b4b_gents_admin}}
HTTP 200
[Asserts]
jsonpath "$.name" == "B4B Member 901151"

GET {{base_url}}/members/901145/parents/candidate/901153
Authorization: {{auth_b4b_gents_admin}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Member not found"
