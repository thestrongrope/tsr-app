# GET /me/parents contract: one file per slice, runs against any implementation.
# Variables: base_url and auth_<alias>. Synthetic members only. tools/membership-contract.sh resets the fixtures and runs it.

# 1. Without sign-in: 401
GET {{base_url}}/me/parents
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A child sees their active parents, with the parent's name where a children list shows the child's
GET {{base_url}}/me/parents
Authorization: {{auth_child_active}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].id" isInteger
jsonpath "$[0].parent_token" == 900211
jsonpath "$[0].child_token" == 900212
jsonpath "$[0].parent_name" == "Synthetic Parent One"
jsonpath "$[0].child_name" not exists
jsonpath "$[0].relationship" == "father"
jsonpath "$[0].status" == "active"
jsonpath "$[0].source" == "token_entry"
jsonpath "$[0].created_at" == "2026-01-10 09:00:00"
jsonpath "$[0].created_by_name" == "Synthetic Parent One"
jsonpath "$[0].activated_at" == "2026-01-10 09:00:00"
jsonpath "$[0].revoked_at" == null

# 3. A child whose only link was revoked, and a member with none, get an empty list
GET {{base_url}}/me/parents
Authorization: {{auth_gender_two}}
HTTP 200
[Asserts]
body == "[]"
