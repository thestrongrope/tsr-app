# POST /members/{child_token}/parents contract: staff add an active parent link by token number. Variables: base_url and auth_<alias>.
# Fixtures: children 901141 (add), 901142 (parent 901151 already linked), 901143 (parent 901152 was removed by the child), 901144 (validation only), 901145 (ladies), 901146 (added by a gents admin); parents 901151 to 901155
# (901153 is held by two members); 901103 is a super admin, 901109 a gents admin (role 3). No file but this one changes these children.

# 1. Without sign-in: 401
POST {{base_url}}/members/901141/parents
{"parent_token": 901154, "relationship": "father"}
HTTP 401

# 2. Staff add a parent: 201; the relationship is trimmed and lower-cased
POST {{base_url}}/members/901141/parents
Authorization: {{auth_b4b_direct_admin}}
{"parent_token": 901154, "relationship": "  FATHER "}
HTTP 201
[Asserts]
jsonpath "$.id" isInteger
jsonpath "$.parent_token" == 901154
jsonpath "$.child_token" == 901141
jsonpath "$.relationship" == "father"
jsonpath "$.status" == "active"

# 3. The pair is now linked: adding it again is 409
POST {{base_url}}/members/901141/parents
Authorization: {{auth_b4b_direct_admin}}
{"parent_token": 901154, "relationship": "father"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "An active link already exists for this parent and child"

# 4. A pair linked in the fixtures: 409
POST {{base_url}}/members/901142/parents
Authorization: {{auth_b4b_direct_admin}}
{"parent_token": 901151, "relationship": "mother"}
HTTP 409

# 5. A parent the child removed returns when a super admin adds them
POST {{base_url}}/members/901143/parents
Authorization: {{auth_b4b_direct_admin}}
{"parent_token": 901152, "relationship": "guardian"}
HTTP 201
[Asserts]
jsonpath "$.relationship" == "guardian"

# 6. A gents admin adds a parent to a gents child (reach by gender)
POST {{base_url}}/members/901146/parents
Authorization: {{auth_b4b_gents_admin}}
{"parent_token": 901155, "relationship": "mother"}
HTTP 201
[Asserts]
jsonpath "$.child_token" == 901146

# 7. A gents admin for a ladies child: 404 (the permission is held, the child is out of reach); a member with no permission: 403
POST {{base_url}}/members/901145/parents
Authorization: {{auth_b4b_gents_admin}}
{"parent_token": 901155, "relationship": "mother"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Student not found"

POST {{base_url}}/members/901144/parents
Authorization: {{auth_b4b_plain}}
{"parent_token": 901155, "relationship": "mother"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 8. An unknown child: 404 for staff, with no early check of the token (a member with no permission gets 403 even for token 0)
POST {{base_url}}/members/999999999/parents
Authorization: {{auth_b4b_direct_admin}}
{"parent_token": 901155, "relationship": "mother"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Student not found"

POST {{base_url}}/members/0/parents
Authorization: {{auth_b4b_plain}}
{"parent_token": 901155, "relationship": "mother"}
HTTP 403

# 9. The body after the permission: not JSON is 422
POST {{base_url}}/members/901144/parents
Authorization: {{auth_b4b_direct_admin}}
Content-Type: application/json
`not json`
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

# 10. A parent who is unknown, a guest or missing: 404
POST {{base_url}}/members/901144/parents
Authorization: {{auth_b4b_direct_admin}}
{"parent_token": 999999999, "relationship": "mother"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Member or student not found"

POST {{base_url}}/members/901144/parents
Authorization: {{auth_b4b_direct_admin}}
{"relationship": "mother"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Member or student not found"

# 11. A parent token two members hold: 422 with a code
POST {{base_url}}/members/901144/parents
Authorization: {{auth_b4b_direct_admin}}
{"parent_token": 901153, "relationship": "mother"}
HTTP 422
[Asserts]
jsonpath "$.code" == "ambiguous_token"

# 12. A self link, the caller as the parent, an unknown relationship: the same 422
POST {{base_url}}/members/901144/parents
Authorization: {{auth_b4b_direct_admin}}
{"parent_token": 901144, "relationship": "mother"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid relationship or self-link not allowed"

POST {{base_url}}/members/901144/parents
Authorization: {{auth_b4b_direct_admin}}
{"parent_token": 901103, "relationship": "mother"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid relationship or self-link not allowed"

POST {{base_url}}/members/901144/parents
Authorization: {{auth_b4b_direct_admin}}
{"parent_token": 901155, "relationship": "uncle"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid relationship or self-link not allowed"
