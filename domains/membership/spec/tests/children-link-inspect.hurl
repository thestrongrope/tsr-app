# GET /me/children/link/{code} contract: one file per slice, runs against any implementation.
# Variables: base_url and auth_<alias>. Synthetic members only. Each call counts toward 60 an hour per member (PHP keeps the count
# across runs), so this file makes few calls; the 429 is proven in db/tests (GuardianTests).

# 1. Without sign-in: 401
GET {{base_url}}/me/children/link/a1b2c3d4e5f60718293a4b5c6d7e8f01
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A live invite: valid, with the child's first name (the only thing revealed)
GET {{base_url}}/me/children/link/a1b2c3d4e5f60718293a4b5c6d7e8f01
Authorization: {{auth_gender_two}}
HTTP 200
[Asserts]
jsonpath "$.state" == "valid"
jsonpath "$.first_name" == "Kidname"

# 3. An expired invite shows only its state, an unknown code too
GET {{base_url}}/me/children/link/0f8e7d6c5b4a39281706f5e4d3c2b1a0
Authorization: {{auth_gender_two}}
HTTP 200
[Asserts]
jsonpath "$.state" == "expired"
jsonpath "$.first_name" not exists

GET {{base_url}}/me/children/link/no-such-code
Authorization: {{auth_gender_two}}
HTTP 200
[Asserts]
jsonpath "$.state" == "not_found"
jsonpath "$.first_name" not exists
