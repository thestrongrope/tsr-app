# GET /classes/{class_id}/mcq/topics contract: the topics a class's quizzes use, for its teacher or class admin. Runs against any implementation.
# Variables: base_url and auth_qm_<alias> (tools/assessment-contract.sh). Fixtures: db/synthetic/assessment-a2-fixtures.sql (read its header).

# 1. Without sign-in: 401
GET {{base_url}}/classes/9631/mcq/topics
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A missing or closed class is 404 before the permission check
GET {{base_url}}/classes/99999999/mcq/topics
Authorization: {{auth_qm_nobody}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/classes/9634/mcq/topics
Authorization: {{auth_qm_teacher}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 3. Refused: a plain student, the admin of another class, a removed admin, a member of no class, a gender admin, a coordinator
GET {{base_url}}/classes/9631/mcq/topics
Authorization: {{auth_qm_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

GET {{base_url}}/classes/9631/mcq/topics
Authorization: {{auth_qm_other_admin}}
HTTP 403

GET {{base_url}}/classes/9631/mcq/topics
Authorization: {{auth_qm_removed_admin}}
HTTP 403

GET {{base_url}}/classes/9631/mcq/topics
Authorization: {{auth_qm_nobody}}
HTTP 403

GET {{base_url}}/classes/9631/mcq/topics
Authorization: {{auth_qm_gents_admin}}
HTTP 403

GET {{base_url}}/classes/9631/mcq/topics
Authorization: {{auth_qm_coord}}
HTTP 403

# 4. The teacher, a class admin and a super admin: the distinct topics in order; the blank topic is left out; no other class's topic
GET {{base_url}}/classes/9631/mcq/topics
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$" count == 6
jsonpath "$[0]" == "A2 100% sure_"
jsonpath "$[1]" == "A2 Topic Beta"
jsonpath "$[2]" == "A2 topic deact"
jsonpath "$[3]" == "A2 topic edit"
jsonpath "$[4]" == "A2 topic one"
jsonpath "$[5]" == "A2 topic two"

GET {{base_url}}/classes/9631/mcq/topics
Authorization: {{auth_qm_admin}}
HTTP 200
[Asserts]
jsonpath "$" count == 6

GET {{base_url}}/classes/9631/mcq/topics
Authorization: {{auth_qm_super}}
HTTP 200
[Asserts]
jsonpath "$" count == 6

GET {{base_url}}/classes/9632/mcq/topics
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0]" == "A2 topic second"
