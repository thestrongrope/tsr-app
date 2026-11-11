# POST /admin/teachers/import contract: give every teacher of an active class who has no training record the levels up to the one they teach. Runs against any implementation.
# Variables: base_url and auth_<alias>. B4a fixtures (reset by tools/classes-contract.sh, training records included): ladies teacher 901011 teaches 9551 (level 3) and 9552 (level 2), 901012 teaches 9553 (level 1),
# 901013 has a record (miqdad, ammar, bilal) and teaches 9554; the admin 900902 (role 1), the ladies admin 900502 (role 4). Only ladies are imported here: a gents import would give records to the teachers other files
# read as untrained. Other ladies teachers in the database are imported too, so "added" is only bounded below.

# 1. Without sign-in: 401
POST {{base_url}}/admin/teachers/import
{"gender": 2}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A student may not import
POST {{base_url}}/admin/teachers/import
Authorization: {{auth_en_student}}
{"gender": 2}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. The ladies' teachers without a record are added; the count is at least ours
POST {{base_url}}/admin/teachers/import
Authorization: {{auth_b4_read}}
{"gender": 2}
HTTP 200
[Asserts]
jsonpath "$.added" >= 2

# 4. The levels follow the lowest level taught: 2 is every level but salman; 1 is every level; an existing record is left alone
GET {{base_url}}/teachers/901011
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.trained" == true
jsonpath "$.flags.salman" == false
jsonpath "$.flags.abuzar" == true
jsonpath "$.flags.miqdad" == true
jsonpath "$.flags.ammar" == true
jsonpath "$.flags.bilal" == true
jsonpath "$.history" count == 1
jsonpath "$.history[0].comments" matches /^ADD: Imported from Active Classes - Batch ID: [0-9a-f]{13} - \+AG, \+MK, \+AY, \+BL$/

GET {{base_url}}/teachers/901012
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.flags.salman" == true
jsonpath "$.flags.bilal" == true
jsonpath "$.history[0].comments" matches /^ADD: Imported from Active Classes - Batch ID: [0-9a-f]{13} - \+SM, \+AG, \+MK, \+AY, \+BL$/

GET {{base_url}}/teachers/901013
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.flags.salman" == false
jsonpath "$.flags.abuzar" == false
jsonpath "$.flags.miqdad" == true
jsonpath "$.history" count == 0

# 5. A second call finds nobody of ours left (the gender may also be the text "2"); each teacher still has one history row
POST {{base_url}}/admin/teachers/import
Authorization: {{auth_b4_read}}
{"gender": "2"}
HTTP 200
[Asserts]
jsonpath "$.added" isInteger

GET {{base_url}}/teachers/901011
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.history" count == 1

# 6. A ladies administrator is held to ladies whatever is asked: the same import, nothing left to add of ours
POST {{base_url}}/admin/teachers/import
Authorization: {{auth_en_ladmin}}
{"gender": 1}
HTTP 200
[Asserts]
jsonpath "$.added" isInteger

GET {{base_url}}/teachers/901012
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.history" count == 1
