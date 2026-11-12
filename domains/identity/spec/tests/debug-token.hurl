# POST /auth/debug-token contract: echoes what the caller's own bearer token decoded to. Served only outside Production (APP_ENV is local on PHP's parity stack; the new API's test stack runs in Development);
# in Production it answers 404 "Not found" before looking at the token (proved by db/tests/TestDebugTokenTests.cs, which builds the host in Production). Runs against any implementation.
# Variables: base_url, auth_deletion_admin (the emulator's token for 924001: only its own claims are echoed).

# 1. No header, or one that is not "Bearer <token>": 401 not authenticated
POST {{base_url}}/auth/debug-token
Content-Length: 0
HTTP 401
[Asserts]
jsonpath "$.detail" == "Not authenticated"

POST {{base_url}}/auth/debug-token
Authorization: Basic abc
Content-Length: 0
HTTP 401
[Asserts]
jsonpath "$.detail" == "Not authenticated"

POST {{base_url}}/auth/debug-token
Authorization: Bearer
Content-Length: 0
HTTP 401
[Asserts]
jsonpath "$.detail" == "Not authenticated"

# 2. A token that does not verify: 401 invalid auth token
POST {{base_url}}/auth/debug-token
Authorization: Bearer not-a-token
Content-Length: 0
HTTP 401
[Asserts]
jsonpath "$.detail" == "Invalid auth token"

# 3. A valid token: its own email, the Firebase uid (the subject), the name claim (none on an emulator account) and provider (always null: PHP's verifier does not hand the provider on)
POST {{base_url}}/auth/debug-token
Authorization: {{auth_deletion_admin}}
Content-Length: 0
HTTP 200
[Asserts]
jsonpath "$.status" == "success"
jsonpath "$.email" == "dl.924001@example.invalid"
jsonpath "$.uid" isString
jsonpath "$.name" == null
jsonpath "$.provider" == null
jsonpath "$.*" count == 5
