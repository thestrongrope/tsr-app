# Sign-in contract: every refusal of PHP's api_authenticate(), and the successes.
# Lookup route: POST /feedback (never creates a member). Create route: POST /auth/link (creates one).
# One file, run unchanged against the new API and PHP. It signs in through the Firebase Auth emulator
# itself, so it needs, besides base_url:
#   emulator_url, project_id, emulator_password   written by the side's mint-token.sh (build/<side>/token.vars)
#   the fixture emails and link_token             domains/identity/spec/tests/fixtures.vars
# The fixture members (and, for the 2 hour deleted-account window, a refreshed row) are set up by
# tools/identity-contract.sh, which also runs this file. Commands: see that script and CLAUDE.md.
# Only synthetic .invalid emails. A token is never written into this file.

# 1. No Authorization header: 401 Not authenticated
POST {{base_url}}/feedback
Content-Type: application/json
{"clientId": "{{newUuid}}", "text": "salaam"}
HTTP 401
[Asserts]
jsonpath "$.detail" == "Not authenticated"

# 2. Not a Bearer header: 401 Not authenticated
POST {{base_url}}/feedback
Authorization: Basic abc
Content-Type: application/json
{"clientId": "{{newUuid}}", "text": "salaam"}
HTTP 401
[Asserts]
jsonpath "$.detail" == "Not authenticated"

# 3. A token that is no token: 401 Invalid auth token
POST {{base_url}}/feedback
Authorization: Bearer abc.def.ghi
Content-Type: application/json
{"clientId": "{{newUuid}}", "text": "salaam"}
HTTP 401
[Asserts]
jsonpath "$.detail" == "Invalid auth token"

# 4. A valid token with no email (an anonymous Firebase user): 401 Email not present in token
POST {{emulator_url}}/accounts:signUp?key=local
Content-Type: application/json
{"returnSecureToken": true}
HTTP 200
[Captures]
anonymous_token: jsonpath "$.idToken"

POST {{base_url}}/feedback
Authorization: Bearer {{anonymous_token}}
Content-Type: application/json
{"clientId": "{{newUuid}}", "text": "salaam"}
HTTP 401
[Asserts]
jsonpath "$.detail" == "Email not present in token"

# 5. Lookup route, a verified email with no member: 404 User not found, and nothing is created
POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
[Options]
variable: norow_email=norow-{{newUuid}}@example.invalid
{"email": "{{norow_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP 200

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{norow_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
norow_token: jsonpath "$.idToken"

POST {{base_url}}/feedback
Authorization: Bearer {{norow_token}}
Content-Type: application/json
{"clientId": "{{newUuid}}", "text": "salaam"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "User not found"

# 6. An UNVERIFIED email that matches a member cannot claim it: 404 on a lookup route and on a create route.
# (The emulator keeps this account unverified for its whole life: no case may create it verified.)
POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{unverified_email}}", "password": "{{emulator_password}}", "emailVerified": false}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{unverified_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
unverified_token: jsonpath "$.idToken"

POST {{base_url}}/feedback
Authorization: Bearer {{unverified_token}}
Content-Type: application/json
{"clientId": "{{newUuid}}", "text": "salaam"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "User not found"

POST {{base_url}}/auth/link
Authorization: Bearer {{unverified_token}}
Content-Length: 0
HTTP 404
[Asserts]
jsonpath "$.detail" == "User not found"

# 7. A guest row (token 0): 403 Registration incomplete, on both kinds of route
POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{guest_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{guest_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
guest_token: jsonpath "$.idToken"

POST {{base_url}}/feedback
Authorization: Bearer {{guest_token}}
Content-Type: application/json
{"clientId": "{{newUuid}}", "text": "salaam"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Registration incomplete"

POST {{base_url}}/auth/link
Authorization: Bearer {{guest_token}}
Content-Length: 0
HTTP 403
[Asserts]
jsonpath "$.detail" == "Registration incomplete"

# 8. A live account deletion: 403 Account deletion pending (with its status) off the allow list,
# but the allow-listed /auth/link still answers
POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{pending_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{pending_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
pending_token: jsonpath "$.idToken"

POST {{base_url}}/feedback
Authorization: Bearer {{pending_token}}
Content-Type: application/json
{"clientId": "{{newUuid}}", "text": "salaam"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Account deletion pending"
jsonpath "$.deletion_status" == "pending"

POST {{base_url}}/auth/link
Authorization: Bearer {{pending_token}}
Content-Length: 0
HTTP 200

# 9. Deleted a moment ago (inside 2 hours), signing in again on a create route: 403 with the deleted message
POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{deleted_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{deleted_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
deleted_token: jsonpath "$.idToken"

POST {{base_url}}/auth/link
Authorization: Bearer {{deleted_token}}
Content-Length: 0
HTTP 403
[Asserts]
jsonpath "$.detail" == "This account has been deleted. Please sign out and sign in again to start afresh."
jsonpath "$.deletion_status" == "completed"

# 10. Success: a member signs in; the lookup route accepts them and the create route says who they are
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

POST {{base_url}}/feedback
Authorization: Bearer {{member_token}}
Content-Type: application/json
{"clientId": "{{newUuid}}", "text": "JazakAllah"}
HTTP 201

POST {{base_url}}/auth/link
Authorization: Bearer {{member_token}}
Content-Length: 0
HTTP 200
[Asserts]
jsonpath "$.me.email" == "{{member_email}}"
jsonpath "$.me.token" isInteger
jsonpath "$.me.id" isInteger
# me is the whole profile, as GET /me answers it: the app reads its fields right after sign-in
jsonpath "$.me.*" count == 16
jsonpath "$.me.roleid" isInteger
jsonpath "$.me.name" exists
jsonpath "$.me.sendupdates" exists

# 11. A verified email that matches a member with no Firebase id claims that member (a create route)
POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{link_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{link_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
link_token_jwt: jsonpath "$.idToken"

POST {{base_url}}/auth/link
Authorization: Bearer {{link_token_jwt}}
Content-Length: 0
HTTP 200
[Asserts]
jsonpath "$.me.token" == {{link_token}}

# 12. A first sign-in on a create route makes a member, and signing in again finds the same one
POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
[Options]
variable: first_email=first-{{newUuid}}@example.invalid
{"email": "{{first_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP 200

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{first_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
first_jwt: jsonpath "$.idToken"

POST {{base_url}}/auth/link
Authorization: Bearer {{first_jwt}}
Content-Length: 0
HTTP 200
[Captures]
first_member: jsonpath "$.me.token"
[Asserts]
jsonpath "$.me.email" == "{{first_email}}"
jsonpath "$.me.token" >= 1001

POST {{base_url}}/auth/link
Authorization: Bearer {{first_jwt}}
Content-Length: 0
HTTP 200
[Asserts]
jsonpath "$.me.token" == {{first_member}}
