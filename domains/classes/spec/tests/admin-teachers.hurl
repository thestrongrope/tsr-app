# GET /admin/teachers?gender= contract: a gender's trained teachers with their levels. Runs against any implementation.
# Variables: base_url and auth_<alias>. B4a fixtures: 900921 (gents; record: abuzar and miqdad; a student of the active class 9544 (ABUZAR); teaches the active 9511 and 9513; closed classes do not count), 900922 (record, but not a student: left out), 900924 (record with status I: left out), 900925 (gender text "Male": left out), 900923 (ladies; record: salman; a student of 9514 (ABUZAR), teaches 9514, 9523 and 9532);
# the admin 900902 (role 1), the gents admin 900501 (role 3), the ladies admin 900502 (role 4).

# 1. Without sign-in: 401
GET {{base_url}}/admin/teachers
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A student may not read the list
GET {{base_url}}/admin/teachers
Authorization: {{auth_en_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. The super admin: gents by default, with the five levels
GET {{base_url}}/admin/teachers
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.levels" count == 5
jsonpath "$.levels[0].key" == "salman"
jsonpath "$.levels[0].code" == "SM"
jsonpath "$.levels[0].name" == "Salman"
jsonpath "$.levels[1].code" == "AG"
jsonpath "$.levels[2].code" == "MK"
jsonpath "$.levels[3].code" == "AY"
jsonpath "$.levels[4].key" == "bilal"
jsonpath "$.levels[4].code" == "BL"
jsonpath "$.levels[4].name" == "Bilal"
jsonpath "$.teachers[?(@.token==900921)].name" == "B4 Member 900921"
jsonpath "$.teachers[?(@.token==900921)].level" == "AG"
jsonpath "$.teachers[?(@.token==900921)].classes" == 2
jsonpath "$.teachers[?(@.token==900921)].flags.salman" == false
jsonpath "$.teachers[?(@.token==900921)].flags.abuzar" == true
jsonpath "$.teachers[?(@.token==900921)].flags.miqdad" == true
jsonpath "$.teachers[?(@.token==900921)].flags.ammar" == false
jsonpath "$.teachers[?(@.token==900921)].flags.bilal" == false
jsonpath "$.teachers[?(@.token==900921)].conducting[0]" == "B4-G-11"
jsonpath "$.teachers[?(@.token==900921)].conducting[1]" == "B4-G-13"
jsonpath "$.teachers[?(@.token==900921)].conducting[2]" not exists
jsonpath "$.teachers[?(@.token==900922)]" not exists
jsonpath "$.teachers[?(@.token==900924)]" not exists
jsonpath "$.teachers[?(@.token==900925)]" not exists
jsonpath "$.teachers[?(@.token==900923)]" not exists

# 4. The gender asked for: 2 is ladies; anything else is gents (no error)
GET {{base_url}}/admin/teachers?gender=2
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.teachers[?(@.token==900923)].level" == "AG"
jsonpath "$.teachers[?(@.token==900923)].classes" == 3
jsonpath "$.teachers[?(@.token==900923)].flags.salman" == true
jsonpath "$.teachers[?(@.token==900923)].conducting[0]" == "B4-L-14"
jsonpath "$.teachers[?(@.token==900923)].conducting[1]" == "B4-L-23"
jsonpath "$.teachers[?(@.token==900923)].conducting[2]" == "B4-L-32"
jsonpath "$.teachers[?(@.token==900921)]" not exists

GET {{base_url}}/admin/teachers?gender=abc
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1

GET {{base_url}}/admin/teachers?gender=3
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1

# 5. A gender administrator is held to their own gender whatever is asked
GET {{base_url}}/admin/teachers?gender=2
Authorization: {{auth_en_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.teachers[?(@.token==900921)].name" == "B4 Member 900921"

GET {{base_url}}/admin/teachers?gender=1
Authorization: {{auth_en_ladmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.teachers[?(@.token==900923)].name" == "B4 Member 900923"
