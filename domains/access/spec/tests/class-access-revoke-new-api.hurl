# POST /admin/class-access/rules/{id}/revoke, new API only: stricter than PHP (decision of 12 Nov 2026). Two refusals, both 403 "You do not have permission to do that", and nothing changes:
# (1) an operator who is not a super admin may not remove a rule from a super admin or a gender admin; (2) a rule is removed only by the operator who granted it or by a super admin.
# PHP allows both: see class-access-revoke-php-only.hurl.
# Variables: base_url and auth_grants_<token> (tools/contract-grants.sh). Fixtures: db/synthetic/grants-fixtures.sql. Every request here is refused. Rules 9750051 and 9750052 sit on 925005 (a gents admin, role 3);
# 9750031 on 925050 (a class admin, role 5), all granted by the super admin 925001.

# 1. A gents admin and a rule on another gents admin (the gender guards pass; the role of the member refuses)
POST {{base_url}}/admin/class-access/rules/9750052/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Peer rule", "version": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. A gents admin, a plain class admin's rule that a super admin granted: refused, the operator did not grant it
POST {{base_url}}/admin/class-access/rules/9750031/revoke
Authorization: {{auth_grants_925003}}
{"reason": "Not mine", "version": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/admin/class-access/members/925005
Authorization: {{auth_grants_925001}}
HTTP 200
[Asserts]
jsonpath "$.rules" count == 2
