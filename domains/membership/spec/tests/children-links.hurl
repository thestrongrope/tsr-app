# GET /me/children/links contract: one file per slice, runs against any implementation.
# Variables: base_url and auth_<alias>. Synthetic members only. tools/membership-contract.sh resets the fixtures and runs it.
# Ids differ per side, so they are only checked as numbers; the two rows share a created_at, so rows are picked by child_token.

# 1. Without sign-in: 401
GET {{base_url}}/me/children/links
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A parent sees every link of their own, active and revoked, with PHP's raw row (keys, null rules, "Y-m-d H:i:s" dates)
GET {{base_url}}/me/children/links
Authorization: {{auth_parent_one}}
HTTP 200
[Asserts]
jsonpath "$" count == 2
jsonpath "$[?(@.child_token==900212)].id" isInteger
jsonpath "$[?(@.child_token==900212)].parent_token" == 900211
jsonpath "$[?(@.child_token==900212)].child_name" == "Synthetic Child Active"
jsonpath "$[?(@.child_token==900212)].relationship" == "father"
jsonpath "$[?(@.child_token==900212)].status" == "active"
jsonpath "$[?(@.child_token==900212)].source" == "token_entry"
jsonpath "$[?(@.child_token==900212)].created_at" == "2026-01-10 09:00:00"
jsonpath "$[?(@.child_token==900212)].created_by_name" == "Synthetic Parent One"
jsonpath "$[?(@.child_token==900212)].activated_at" == "2026-01-10 09:00:00"
jsonpath "$[?(@.child_token==900212)].revoked_at" == null
jsonpath "$[?(@.child_token==900213)].child_name" == "Synthetic Child Revoked"
jsonpath "$[?(@.child_token==900213)].relationship" == "mother"
jsonpath "$[?(@.child_token==900213)].status" == "revoked"
jsonpath "$[?(@.child_token==900213)].revoked_at" == "2026-01-11 09:00:00"
jsonpath "$[0].id" isInteger

# 3. A member with no links gets an empty list, never someone else's
GET {{base_url}}/me/children/links
Authorization: {{auth_gender_two}}
HTTP 200
[Asserts]
body == "[]"

# 4. The child's invite or link is not the child's list: a child with a parent has no children
GET {{base_url}}/me/children/links
Authorization: {{auth_child_active}}
HTTP 200
[Asserts]
body == "[]"
