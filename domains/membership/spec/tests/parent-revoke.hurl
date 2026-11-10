# DELETE /me/parents/{parent_token} contract: one file per slice, runs against any implementation.
# Variables: base_url and auth_<alias>. Synthetic members only. It revokes a link: tools/membership-contract.sh resets it first.

# 1. Without sign-in: 401
DELETE {{base_url}}/me/parents/900262
HTTP 401

# 2. A parent that is not linked, or a token that is not a number: 404
DELETE {{base_url}}/me/parents/12345
Authorization: {{auth_prevoke_child}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Active parent link not found"

DELETE {{base_url}}/me/parents/abc
Authorization: {{auth_prevoke_child}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Active parent link not found"

# 3. Another child's parent is not this child's: 404, and the link stays
DELETE {{base_url}}/me/parents/900211
Authorization: {{auth_prevoke_child}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Active parent link not found"

GET {{base_url}}/me/parents
Authorization: {{auth_prevoke_child}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].parent_token" == 900262
jsonpath "$[0].relationship" == "guardian"

# 4. The child removes their parent: 204, and the list is empty
DELETE {{base_url}}/me/parents/900262
Authorization: {{auth_prevoke_child}}
HTTP 204
[Asserts]
body == ""

GET {{base_url}}/me/parents
Authorization: {{auth_prevoke_child}}
HTTP 200
[Asserts]
body == "[]"

# 5. Removing again: 404
DELETE {{base_url}}/me/parents/900262
Authorization: {{auth_prevoke_child}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Active parent link not found"
