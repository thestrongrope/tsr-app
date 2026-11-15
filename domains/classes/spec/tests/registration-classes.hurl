# GET /registrations/{registration_id}/classes contract: the classes a waiting registrant could be placed in. Runs against any implementation.
# Variables: base_url and auth_<alias>. ENROLMENT fixtures (reset by tools/classes-contract.sh): registrations 9577 (900576, gents, waiting), 9572 (900572, ladies, waiting), 9573 (rejected), 9574 (already enrolled),
# 9575 (not the member's latest row); class 9420 (gents, MIQDAD, teacher 900511, location En Hall, no students), the ladies class 9414; the write admin (all), the gents admin 900501, the ladies admin 900502.

# 1. Without sign-in: 401
GET {{base_url}}/registrations/9577/classes
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A caller who may read no registrations: 403 before the id is looked up (an unknown id answers the same)
GET {{base_url}}/registrations/9577/classes
Authorization: {{auth_en_teacher}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/registrations/999999/classes
Authorization: {{auth_en_student}}
HTTP 403

# 3. Nobody is waiting under that id: 409 (unknown, rejected, already enrolled, not the member's latest row)
GET {{base_url}}/registrations/999999/classes
Authorization: {{auth_wr_admin}}
HTTP 409
[Asserts]
jsonpath "$.detail" == "This registrant is no longer waiting: they have been placed or rejected."

GET {{base_url}}/registrations/9573/classes
Authorization: {{auth_wr_admin}}
HTTP 409

GET {{base_url}}/registrations/9574/classes
Authorization: {{auth_wr_admin}}
HTTP 409

GET {{base_url}}/registrations/9575/classes
Authorization: {{auth_wr_admin}}
HTTP 409

# 4. A registrant of the other gender than the caller's reach: 403
GET {{base_url}}/registrations/9577/classes
Authorization: {{auth_en_ladmin}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/registrations/9572/classes
Authorization: {{auth_en_gadmin}}
HTTP 403

# 5. The write admin sees the gents classes with what the picker shows; the ladies class is not among them
GET {{base_url}}/registrations/9577/classes
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.classes[?(@.id==9420)].code" == "EN-G-020"
jsonpath "$.classes[?(@.id==9420)].level" == "MIQDAD"
jsonpath "$.classes[?(@.id==9420)].teacher" == "En Member 900511"
jsonpath "$.classes[?(@.id==9420)].location" == "En Hall"
jsonpath "$.classes[?(@.id==9420)].students" == 0
jsonpath "$.classes[?(@.id==9414)]" not exists

# 6. The gents admin gets the same gents classes; the ladies registrant gets the ladies class to the ladies admin
GET {{base_url}}/registrations/9577/classes
Authorization: {{auth_en_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.classes[?(@.id==9420)].code" == "EN-G-020"

GET {{base_url}}/registrations/9572/classes
Authorization: {{auth_en_ladmin}}
HTTP 200
[Asserts]
jsonpath "$.classes[?(@.id==9414)].code" == "EN-L-014"
jsonpath "$.classes[?(@.id==9420)]" not exists
