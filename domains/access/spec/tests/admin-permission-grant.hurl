# POST /admin/permissions/members/{token}/grants {permission, reason} contract: a super admin gives a member one named permission. Runs against any implementation.
# Variables: base_url and auth_grants_<token> (tools/contract-grants.sh). Fixtures: db/synthetic/grants-fixtures.sql (read its header). This file changes members 925021 (grant and duplicate),
# 925023 (takes effect at once, then revoked), 925024 (the reasons) and 925002 (a super admin grants themselves); no other file writes them. 925011 is a super admin used as a target of refusals only.
# PHP's order: sign-in, permissions:manage, permission text (422), reason type (422), then the model: the reason 1 to 300 characters (422), the member (404), grantable (422) or held (409).

# 1. Without sign-in: 401
POST {{base_url}}/admin/permissions/members/925021/grants
{"permission": "api-docs:read:all", "reason": "Need it"}
HTTP 401

# 2. Everyone but a super admin: 403, nothing written
POST {{base_url}}/admin/permissions/members/925021/grants
Authorization: {{auth_grants_925003}}
{"permission": "api-docs:read:all", "reason": "Need it"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can manage permissions"

POST {{base_url}}/admin/permissions/members/925021/grants
Authorization: {{auth_grants_925004}}
{"permission": "api-docs:read:all", "reason": "Need it"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can manage permissions"

POST {{base_url}}/admin/permissions/members/925021/grants
Authorization: {{auth_grants_925006}}
{"permission": "api-docs:read:all", "reason": "Need it"}
HTTP 403

POST {{base_url}}/admin/permissions/members/925021/grants
Authorization: {{auth_grants_925007}}
{"permission": "api-docs:read:all", "reason": "Need it"}
HTTP 403

POST {{base_url}}/admin/permissions/members/925021/grants
Authorization: {{auth_grants_925008}}
{"permission": "api-docs:read:all", "reason": "Need it"}
HTTP 403

POST {{base_url}}/admin/permissions/members/925021/grants
Authorization: {{auth_grants_925010}}
{"permission": "api-docs:read:all", "reason": "Need it"}
HTTP 403

GET {{base_url}}/admin/permissions/members/925021
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.granted" count == 0

# 3. The permission: required text
POST {{base_url}}/admin/permissions/members/925021/grants
Authorization: {{auth_grants_925001}}
{"reason": "Need it"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "permission is required"

POST {{base_url}}/admin/permissions/members/925021/grants
Authorization: {{auth_grants_925001}}
{"permission": "", "reason": "Need it"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "permission is required"

POST {{base_url}}/admin/permissions/members/925021/grants
Authorization: {{auth_grants_925001}}
{"permission": 5, "reason": "Need it"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "permission is required"

POST {{base_url}}/admin/permissions/members/925021/grants
Authorization: {{auth_grants_925001}}
{"permission": ["api-docs:read:all"], "reason": "Need it"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "permission is required"

# 4. The reason: text of 1 to 300 characters after trimming; the type is checked before the length, both before the member
POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "api-docs:read:all"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A reason is required"

POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "api-docs:read:all", "reason": null}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A reason is required"

POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "api-docs:read:all", "reason": "   "}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A reason is required"

POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "api-docs:read:all", "reason": 12}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason must be text"

POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "api-docs:read:all", "reason": ["x"]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason must be text"

POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "api-docs:read:all", "reason": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The reason must be 300 characters or fewer"

POST {{base_url}}/admin/permissions/members/99999999/grants
Authorization: {{auth_grants_925001}}
{"permission": "api-docs:read:all"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A reason is required"

# 5. The member: a guest, a negative, a text and an unknown token are 404 (after the reason, before grantable)
POST {{base_url}}/admin/permissions/members/0/grants
Authorization: {{auth_grants_925001}}
{"permission": "api-docs:read:all", "reason": "Need it"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Member not found"

POST {{base_url}}/admin/permissions/members/-7/grants
Authorization: {{auth_grants_925001}}
{"permission": "api-docs:read:all", "reason": "Need it"}
HTTP 404

POST {{base_url}}/admin/permissions/members/abc/grants
Authorization: {{auth_grants_925001}}
{"permission": "api-docs:read:all", "reason": "Need it"}
HTTP 404

POST {{base_url}}/admin/permissions/members/99999999/grants
Authorization: {{auth_grants_925001}}
{"permission": "nope:nothing:all", "reason": "Need it"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Member not found"

POST {{base_url}}/admin/permissions/members/99999999999999999999/grants
Authorization: {{auth_grants_925001}}
{"permission": "api-docs:read:all", "reason": "Need it"}
HTTP 404

# 6. What can never be granted: the three excluded names, any scope but all, an unknown name, text that is no name at all: 422 "That permission cannot be granted"
POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "permissions:manage:all", "reason": "Make me an admin"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "That permission cannot be granted"

POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "class-access:manage:all", "reason": "Make me an admin"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "That permission cannot be granted"

POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "members:enrol-by-token:all", "reason": "Make me an admin"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "That permission cannot be granted"

POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "class-access:manage:gender", "reason": "Make me a gender admin"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "That permission cannot be granted"

POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "classes:read:assigned", "reason": "Scope that is computed"}
HTTP 422

POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "classes:read", "reason": "No scope"}
HTTP 422

POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "nope:nothing:all", "reason": "Unknown"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "That permission cannot be granted"

POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "API-DOCS:READ:ALL", "reason": "Wrong case"}
HTTP 422

POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": " api-docs:read:all", "reason": "Padded"}
HTTP 422

POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "../../etc/passwd:all", "reason": "Path-like"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "That permission cannot be granted"

POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "reason": "Very long"}
HTTP 422

POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "api-docs:read:all' OR '1'='1", "reason": "Quote"}
HTTP 422

# 7. What the member already holds is 409, even for an excluded name: by role (a super admin) and by the member set (a plain member)
POST {{base_url}}/admin/permissions/members/925011/grants
Authorization: {{auth_grants_925001}}
{"permission": "permissions:manage:all", "reason": "Already theirs"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "The member already holds that permission"

POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "content:read:all", "reason": "Everyone has it"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "The member already holds that permission"

POST {{base_url}}/admin/permissions/members/925010/grants
Authorization: {{auth_grants_925001}}
{"permission": "standard-mcqs:update:all", "reason": "Held by a live grant"}
HTTP 409

# 8. Nothing above wrote a grant
GET {{base_url}}/admin/permissions/members/925024
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.granted" count == 0

# 9. A grant: 200 with the refreshed member view; the reason is stored trimmed; the grantor is the operator
POST {{base_url}}/admin/permissions/members/925021/grants
Authorization: {{auth_grants_925001}}
{"permission": "api-docs:read:all", "reason": "   Need the docs  "}
HTTP 200
[Asserts]
jsonpath "$.*" count == 4
jsonpath "$.member.token" == 925021
jsonpath "$.granted" count == 1
jsonpath "$.granted[0].name" == "api-docs:read:all"
jsonpath "$.granted[0].reason" == "Need the docs"
jsonpath "$.granted[0].grantedBy" == "Gr Member 925001"
jsonpath "$.granted[0].reach" == "In every class and for every member"
jsonpath "$.grantable[?(@.name=='api-docs:read:all')]" not exists
jsonpath "$.grantable[?(@.name=='donors:read:all')]" exists

# 10. The same grant again: 409, still one row
POST {{base_url}}/admin/permissions/members/925021/grants
Authorization: {{auth_grants_925001}}
{"permission": "api-docs:read:all", "reason": "Again"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "The member already holds that permission"

GET {{base_url}}/admin/permissions/members/925021
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.granted" count == 1

# 11. A reason of exactly 300 characters is accepted
POST {{base_url}}/admin/permissions/members/925024/grants
Authorization: {{auth_grants_925001}}
{"permission": "api-docs:read:all", "reason": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
HTTP 200
[Asserts]
jsonpath "$.granted[0].reason" == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

# 12. At once: the grant shows in the member's own permissions on their very next request, and a revoke removes it on the next one
GET {{base_url}}/me/permissions
Authorization: {{auth_grants_925023}}
HTTP 200
[Asserts]
jsonpath "$.permissions" not contains "api-docs:read:all"

POST {{base_url}}/admin/permissions/members/925023/grants
Authorization: {{auth_grants_925001}}
{"permission": "api-docs:read:all", "reason": "Effect at once"}
HTTP 200
[Captures]
effect_grant_id: jsonpath "$.granted[0].id"

GET {{base_url}}/me/permissions
Authorization: {{auth_grants_925023}}
HTTP 200
[Asserts]
jsonpath "$.permissions" contains "api-docs:read:all"

GET {{base_url}}/me/permissions/api-docs:read
Authorization: {{auth_grants_925023}}
HTTP 200
[Asserts]
jsonpath "$.scopes" contains "all"

POST {{base_url}}/admin/permissions/grants/{{effect_grant_id}}/revoke
Authorization: {{auth_grants_925001}}
{"reason": "Effect at once, over"}
HTTP 200

GET {{base_url}}/me/permissions
Authorization: {{auth_grants_925023}}
HTTP 200
[Asserts]
jsonpath "$.permissions" not contains "api-docs:read:all"

GET {{base_url}}/me/permissions/api-docs:read
Authorization: {{auth_grants_925023}}
HTTP 200
[Asserts]
jsonpath "$.scopes" count == 0

# 13. A super admin grants themselves a permission no role gives (PHP has no self guard here: finding 10), and the member who holds it can use it; then revokes it
POST {{base_url}}/admin/permissions/members/925002/grants
Authorization: {{auth_grants_925002}}
{"permission": "quiz:admin:all", "reason": "Self grant"}
HTTP 200
[Asserts]
jsonpath "$.member.token" == 925002
jsonpath "$.granted[0].name" == "quiz:admin:all"
jsonpath "$.granted[0].grantedBy" == "Gr Member 925002"
[Captures]
self_grant_id: jsonpath "$.granted[0].id"

GET {{base_url}}/me/permissions
Authorization: {{auth_grants_925002}}
HTTP 200
[Asserts]
jsonpath "$.permissions" contains "quiz:admin:all"

POST {{base_url}}/admin/permissions/grants/{{self_grant_id}}/revoke
Authorization: {{auth_grants_925002}}
{"reason": "Self grant, over"}
HTTP 200
