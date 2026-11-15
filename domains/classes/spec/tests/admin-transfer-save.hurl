# POST /admin/transfers contract: move several students between classes of one gender; each moves on its own and the answer says who did not. Runs against any implementation.
# Variables: base_url and auth_<alias>. B4a fixtures (reset by tools/classes-contract.sh): 9521 (gents, active; 900961 to 900965 active, 900966 removed), 9522 (destination; 900962 already in it), 9523 (ladies), 9524 (closed),
# 9525 (closed; deactivation cohort 900971 and 900972; 900972 is active in 9526); the admin 900903 (role 1), the gents admin 900501.

# 1. Without sign-in: 401
POST {{base_url}}/admin/transfers
{"fromClassId": 9521, "toClassId": 9522, "type": "transfer", "tokens": [900961]}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Only students:transfer
POST {{base_url}}/admin/transfers
Authorization: {{auth_en_student}}
{"fromClassId": 9521, "toClassId": 9522, "type": "transfer", "tokens": [900961]}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only administrators can transfer students"

POST {{base_url}}/admin/transfers
Authorization: {{auth_en_gadmin}}
{"fromClassId": 9521, "toClassId": 9522, "type": "transfer", "tokens": [900961]}
HTTP 403

# 3. The checks, in PHP's order
POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Source and destination classes are required"

POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": "9521", "toClassId": 9522, "type": "transfer", "tokens": [900961]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Source and destination classes are required"

POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": 9521.0, "toClassId": 9522, "type": "transfer", "tokens": [900961]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Source and destination classes are required"

POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": 9521, "toClassId": 9521, "type": "transfer", "tokens": [900961]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Source and destination classes must be different"

POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": 9521, "toClassId": 9522, "type": "Transfer", "tokens": [900961]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "type must be transfer, promotion or demotion"

POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": 9521, "toClassId": 9522, "tokens": [900961]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "type must be transfer, promotion or demotion"

POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": 9521, "toClassId": 9522, "type": "transfer", "reason": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "tokens": [900961]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason must be at most 500 characters"

POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": 9521, "toClassId": 9522, "type": "transfer"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose at least one student"

POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": 9521, "toClassId": 9522, "type": "transfer", "tokens": []}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose at least one student"

POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": 9521, "toClassId": 9522, "type": "transfer", "tokens": [900961, "900962"]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "tokens must be member tokens"

POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": 9521, "toClassId": 9522, "type": "transfer", "tokens": [0]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "tokens must be member tokens"

POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": 9521, "toClassId": 999999, "type": "transfer", "tokens": [900961]}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": 999999, "toClassId": 9522, "type": "transfer", "tokens": [900961]}
HTTP 404

POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": 9521, "toClassId": 9524, "type": "transfer", "tokens": [900961]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The destination class is not active"

POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": 9521, "toClassId": 9523, "type": "transfer", "tokens": [900961]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A student can only move to a class of the same gender"

# 4. A refused request moved nobody
GET {{base_url}}/admin/transfers/classes/9521/students
Authorization: {{auth_b4_save}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 5

# 5. A batch: one moves, one is already in the destination, one is not in the source, one is no member; a repeated token counts once; the names come from the source's roster
POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": 9521, "toClassId": 9522, "type": "transfer", "reason": " B4 move ", "tokens": [900961, 900962, 900962, 900966, 999000001]}
HTTP 200
[Asserts]
jsonpath "$.moved" count == 1
jsonpath "$.moved[0].token" == 900961
jsonpath "$.moved[0].name" == "B4 Member 900961"
jsonpath "$.failed" count == 3
jsonpath "$.failed[0].token" == 900962
jsonpath "$.failed[0].name" == "B4 Member 900962"
jsonpath "$.failed[0].reason" == "Student 900962 is already enrolled in destination class #9522"
jsonpath "$.failed[1].token" == 900966
jsonpath "$.failed[1].name" == null
jsonpath "$.failed[1].reason" == "Student 900966 is not active in source class #9521"
jsonpath "$.failed[2].token" == 999000001
jsonpath "$.failed[2].reason" == "Student 999000001 is not active in source class #9521"

# 6. The move is logged (the reason trimmed), the student left the source and joined the destination; the one who could not move stayed
GET {{base_url}}/admin/transfers/history?q=900961
Authorization: {{auth_b4_save}}
HTTP 200
[Asserts]
jsonpath "$.total" == 1
jsonpath "$.items[0].type" == "transfer"
jsonpath "$.items[0].fromCode" == "B4-G-21"
jsonpath "$.items[0].toCode" == "B4-G-22"
jsonpath "$.items[0].reason" == "B4 move"
jsonpath "$.items[0].transferredBy" == "B4 Member 900903"

GET {{base_url}}/admin/transfers/classes/9521/students
Authorization: {{auth_b4_save}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 4
jsonpath "$.students[?(@.token==900961)]" not exists
jsonpath "$.students[?(@.token==900962)].name" == "B4 Member 900962"

GET {{base_url}}/admin/transfers/classes/9522/students
Authorization: {{auth_b4_save}}
HTTP 200
[Asserts]
jsonpath "$.students[?(@.token==900961)].name" == "B4 Member 900961"

# 7. A promotion without a reason; the type is kept
POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": 9521, "toClassId": 9522, "type": "promotion", "tokens": [900963]}
HTTP 200
[Asserts]
jsonpath "$.moved[0].token" == 900963
jsonpath "$.failed" count == 0

GET {{base_url}}/admin/transfers/history?q=900963
Authorization: {{auth_b4_save}}
HTTP 200
[Asserts]
jsonpath "$.items[0].type" == "promotion"
jsonpath "$.items[0].reason" == null

# 8. A repeated request finds nobody left in the source
POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": 9521, "toClassId": 9522, "type": "transfer", "tokens": [900961]}
HTTP 200
[Asserts]
jsonpath "$.moved" count == 0
jsonpath "$.failed[0].reason" == "Student 900961 is not active in source class #9521"

# 9. A closed source: its deactivation cohort can be re-homed; a member active elsewhere cannot; a stranger is not on it
POST {{base_url}}/admin/transfers
Authorization: {{auth_b4_save}}
{"fromClassId": 9525, "toClassId": 9522, "type": "transfer", "tokens": [900971, 900972, 900973]}
HTTP 200
[Asserts]
jsonpath "$.moved" count == 1
jsonpath "$.moved[0].token" == 900971
jsonpath "$.moved[0].name" == "B4 Member 900971"
jsonpath "$.failed" count == 2
jsonpath "$.failed[0].token" == 900972
jsonpath "$.failed[0].name" == null
jsonpath "$.failed[0].reason" == "Student 900972 already has an active class; skipped"
jsonpath "$.failed[1].reason" == "Student 900973 is not active in source class #9525"

GET {{base_url}}/admin/transfers/classes/9525/students
Authorization: {{auth_b4_save}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 0

GET {{base_url}}/admin/transfers/history?q=900971
Authorization: {{auth_b4_save}}
HTTP 200
[Asserts]
jsonpath "$.total" == 1
jsonpath "$.items[0].fromCode" == "B4-G-25"
