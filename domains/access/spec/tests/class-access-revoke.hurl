# POST /admin/class-access/rules/{id}/revoke {reason, version} contract: an operator takes a class access rule away; the rule stays, with who removed it and why. Runs against any implementation.
# Variables: base_url and auth_grants_<token> (tools/contract-grants.sh). Fixtures: db/synthetic/grants-fixtures.sql (read its header). This file changes 925042 (rules 9750021 and 9750022 live, 9750024 already revoked; role 5)
# and 925005 (a second gents admin, role 3: rules 9750051 and 9750052). 925051 (gents) holds a ladies rule 9750041 and a rule of either gender 9750042, 925052 (ladies) a ladies rule 9750043, 925050 a gents rule 9750031 and
# a ladies rule 9750032: they are only refused here and never changed.
# PHP's order: sign-in, class-access:manage, reason text and version required (422), then the model: the reason 1 to 300 characters (422), the rule and its member (404), the operator guards (own access 422,
# rule gender 403, member gender 403), already removed (409), then under the member lock: the guards again, the version (409 member_changed), the update.

# 1. Without sign-in: 401. Who may not use the screen: 403
POST {{base_url}}/admin/class-access/rules/9750021/revoke
{"reason": "Done", "version": "x"}
HTTP 401

POST {{base_url}}/admin/class-access/rules/9750021/revoke
Authorization: {{auth_grants_925006}}
{"reason": "Done", "version": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/admin/class-access/rules/9750021/revoke
Authorization: {{auth_grants_925008}}
{"reason": "Done", "version": "x"}
HTTP 403

POST {{base_url}}/admin/class-access/rules/9750021/revoke
Authorization: {{auth_grants_925010}}
{"reason": "Done", "version": "x"}
HTTP 403

# 2. The body: reason text, then version required; then the reason's length
POST {{base_url}}/admin/class-access/rules/9750021/revoke
Authorization: {{auth_grants_925003}}
{"reason": 5, "version": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason must be text"

POST {{base_url}}/admin/class-access/rules/9750021/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Done"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "version is required"

POST {{base_url}}/admin/class-access/rules/9750021/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Done", "version": ""}
HTTP 422
[Asserts]
jsonpath "$.detail" == "version is required"

POST {{base_url}}/admin/class-access/rules/9750021/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Done", "version": 3}
HTTP 422
[Asserts]
jsonpath "$.detail" == "version is required"

POST {{base_url}}/admin/class-access/rules/9750021/revoke
Authorization: {{auth_grants_925003}}
{"version": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A reason is required"

POST {{base_url}}/admin/class-access/rules/9750021/revoke
Authorization: {{auth_grants_925003}}
{"reason": "   ", "version": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A reason is required"

POST {{base_url}}/admin/class-access/rules/9750021/revoke
Authorization: {{auth_grants_925003}}
{"reason": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "version": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The reason must be 300 characters or fewer"

POST {{base_url}}/admin/class-access/rules/99999999/revoke
Authorization: {{auth_grants_925003}}
{"reason": "   ", "version": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A reason is required"

# 3. No such rule: unknown, zero, negative, text and huge ids are 404
POST {{base_url}}/admin/class-access/rules/99999999/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Done", "version": "x"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Rule not found"

POST {{base_url}}/admin/class-access/rules/0/revoke
Authorization: {{auth_grants_925001}}
{"reason": "Done", "version": "x"}
HTTP 404

POST {{base_url}}/admin/class-access/rules/-1/revoke
Authorization: {{auth_grants_925001}}
{"reason": "Done", "version": "x"}
HTTP 404

POST {{base_url}}/admin/class-access/rules/abc/revoke
Authorization: {{auth_grants_925001}}
{"reason": "Done", "version": "x"}
HTTP 404

POST {{base_url}}/admin/class-access/rules/99999999999999999999/revoke
Authorization: {{auth_grants_925001}}
{"reason": "Done", "version": "x"}
HTTP 404

# 4. A rule outside the operator's reach: 403 and nothing changes. A gents admin and a ladies rule on a gents member, a rule of either gender, a ladies rule on a ladies member; a ladies admin and a gents rule or a gents member
POST {{base_url}}/admin/class-access/rules/9750041/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Done", "version": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This member belongs to the other gender"

POST {{base_url}}/admin/class-access/rules/9750042/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Done", "version": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This member belongs to the other gender"

POST {{base_url}}/admin/class-access/rules/9750043/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Done", "version": "x"}
HTTP 403

POST {{base_url}}/admin/class-access/rules/9750032/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Done", "version": "x"}
HTTP 403

POST {{base_url}}/admin/class-access/rules/9750041/revoke
Authorization: {{auth_grants_925004}}
{"reason": "Done", "version": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This member belongs to the other gender"

POST {{base_url}}/admin/class-access/rules/9750031/revoke
Authorization: {{auth_grants_925004}}
{"reason": "Done", "version": "x"}
HTTP 403

POST {{base_url}}/admin/class-access/rules/9750042/revoke
Authorization: {{auth_grants_925004}}
{"reason": "Done", "version": "x"}
HTTP 403

POST {{base_url}}/admin/class-access/rules/9750021/revoke
Authorization: {{auth_grants_925004}}
{"reason": "Done", "version": "x"}
HTTP 403

GET {{base_url}}/admin/class-access/members/925051
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.rules" count == 2

# 5. Your own access: 422 for a gents admin who holds a rule themselves (a second gents admin, 925005), nothing changes
POST {{base_url}}/admin/class-access/rules/9750051/revoke
Authorization: {{auth_grants_925005}}
{"reason": "Remove my own rule", "version": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "You cannot change your own access"

# 6. An already removed rule: 409 (the guards pass for a gents admin on a gents member)
POST {{base_url}}/admin/class-access/rules/9750024/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Done", "version": "x"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "That access was already removed"

# 7. The version a client saw is not the member's now: 409 member_changed, nothing removed
GET {{base_url}}/admin/class-access/members/925042
Authorization: {{auth_grants_925003}}
HTTP 200
[Asserts]
jsonpath "$.rules" count == 2
jsonpath "$.version" matches "^5:[0-9a-f]{16}$"
[Captures]
vA: jsonpath "$.version"

POST {{base_url}}/admin/class-access/rules/9750021/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Done", "version": "5:0000000000000000"}
HTTP 409
[Asserts]
jsonpath "$.code" == "member_changed"
jsonpath "$.detail" == "This member was just changed by someone else. Open them again to see the current access."

# 8. Revoke one of two rules: 200 {saved: true}, the refreshed view without it; the member stays a class admin (role 5); the old version is stale
POST {{base_url}}/admin/class-access/rules/9750021/revoke
Authorization: {{auth_grants_925003}}
{"reason": "  Moved to another city  ", "version": "{{vA}}"}
HTTP 200
[Asserts]
jsonpath "$.*" count == 5
jsonpath "$.saved" == true
jsonpath "$.member.token" == 925042
jsonpath "$.rules" count == 1
jsonpath "$.rules[0].id" == 9750022
jsonpath "$.rules[0].note" == "Gents, level 2, Grland"
jsonpath "$.rules[0].conditions" count == 2
jsonpath "$.rules[0].classCount" == 2
jsonpath "$.version" matches "^5:[0-9a-f]{16}$"
jsonpath "$.version" != "{{vA}}"
[Captures]
vB: jsonpath "$.version"

POST {{base_url}}/admin/class-access/rules/9750022/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Stale", "version": "{{vA}}"}
HTTP 409
[Asserts]
jsonpath "$.code" == "member_changed"

POST {{base_url}}/admin/class-access/rules/9750021/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Again", "version": "{{vB}}"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "That access was already removed"

GET {{base_url}}/user/permissions
Authorization: {{auth_grants_925042}}
HTTP 200
[Asserts]
jsonpath "$.role_id" == 5

# 9. Revoke the last rule: the member is back to role 0 (the version starts with 0) on their very next request
POST {{base_url}}/admin/class-access/rules/9750022/revoke
Authorization: {{auth_grants_925003}}
{"reason": "No longer a coordinator", "version": "{{vB}}"}
HTTP 200
[Asserts]
jsonpath "$.saved" == true
jsonpath "$.rules" count == 0
jsonpath "$.version" matches "^0:[0-9a-f]{16}$"

GET {{base_url}}/user/permissions
Authorization: {{auth_grants_925042}}
HTTP 200
[Asserts]
jsonpath "$.role_id" == 0

POST {{base_url}}/admin/class-access/rules/9750022/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Again", "version": "x"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "That access was already removed"

# 10. A gents admin removes a rule of ANOTHER gents admin (equal rank): allowed, the only self guard is the operator's own token (finding 11). The other admin keeps their role 3
GET {{base_url}}/admin/class-access/members/925005
Authorization: {{auth_grants_925003}}
HTTP 200
[Asserts]
jsonpath "$.rules" count == 2
jsonpath "$.version" matches "^3:[0-9a-f]{16}$"
jsonpath "$.fromRole" == "Classes of their own gender"
[Captures]
vC: jsonpath "$.version"

POST {{base_url}}/admin/class-access/rules/9750052/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Peer rule removed", "version": "{{vC}}"}
HTTP 200
[Asserts]
jsonpath "$.saved" == true
jsonpath "$.member.token" == 925005
jsonpath "$.rules" count == 1
jsonpath "$.rules[0].id" == 9750051
jsonpath "$.version" matches "^3:[0-9a-f]{16}$"

GET {{base_url}}/user/permissions
Authorization: {{auth_grants_925005}}
HTTP 200
[Asserts]
jsonpath "$.role_id" == 3
