# GET /mcq/copy/classes/{class_id}/topics contract: the topics of a class the caller may copy quizzes from. Runs against any implementation.
# Variables: base_url and auth_qm_<alias> (tools/assessment-contract.sh). Fixtures: db/synthetic/assessment-a2-fixtures.sql (read its header).

# 1. Without sign-in: 401
GET {{base_url}}/mcq/copy/classes/9631/topics
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A missing or closed class is 404 before the permission check
GET {{base_url}}/mcq/copy/classes/99999999/topics
Authorization: {{auth_qm_nobody}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/mcq/copy/classes/9634/topics
Authorization: {{auth_qm_super}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 3. Refused (copying is not managing: the class teacher and a class admin may not): the teacher, a class admin, a plain student, a member of no class,
#    a ladies admin on a gents class, a gents admin on a ladies class, a coordinator on a class that is not assigned to it
GET {{base_url}}/mcq/copy/classes/9631/topics
Authorization: {{auth_qm_teacher}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to copy MCQs from this class"

GET {{base_url}}/mcq/copy/classes/9631/topics
Authorization: {{auth_qm_admin}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to copy MCQs from this class"

GET {{base_url}}/mcq/copy/classes/9631/topics
Authorization: {{auth_qm_student}}
HTTP 403

GET {{base_url}}/mcq/copy/classes/9631/topics
Authorization: {{auth_qm_nobody}}
HTTP 403

GET {{base_url}}/mcq/copy/classes/9631/topics
Authorization: {{auth_qm_ladies_admin}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to copy MCQs from this class"

GET {{base_url}}/mcq/copy/classes/9636/topics
Authorization: {{auth_qm_gents_admin}}
HTTP 403

GET {{base_url}}/mcq/copy/classes/9635/topics
Authorization: {{auth_qm_coord}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to copy MCQs from this class"

# 4. A super admin, a gents admin and the coordinator (for an assigned class) read the distinct topics; a ladies admin reads a ladies class (none yet)
GET {{base_url}}/mcq/copy/classes/9631/topics
Authorization: {{auth_qm_super}}
HTTP 200
[Asserts]
jsonpath "$" count == 6
jsonpath "$[0]" == "A2 100% sure_"
jsonpath "$[1]" == "A2 Topic Beta"
jsonpath "$[5]" == "A2 topic two"

GET {{base_url}}/mcq/copy/classes/9631/topics
Authorization: {{auth_qm_gents_admin}}
HTTP 200
[Asserts]
jsonpath "$" count == 6

GET {{base_url}}/mcq/copy/classes/9631/topics
Authorization: {{auth_qm_coord}}
HTTP 200
[Asserts]
jsonpath "$" count == 6

GET {{base_url}}/mcq/copy/classes/9636/topics
Authorization: {{auth_qm_ladies_admin}}
HTTP 200
[Asserts]
jsonpath "$" count == 0
