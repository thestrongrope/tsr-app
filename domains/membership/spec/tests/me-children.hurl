# GET /me/children contract: the caller's active linked children with the classes they are in. Variables: base_url and auth_<alias>. Synthetic members only.
# tools/membership-contract.sh loads the B4b fixtures (parent 901121: children 901131 in a live and a closed class, 901132 in none, 901133 with gender Male, 901134 with a revoked link).

# 1. Without sign-in: 401
GET {{base_url}}/me/children
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A parent sees the active links in link order; revoked links and closed classes are left out
GET {{base_url}}/me/children
Authorization: {{auth_b4b_parent_kids}}
HTTP 200
[Asserts]
jsonpath "$" count == 3
jsonpath "$[0].token" == 901131
jsonpath "$[0].name" == "B4B Member 901131"
jsonpath "$[0].first_name" == "Kid"
jsonpath "$[0].last_name" == null
jsonpath "$[0].gender" == 1
jsonpath "$[0].relationship" == "father"
jsonpath "$[0].classes" count == 1
jsonpath "$[0].classes[0].class_id" == 9561
jsonpath "$[0].classes[0].class_name" == "B4B Gents Class"
jsonpath "$[0].classes[0].class_code" == "B4B-G-61"
jsonpath "$[0].classes[0].status" == "A"
jsonpath "$[1].token" == 901132
jsonpath "$[1].first_name" == null
jsonpath "$[1].relationship" == "mother"
jsonpath "$[1].classes" count == 0

# 3. A stored gender of the word Male is the number 0 here (PHP's (int) cast), not 1
GET {{base_url}}/me/children
Authorization: {{auth_b4b_parent_kids}}
HTTP 200
[Asserts]
jsonpath "$[2].token" == 901133
jsonpath "$[2].gender" == 0
jsonpath "$[2].relationship" == "guardian"

# 4. A member with no links gets an empty list
GET {{base_url}}/me/children
Authorization: {{auth_b4b_parent_none}}
HTTP 200
[Asserts]
body == "[]"
