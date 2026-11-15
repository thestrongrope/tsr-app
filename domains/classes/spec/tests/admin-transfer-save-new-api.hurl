# POST /admin/transfers, cases only the new API answers (a NUL byte cannot be stored; PHP stores it). Runs on the new API only.
# Variables: base_url and auth_<alias>. B4a fixtures: 9521 (source), 9522 (destination), 900961 active in 9521; the admin 900903 (role 1).

# 1. A NUL byte in the reason is 422 and nobody moves
POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": 9521, "toClassId": 9522, "type": "transfer", "reason": "a\u0000b", "tokens": [900961]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason must be at most 500 characters"

