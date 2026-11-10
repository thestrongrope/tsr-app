# GET /me/permissions/{permission}: the scopes one action is held in
# One file, run unchanged against the new API and PHP (tools/access-contract.sh dev|parity). Each fixture member
# signs in at that side's Auth emulator, then the whole answer is asserted: every permission in order and every
# scope, not only the status. Fixtures: one member per role, one with named grants, and the guest; none has any
# class relationship (the new API has no classes yet). Only synthetic .invalid emails (fixtures.vars, db/synthetic/seed.sql).
# The expected lists were captured from PHP (tsr-account develop) on the parity stack, then proven on the new API;
# where the two ever differ, PHP wins (docs/specs/initial-build/php-parity-feedback.md).


POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{member_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{member_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
member_token: jsonpath "$.idToken"

# member, feedback:create
GET {{base_url}}/me/permissions/feedback:create
Authorization: Bearer {{member_token}}
HTTP 200
[Asserts]
jsonpath "$.permission" == "feedback:create"
jsonpath "$.*" count == 2
jsonpath "$.scopes" count == 1
jsonpath "$.scopes[0]" == "self"

POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{superadmin_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{superadmin_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
superadmin_token: jsonpath "$.idToken"

# superadmin, classes:read
GET {{base_url}}/me/permissions/classes:read
Authorization: Bearer {{superadmin_token}}
HTTP 200
[Asserts]
jsonpath "$.permission" == "classes:read"
jsonpath "$.*" count == 2
jsonpath "$.scopes" count == 2
jsonpath "$.scopes[0]" == "all"
jsonpath "$.scopes[1]" == "enrolled"

POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{gentsadmin_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{gentsadmin_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
gentsadmin_token: jsonpath "$.idToken"

# gentsadmin, classes:read
GET {{base_url}}/me/permissions/classes:read
Authorization: Bearer {{gentsadmin_token}}
HTTP 200
[Asserts]
jsonpath "$.permission" == "classes:read"
jsonpath "$.*" count == 2
jsonpath "$.scopes" count == 2
jsonpath "$.scopes[0]" == "enrolled"
jsonpath "$.scopes[1]" == "gender"

POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{coordinator_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{coordinator_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
coordinator_token: jsonpath "$.idToken"

# coordinator, registrations:read
GET {{base_url}}/me/permissions/registrations:read
Authorization: Bearer {{coordinator_token}}
HTTP 200
[Asserts]
jsonpath "$.permission" == "registrations:read"
jsonpath "$.*" count == 2
jsonpath "$.scopes" count == 1
jsonpath "$.scopes[0]" == "assigned"

POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{granted_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{granted_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
granted_token: jsonpath "$.idToken"

# granted, standard-mcqs:update
GET {{base_url}}/me/permissions/standard-mcqs:update
Authorization: Bearer {{granted_token}}
HTTP 200
[Asserts]
jsonpath "$.permission" == "standard-mcqs:update"
jsonpath "$.*" count == 2
jsonpath "$.scopes" count == 1
jsonpath "$.scopes[0]" == "all"

# granted, summary-report:read
GET {{base_url}}/me/permissions/summary-report:read
Authorization: Bearer {{granted_token}}
HTTP 200
[Asserts]
jsonpath "$.permission" == "summary-report:read"
jsonpath "$.*" count == 2
jsonpath "$.scopes" count == 0

# member, feedback:review
GET {{base_url}}/me/permissions/feedback:review
Authorization: Bearer {{member_token}}
HTTP 200
[Asserts]
jsonpath "$.permission" == "feedback:review"
jsonpath "$.*" count == 2
jsonpath "$.scopes" count == 0

POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{finance_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{finance_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
finance_token: jsonpath "$.idToken"

# finance, donors:read
GET {{base_url}}/me/permissions/donors:read
Authorization: Bearer {{finance_token}}
HTTP 200
[Asserts]
jsonpath "$.permission" == "donors:read"
jsonpath "$.*" count == 2
jsonpath "$.scopes" count == 1
jsonpath "$.scopes[0]" == "all"

# The colon may arrive percent-encoded
GET {{base_url}}/me/permissions/feedback%3Acreate
Authorization: Bearer {{member_token}}
HTTP 200
[Asserts]
jsonpath "$.permission" == "feedback:create"
jsonpath "$.scopes[0]" == "self"

# A name the catalog lacks is 404; so is a full name with its scope (the path takes resource:action only)
GET {{base_url}}/me/permissions/nope:read
Authorization: Bearer {{member_token}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Unknown permission"

GET {{base_url}}/me/permissions/feedback:create:self
Authorization: Bearer {{member_token}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Unknown permission"

GET {{base_url}}/me/permissions/feedback:create
HTTP 401
[Asserts]
jsonpath "$.detail" == "Not authenticated"
