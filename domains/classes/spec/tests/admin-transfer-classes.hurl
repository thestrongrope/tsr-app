# GET /admin/transfers/classes contract: every class (closed ones too) and the level names, for the one administrator who may transfer students. Runs against any implementation.
# Variables: base_url and auth_<alias>. B4a fixtures: 9511 (gents, MIQDAD, teacher 900921, Pune; 900931 and 900932 active, 900933 removed, 900934 with status I but no removal: three rows count), 9512 (closed, AMMAR),
# 9513 (no city; one student), 9514 (ladies, ABUZAR); the admin 900902 (role 1).

# 1. Without sign-in: 401
GET {{base_url}}/admin/transfers/classes
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Only students:transfer: a student and the gents admin are refused
GET {{base_url}}/admin/transfers/classes
Authorization: {{auth_en_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only administrators can transfer students"

GET {{base_url}}/admin/transfers/classes
Authorization: {{auth_en_gadmin}}
HTTP 403

# 3. The class rows: the level's NAME, the teacher's name, the live row count (status is not looked at), active as a flag
GET {{base_url}}/admin/transfers/classes
Authorization: {{auth_b4_read}}
HTTP 200
[Asserts]
jsonpath "$.classes[?(@.id==9511)].code" == "B4-G-11"
jsonpath "$.classes[?(@.id==9511)].name" == "B4 Alpha Class"
jsonpath "$.classes[?(@.id==9511)].level" == "MIQDAD"
jsonpath "$.classes[?(@.id==9511)].gender" == 1
jsonpath "$.classes[?(@.id==9511)].teacher" == "B4 Member 900921"
jsonpath "$.classes[?(@.id==9511)].city" == "Pune"
jsonpath "$.classes[?(@.id==9511)].country" == "India"
jsonpath "$.classes[?(@.id==9511)].students" == 3
jsonpath "$.classes[?(@.id==9511)].active" == true
jsonpath "$.classes[?(@.id==9512)].active" == false
jsonpath "$.classes[?(@.id==9512)].level" == "AMMAR"
jsonpath "$.classes[?(@.id==9513)].city" == null
jsonpath "$.classes[?(@.id==9513)].students" == 1
jsonpath "$.classes[?(@.id==9514)].gender" == 2
jsonpath "$.classes[?(@.id==9514)].level" == "ABUZAR"
jsonpath "$.classes[?(@.id==9515)].students" == 0
jsonpath "$.levels" contains "MIQDAD"
jsonpath "$.levels" contains "AMMAR"
jsonpath "$.levels" contains "ABUZAR"
