# DELETE /me/children/{child_token}/link contract: one file per slice, runs against any implementation.
# Variables: base_url and auth_<alias>. Synthetic members only. It revokes a link: tools/membership-contract.sh resets it first.

# 1. Without sign-in: 401
DELETE {{base_url}}/me/children/900252/link
HTTP 401

# 2. A link that is not there: 404 (an unknown token, a token that is not a number, which PHP reads as 0)
DELETE {{base_url}}/me/children/12345/link
Authorization: {{auth_revoke_parent}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Active link not found"

DELETE {{base_url}}/me/children/abc/link
Authorization: {{auth_revoke_parent}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Active link not found"

# 3. Someone else's link is not the caller's: 404 and it stays active
DELETE {{base_url}}/me/children/900252/link
Authorization: {{auth_parent_one}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Active link not found"

# 4. The parent ends their own link: 204 with no body
DELETE {{base_url}}/me/children/900252/link
Authorization: {{auth_revoke_parent}}
HTTP 204
[Asserts]
body == ""

GET {{base_url}}/me/children/links
Authorization: {{auth_revoke_parent}}
HTTP 200
[Asserts]
jsonpath "$[?(@.child_token==900252)].status" == "revoked"
jsonpath "$[?(@.child_token==900252)].revoked_at" matches /^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/

# 5. Ending it again: 404
DELETE {{base_url}}/me/children/900252/link
Authorization: {{auth_revoke_parent}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Active link not found"
