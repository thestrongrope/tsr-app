# GET /admin/deactivated-classes/candidates contract: the active classes one may choose to deactivate. Runs against any implementation.
# Variables: base_url and auth_<alias>. B4a fixtures: 9511 (gents, MIQDAD, Pune, teacher 900921, three rows not removed), 9513 (no city, one student), 9514 (ladies, ABUZAR), 9512 (closed); the admin 900902 (role 1).

# 1. Without sign-in: 401
GET {{base_url}}/admin/deactivated-classes/candidates
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Only deactivated-classes:manage: a student and the gents admin are refused
GET {{base_url}}/admin/deactivated-classes/candidates
Authorization: {{auth_en_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/admin/deactivated-classes/candidates
Authorization: {{auth_en_gadmin}}
HTTP 403

# 3. The active classes with what the confirmation shows; a missing city is an empty text; closed classes are not offered
GET {{base_url}}/admin/deactivated-classes/candidates
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.classes[?(@.id==9511)].code" == "B4-G-11"
jsonpath "$.classes[?(@.id==9511)].level" == "MIQDAD"
jsonpath "$.classes[?(@.id==9511)].gender" == 1
jsonpath "$.classes[?(@.id==9511)].teacher" == "B4 Member 900921"
jsonpath "$.classes[?(@.id==9511)].city" == "Pune"
jsonpath "$.classes[?(@.id==9511)].students" == 3
jsonpath "$.classes[?(@.id==9513)].city" == ""
jsonpath "$.classes[?(@.id==9513)].students" == 1
jsonpath "$.classes[?(@.id==9514)].gender" == 2
jsonpath "$.classes[?(@.id==9514)].level" == "ABUZAR"
jsonpath "$.classes[?(@.id==9512)]" not exists
jsonpath "$.classes[?(@.id==9515)]" not exists
