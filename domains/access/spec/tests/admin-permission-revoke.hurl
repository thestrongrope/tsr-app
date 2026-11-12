# POST /admin/permissions/grants/{id}/revoke {reason} contract: a super admin takes a named grant away; the row stays. Runs against any implementation.
# Variables: base_url and auth_grants_<token> (tools/contract-grants.sh). Fixtures: db/synthetic/grants-fixtures.sql (read its header). This file changes member 925022 only: grants 9750011 (api-docs:read:all)
# and 9750013 (standard-mcqs:update:all) are live, 9750012 (summary-report:read:all) is already revoked. 925010's grant 9750001 is only read here (a refusal never changes it).
# PHP's order: sign-in, permissions:manage, reason type (422), the reason 1 to 300 characters (422), the grant (404), already revoked (409).

# 1. Without sign-in: 401
POST {{base_url}}/admin/permissions/grants/9750011/revoke
{"reason": "Done"}
HTTP 401

# 2. Everyone but a super admin: 403, the grant stays
POST {{base_url}}/admin/permissions/grants/9750011/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Done"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can manage permissions"

POST {{base_url}}/admin/permissions/grants/9750011/revoke
Authorization: {{auth_grants_925004}}
{"reason": "Done"}
HTTP 403

POST {{base_url}}/admin/permissions/grants/9750011/revoke
Authorization: {{auth_grants_925006}}
{"reason": "Done"}
HTTP 403

POST {{base_url}}/admin/permissions/grants/9750011/revoke
Authorization: {{auth_grants_925007}}
{"reason": "Done"}
HTTP 403

POST {{base_url}}/admin/permissions/grants/9750011/revoke
Authorization: {{auth_grants_925008}}
{"reason": "Done"}
HTTP 403

POST {{base_url}}/admin/permissions/grants/9750001/revoke
Authorization: {{auth_grants_925010}}
{"reason": "Revoke my own grant"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can manage permissions"

GET {{base_url}}/admin/permissions/members/925022
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.granted" count == 2

# 3. The reason: text, then 1 to 300 characters, both before the grant is looked up
POST {{base_url}}/admin/permissions/grants/9750011/revoke
Authorization: {{auth_grants_925011}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A reason is required"

POST {{base_url}}/admin/permissions/grants/9750011/revoke
Authorization: {{auth_grants_925011}}
{"reason": "  "}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A reason is required"

POST {{base_url}}/admin/permissions/grants/9750011/revoke
Authorization: {{auth_grants_925011}}
{"reason": 7}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason must be text"

POST {{base_url}}/admin/permissions/grants/9750011/revoke
Authorization: {{auth_grants_925011}}
{"reason": {"a": 1}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason must be text"

POST {{base_url}}/admin/permissions/grants/9750011/revoke
Authorization: {{auth_grants_925011}}
{"reason": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The reason must be 300 characters or fewer"

POST {{base_url}}/admin/permissions/grants/99999999/revoke
Authorization: {{auth_grants_925011}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A reason is required"

# 4. No such grant: unknown, negative, zero, text and huge ids are 404
POST {{base_url}}/admin/permissions/grants/99999999/revoke
Authorization: {{auth_grants_925011}}
{"reason": "Done"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Grant not found"

POST {{base_url}}/admin/permissions/grants/-3/revoke
Authorization: {{auth_grants_925011}}
{"reason": "Done"}
HTTP 404

POST {{base_url}}/admin/permissions/grants/0/revoke
Authorization: {{auth_grants_925011}}
{"reason": "Done"}
HTTP 404

POST {{base_url}}/admin/permissions/grants/abc/revoke
Authorization: {{auth_grants_925011}}
{"reason": "Done"}
HTTP 404

POST {{base_url}}/admin/permissions/grants/99999999999999999999/revoke
Authorization: {{auth_grants_925011}}
{"reason": "Done"}
HTTP 404

# 5. An already revoked grant: 409
POST {{base_url}}/admin/permissions/grants/9750012/revoke
Authorization: {{auth_grants_925011}}
{"reason": "Done"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "That grant is already revoked"

# 6. Revoke one grant: 200 with the member's refreshed view; the other grant stays; the revoked permission is grantable again
POST {{base_url}}/admin/permissions/grants/9750011/revoke
Authorization: {{auth_grants_925011}}
{"reason": "  No longer needed  "}
HTTP 200
[Asserts]
jsonpath "$.*" count == 4
jsonpath "$.member.token" == 925022
jsonpath "$.member.name" == "Gr Member 925022"
jsonpath "$.granted" count == 1
jsonpath "$.granted[0].id" == 9750013
jsonpath "$.granted[0].name" == "standard-mcqs:update:all"
jsonpath "$.grantable[?(@.name=='api-docs:read:all')]" exists
jsonpath "$.grantable[?(@.name=='standard-mcqs:update:all')]" not exists

# 7. The same grant again: 409, and the member view is unchanged
POST {{base_url}}/admin/permissions/grants/9750011/revoke
Authorization: {{auth_grants_925011}}
{"reason": "Again"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "That grant is already revoked"

# 8. The last one: the member holds no named grant
POST {{base_url}}/admin/permissions/grants/9750013/revoke
Authorization: {{auth_grants_925001}}
{"reason": "Last one"}
HTTP 200
[Asserts]
jsonpath "$.granted" count == 0
jsonpath "$.grantable[?(@.name=='standard-mcqs:update:all')]" exists

GET {{base_url}}/admin/permissions/members/925022
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.granted" count == 0
