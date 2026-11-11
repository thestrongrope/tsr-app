# POST /admin/teachers/training contract: add or remove the levels teachers are trained for, with a comment. Runs against any implementation.
# Variables: base_url and auth_<alias>. B4a fixtures (reset by tools/classes-contract.sh, training records and history included): 901001 (record, all levels off), 901002 (no record), 901003 (ladies, no record),
# 901004 (gender text "Male"), 901005 (record, status I, bilal on), 901006 (record: salman and bilal on, one history row); the admin 900903 (role 1), the gents admin 900501 (role 3).

# 1. Without sign-in: 401
POST {{base_url}}/admin/teachers/training
{"changes": [{"token": 901001, "level": "salman", "action": "added"}], "comments": "x"}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A student may not train anyone (before the body is read)
POST {{base_url}}/admin/teachers/training
Authorization: {{auth_en_student}}
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. The comment and the list, in PHP's order
POST {{base_url}}/admin/teachers/training
Authorization: {{auth_b4_save}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A comment is required"

POST {{base_url}}/admin/teachers/training
Authorization: {{auth_b4_save}}
{"changes": [{"token": 901001, "level": "salman", "action": "added"}], "comments": "   "}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A comment is required"

POST {{base_url}}/admin/teachers/training
Authorization: {{auth_b4_save}}
{"changes": [{"token": 901001, "level": "salman", "action": "added"}], "comments": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A comment is required"

POST {{base_url}}/admin/teachers/training
Authorization: {{auth_b4_save}}
{"changes": [{"token": 901001, "level": "salman", "action": "added"}], "comments": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The comment must be 500 characters or fewer"

POST {{base_url}}/admin/teachers/training
Authorization: {{auth_b4_save}}
{"comments": "B4 nothing"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "There is nothing to change"

POST {{base_url}}/admin/teachers/training
Authorization: {{auth_b4_save}}
{"changes": "salman", "comments": "B4 nothing"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "There is nothing to change"

# 4. Each change must be a teacher, a level and added or removed
POST {{base_url}}/admin/teachers/training
Authorization: {{auth_b4_save}}
{"changes": [5], "comments": "B4 shape"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Each change needs a teacher, a level and added or removed"

POST {{base_url}}/admin/teachers/training
Authorization: {{auth_b4_save}}
{"changes": [{"token": 901001, "level": "salman"}], "comments": "B4 shape"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Each change needs a teacher, a level and added or removed"

POST {{base_url}}/admin/teachers/training
Authorization: {{auth_b4_save}}
{"changes": [{"token": 901001, "level": "zayd", "action": "added"}], "comments": "B4 shape"}
HTTP 422

POST {{base_url}}/admin/teachers/training
Authorization: {{auth_b4_save}}
{"changes": [{"token": 901001, "level": "salman", "action": "toggled"}], "comments": "B4 shape"}
HTTP 422

POST {{base_url}}/admin/teachers/training
Authorization: {{auth_b4_save}}
{"changes": [{"token": "abc", "level": "salman", "action": "added"}], "comments": "B4 shape"}
HTTP 422

# 5. Teachers are judged one by one, in order: an unknown one is 404, one without a numeric gender (or one the caller may not manage) is 403, even when a later change is malformed
POST {{base_url}}/admin/teachers/training
Authorization: {{auth_b4_save}}
{"changes": [{"token": 999999, "level": "salman", "action": "added"}, {"token": 901001, "level": "bad", "action": "added"}], "comments": "B4 judged"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Teacher #999999 not found"

POST {{base_url}}/admin/teachers/training
Authorization: {{auth_b4_save}}
{"changes": [{"token": 901004, "level": "salman", "action": "added"}], "comments": "B4 judged"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to change teacher #901004"

POST {{base_url}}/admin/teachers/training
Authorization: {{auth_en_gadmin}}
{"changes": [{"token": 901003, "level": "salman", "action": "added"}], "comments": "B4 judged"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to change teacher #901003"

# 6. Nothing was written by any refusal
GET {{base_url}}/teachers/901002
Authorization: {{auth_b4_save}}
HTTP 200
[Asserts]
jsonpath "$.flags.abuzar" == false
jsonpath "$.history" count == 0

# 7. A batch: a teacher with a record, one without (two levels, the same teacher counted once), a ladies teacher (the super admin may); "changed" counts teachers
POST {{base_url}}/admin/teachers/training
Authorization: {{auth_b4_save}}
{"changes": [{"token": 901001, "level": "salman", "action": "added"}, {"token": 901002, "level": "abuzar", "action": "added"}, {"token": 901002, "level": "miqdad", "action": "added"}, {"token": "901003", "level": "bilal", "action": "added"}], "comments": " B4 batch "}
HTTP 200
[Asserts]
jsonpath "$.changed" == 3

GET {{base_url}}/teachers/901001
Authorization: {{auth_b4_save}}
HTTP 200
[Asserts]
jsonpath "$.flags.salman" == true
jsonpath "$.flags.abuzar" == false
jsonpath "$.history" count == 1
jsonpath "$.history[0].comments" matches /^UPDATE: B4 batch - Batch ID: [0-9a-f]{13} - \+SM$/
jsonpath "$.history[0].by" == "B4 Member 900903"

GET {{base_url}}/teachers/901002
Authorization: {{auth_b4_save}}
HTTP 200
[Asserts]
jsonpath "$.trained" == true
jsonpath "$.flags.salman" == false
jsonpath "$.flags.abuzar" == true
jsonpath "$.flags.miqdad" == true
jsonpath "$.history[0].comments" matches /^ADD: B4 batch - Batch ID: [0-9a-f]{13} - \+AG, \+MK$/

GET {{base_url}}/teachers/901003
Authorization: {{auth_b4_save}}
HTTP 200
[Asserts]
jsonpath "$.flags.bilal" == true

# 8. Removing a level, reactivating a teacher whose record was inactive, and a change that flips nothing (still recorded, with an empty list)
POST {{base_url}}/admin/teachers/training
Authorization: {{auth_b4_save}}
{"changes": [{"token": 901006, "level": "bilal", "action": "removed"}, {"token": 901005, "level": "salman", "action": "added"}], "comments": "B4 second"}
HTTP 200
[Asserts]
jsonpath "$.changed" == 2

GET {{base_url}}/teachers/901006
Authorization: {{auth_b4_save}}
HTTP 200
[Asserts]
jsonpath "$.flags.salman" == true
jsonpath "$.flags.bilal" == false
jsonpath "$.history" count == 2
jsonpath "$.history[0].comments" matches /^UPDATE: B4 second - Batch ID: [0-9a-f]{13} - -BL$/

GET {{base_url}}/teachers/901005
Authorization: {{auth_b4_save}}
HTTP 200
[Asserts]
jsonpath "$.flags.salman" == true
jsonpath "$.flags.bilal" == true
jsonpath "$.history[0].comments" matches /^UPDATE: B4 second - Batch ID: [0-9a-f]{13} - \+SM$/

POST {{base_url}}/admin/teachers/training
Authorization: {{auth_b4_save}}
{"changes": [{"token": 901001, "level": "salman", "action": "added"}], "comments": "B4 same"}
HTTP 200
[Asserts]
jsonpath "$.changed" == 1

GET {{base_url}}/teachers/901001
Authorization: {{auth_b4_save}}
HTTP 200
[Asserts]
jsonpath "$.history" count == 2
body matches /"comments":"UPDATE: B4 same - Batch ID: [0-9a-f]{13} - "/
