# GET /mcq/copy/classes contract: the classes a member may copy quizzes from or to. Runs against any implementation.
# Variables: base_url and auth_qm_<alias> (tools/assessment-contract.sh). Fixtures: db/synthetic/assessment-a2-fixtures.sql (read its header).
# The lists hold every class of the database for the wide roles, so the cases look at the fixture classes 9631 to 9637 only (a filter on the id), except the coordinator's, which is exactly its four.

# 1. Without sign-in: 401
GET {{base_url}}/mcq/copy/classes
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Who may not copy at all (a teacher, a class admin student, a plain student, a member of no class: mcqs:copy has no "own" scope): 403
GET {{base_url}}/mcq/copy/classes
Authorization: {{auth_qm_teacher}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to copy MCQs"

GET {{base_url}}/mcq/copy/classes
Authorization: {{auth_qm_admin}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to copy MCQs"

GET {{base_url}}/mcq/copy/classes
Authorization: {{auth_qm_student}}
HTTP 403

GET {{base_url}}/mcq/copy/classes
Authorization: {{auth_qm_nobody}}
HTTP 403

# 3. A super admin sees the classes of both genders (active only, ordered by gender, level order, id); a closed class is never listed
GET {{base_url}}/mcq/copy/classes
Authorization: {{auth_qm_super}}
HTTP 200
[Asserts]
jsonpath "$[?(@.id>9630 && @.id<9638)].id" count == 6
jsonpath "$[?(@.id>9630 && @.id<9638)].id" nth 0 == 9637
jsonpath "$[?(@.id>9630 && @.id<9638)].id" nth 1 == 9631
jsonpath "$[?(@.id>9630 && @.id<9638)].id" nth 2 == 9632
jsonpath "$[?(@.id>9630 && @.id<9638)].id" nth 3 == 9633
jsonpath "$[?(@.id>9630 && @.id<9638)].id" nth 4 == 9635
jsonpath "$[?(@.id>9630 && @.id<9638)].id" nth 5 == 9636
jsonpath "$[?(@.id==9631)].code" == "A2-G-631"
jsonpath "$[?(@.id==9631)].level" == "MIQDAD"
jsonpath "$[?(@.id==9631)].city" == "A2ville"
jsonpath "$[?(@.id==9631)].teacher" == "Qm Member 902501"
jsonpath "$[?(@.id==9637)].level" == "SALMAN"
jsonpath "$[?(@.id==9634)]" not exists

# 4. A gents admin sees the gents classes only (never the ladies class 9636); a ladies admin the ladies classes only
GET {{base_url}}/mcq/copy/classes
Authorization: {{auth_qm_gents_admin}}
HTTP 200
[Asserts]
jsonpath "$[?(@.id>9630 && @.id<9638)].id" count == 5
jsonpath "$[?(@.id==9636)]" not exists
jsonpath "$[?(@.id==9635)].city" == "A2other"

GET {{base_url}}/mcq/copy/classes
Authorization: {{auth_qm_ladies_admin}}
HTTP 200
[Asserts]
jsonpath "$[?(@.id>9630 && @.id<9638)].id" == 9636
jsonpath "$[?(@.id==9636)].code" == "A2-L-636"
jsonpath "$[?(@.id==9631)]" not exists

# 5. A coordinator sees exactly the classes assigned to it, not 9635 (another city) or 9636
GET {{base_url}}/mcq/copy/classes
Authorization: {{auth_qm_coord}}
HTTP 200
[Asserts]
jsonpath "$" count == 4
jsonpath "$[0].id" == 9637
jsonpath "$[1].id" == 9631
jsonpath "$[2].id" == 9632
jsonpath "$[3].id" == 9633
