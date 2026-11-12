# GET /classes/{class_id}/mcq/manage contract: a class's quizzes for its teacher or class admin. Runs against any implementation.
# Variables: base_url and auth_qm_<alias> (tools/assessment-contract.sh). Fixtures: db/synthetic/assessment-a2-fixtures.sql (read its header).

# 1. Without sign-in: 401
GET {{base_url}}/classes/9631/mcq/manage
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A class that does not exist or is closed is 404 before any permission check, even for a member who could not manage it
GET {{base_url}}/classes/99999999/mcq/manage
Authorization: {{auth_qm_nobody}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/classes/9634/mcq/manage
Authorization: {{auth_qm_teacher}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 3. Who may not manage the class: a plain student, the admin of another class, a removed admin, a member of no class,
#    the teacher of another class, a gender admin and a coordinator (they may copy, not manage)
GET {{base_url}}/classes/9631/mcq/manage
Authorization: {{auth_qm_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

GET {{base_url}}/classes/9631/mcq/manage
Authorization: {{auth_qm_other_admin}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

GET {{base_url}}/classes/9631/mcq/manage
Authorization: {{auth_qm_removed_admin}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

GET {{base_url}}/classes/9631/mcq/manage
Authorization: {{auth_qm_nobody}}
HTTP 403

GET {{base_url}}/classes/9631/mcq/manage
Authorization: {{auth_qm_teacher2}}
HTTP 403

GET {{base_url}}/classes/9631/mcq/manage
Authorization: {{auth_qm_gents_admin}}
HTTP 403

GET {{base_url}}/classes/9631/mcq/manage
Authorization: {{auth_qm_coord}}
HTTP 403

GET {{base_url}}/classes/9631/mcq/manage
Authorization: {{auth_qm_admin2}}
HTTP 403

# 4. The class teacher, a class admin student and a super admin see the list, newest first (by id)
GET {{base_url}}/classes/9631/mcq/manage
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.total" == 12
jsonpath "$.page" == 1
jsonpath "$.pageSize" == 20
jsonpath "$.hasNext" == false
jsonpath "$.items" count == 12
jsonpath "$.items[0].id" == 963412
jsonpath "$.items[11].id" == 963401

GET {{base_url}}/classes/9631/mcq/manage
Authorization: {{auth_qm_admin}}
HTTP 200
[Asserts]
jsonpath "$.total" == 12

GET {{base_url}}/classes/9631/mcq/manage
Authorization: {{auth_qm_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 12

# 5. The shape of a row: a published quiz with answers, counts, the link; a draft has a null link; restrictToClass is an int
GET {{base_url}}/classes/9631/mcq/manage?pageSize=50
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.items[?(@.id==963402)].code" == "A2Q963402"
jsonpath "$.items[?(@.id==963402)].name" == "A2 Quiz Published"
jsonpath "$.items[?(@.id==963402)].topic" == "A2 topic two"
jsonpath "$.items[?(@.id==963402)].classId" == 9631
jsonpath "$.items[?(@.id==963402)].createdAt" == "2026-01-02T09:00:00"
jsonpath "$.items[?(@.id==963402)].publishedAt" == "2026-01-10T10:00:00"
jsonpath "$.items[?(@.id==963402)].deactivatedAt" == null
jsonpath "$.items[?(@.id==963402)].restrictToClass" == 0
jsonpath "$.items[?(@.id==963402)].questionCount" == 2
jsonpath "$.items[?(@.id==963402)].submittedCount" == 1
jsonpath "$.items[?(@.id==963402)].link" endsWith "/mcq/A2Q963402"
jsonpath "$.items[?(@.id==963401)].link" == null
jsonpath "$.items[?(@.id==963401)].questionCount" == 3
jsonpath "$.items[?(@.id==963401)].submittedCount" == 0
jsonpath "$.items[?(@.id==963403)].deactivatedAt" == "2026-01-15T10:00:00"
jsonpath "$.items[?(@.id==963411)].questionCount" == 0
# a quiz of another class is never listed
jsonpath "$.items[?(@.id==963421)]" not exists

# 6. Paging: pageSize 5, page 3 has the last two; a page past the end is empty; pageSize is cut to 50, raised to 1, a non-number is 1; page 0 is page 1
GET {{base_url}}/classes/9631/mcq/manage?pageSize=5&page=3
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.total" == 12
jsonpath "$.page" == 3
jsonpath "$.pageSize" == 5
jsonpath "$.hasNext" == false
jsonpath "$.items" count == 2
jsonpath "$.items[0].id" == 963402

GET {{base_url}}/classes/9631/mcq/manage?pageSize=5&page=2
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.hasNext" == true
jsonpath "$.items" count == 5

GET {{base_url}}/classes/9631/mcq/manage?pageSize=5&page=9
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.items" count == 0
jsonpath "$.hasNext" == false

GET {{base_url}}/classes/9631/mcq/manage?pageSize=500
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.pageSize" == 50

GET {{base_url}}/classes/9631/mcq/manage?pageSize=0&page=0
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.pageSize" == 1
jsonpath "$.page" == 1
jsonpath "$.items" count == 1

GET {{base_url}}/classes/9631/mcq/manage?pageSize=abc&page=xyz
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.pageSize" == 1
jsonpath "$.page" == 1
