# GET /me/guides contract: the guides a student or a teacher can open, by slug. Runs against any implementation (tools/classes-contract.sh).
# Variables: base_url and auth_<alias>. Fixtures (classes-fixtures.sql): 900311 studies in the open class 9301, 900301 teaches it,
# 900313 is in no class, 900316 was removed from 9301, 900315 is a super admin in no class. Synthetic members only. Read only.

# 1. Without sign-in: 401 with a detail
GET {{base_url}}/me/guides
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A member who neither studies nor teaches is refused with PHP's text
GET {{base_url}}/me/guides
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Guides are for students and teachers"

# 3. A student removed from the class is not a student any more
GET {{base_url}}/me/guides
Authorization: {{auth_removed}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Guides are for students and teachers"

# 4. No permission opens it: a super admin who neither studies nor teaches is refused too
GET {{base_url}}/me/guides
Authorization: {{auth_admin}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Guides are for students and teachers"

# 5. A student gets the four levels that have a guide page, in class level order, with slug and name only
#    (a level is listed whether or not its guide has text: AMMAR has no guide row, BILAL a blank one)
GET {{base_url}}/me/guides
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.guides" count == 4
jsonpath "$.guides[0].slug" == "abuzar"
jsonpath "$.guides[0].name" == "ABUZAR"
jsonpath "$.guides[1].slug" == "miqdad"
jsonpath "$.guides[1].name" == "MIQDAD"
jsonpath "$.guides[2].slug" == "ammar"
jsonpath "$.guides[2].name" == "AMMAR"
jsonpath "$.guides[3].slug" == "bilal"
jsonpath "$.guides[3].name" == "BILAL"
jsonpath "$.guides[0].id" not exists
jsonpath "$.guides[0].guide" not exists
jsonpath "$.levels" not exists

# 6. A teacher gets the same list
GET {{base_url}}/me/guides
Authorization: {{auth_teacher_g}}
HTTP 200
[Asserts]
jsonpath "$.guides" count == 4
jsonpath "$.guides[3].slug" == "bilal"
