# GET /mcq/copy/classes/{class_id}/quizzes?topic= contract: the quizzes of a class and topic the caller may copy from. Runs against any implementation.
# Variables: base_url and auth_qm_<alias> (tools/assessment-contract.sh). Fixtures: db/synthetic/assessment-a2-fixtures.sql (read its header).
# The topic is matched with SQL LIKE, ignoring case: % and _ in it are wildcards (PHP's behaviour, copied). Newest first. Drafts and deactivated quizzes are listed too.

# 1. Without sign-in: 401
GET {{base_url}}/mcq/copy/classes/9631/quizzes?topic=x
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A missing or closed class is 404 before the permission check
GET {{base_url}}/mcq/copy/classes/99999999/quizzes?topic=x
Authorization: {{auth_qm_nobody}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/mcq/copy/classes/9634/quizzes?topic=x
Authorization: {{auth_qm_super}}
HTTP 404

# 3. Refused (copying is not managing): the teacher, a class admin, a plain student, a member of no class, a ladies admin on a gents class, a gents admin on a ladies class, a coordinator on an unassigned class
GET {{base_url}}/mcq/copy/classes/9631/quizzes?topic=A2%20topic%20two
Authorization: {{auth_qm_teacher}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to copy MCQs from this class"
jsonpath "$[0]" not exists

GET {{base_url}}/mcq/copy/classes/9631/quizzes?topic=A2%20topic%20two
Authorization: {{auth_qm_admin}}
HTTP 403

GET {{base_url}}/mcq/copy/classes/9631/quizzes?topic=A2%20topic%20two
Authorization: {{auth_qm_student}}
HTTP 403

GET {{base_url}}/mcq/copy/classes/9631/quizzes?topic=A2%20topic%20two
Authorization: {{auth_qm_nobody}}
HTTP 403

GET {{base_url}}/mcq/copy/classes/9631/quizzes?topic=A2%20topic%20two
Authorization: {{auth_qm_ladies_admin}}
HTTP 403

GET {{base_url}}/mcq/copy/classes/9636/quizzes?topic=A2%20topic%20two
Authorization: {{auth_qm_gents_admin}}
HTTP 403

GET {{base_url}}/mcq/copy/classes/9635/quizzes?topic=A2%20topic%20two
Authorization: {{auth_qm_coord}}
HTTP 403

# 4. The topic is required (after the permission check), trimmed; a blank one is 422
GET {{base_url}}/mcq/copy/classes/9631/quizzes
Authorization: {{auth_qm_super}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "topic is required"

GET {{base_url}}/mcq/copy/classes/9631/quizzes?topic=%20%20
Authorization: {{auth_qm_super}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "topic is required"

# 5. The quizzes of the topic, newest first, ignoring case; the shape is id, name, createdAt only (no answer, no questions)
GET {{base_url}}/mcq/copy/classes/9631/quizzes?topic=A2%20topic%20two
Authorization: {{auth_qm_super}}
HTTP 200
[Asserts]
jsonpath "$" count == 2
jsonpath "$[0].id" == 963403
jsonpath "$[0].name" == "A2 Quiz Deactivated"
jsonpath "$[0].createdAt" == "2026-01-03T09:00:00"
jsonpath "$[1].id" == 963402
jsonpath "$[0].questions" not exists
jsonpath "$[0].answer" not exists

GET {{base_url}}/mcq/copy/classes/9631/quizzes?topic=%20a2%20TOPIC%20TWO%20
Authorization: {{auth_qm_gents_admin}}
HTTP 200
[Asserts]
jsonpath "$" count == 2

GET {{base_url}}/mcq/copy/classes/9631/quizzes?topic=A2%20topic%20two
Authorization: {{auth_qm_coord}}
HTTP 200
[Asserts]
jsonpath "$" count == 2

# 6. LIKE wildcards are live (copied): _ matches one character, % any run (the topic "A2 topic tw_" is the two quizzes of "A2 topic two"; "%" is every quiz of the class)
GET {{base_url}}/mcq/copy/classes/9631/quizzes?topic=A2%20topic%20tw_
Authorization: {{auth_qm_super}}
HTTP 200
[Asserts]
jsonpath "$" count == 2

GET {{base_url}}/mcq/copy/classes/9631/quizzes?topic=A2%20100%25%20sure_
Authorization: {{auth_qm_super}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].id" == 963411

GET {{base_url}}/mcq/copy/classes/9631/quizzes?topic=%25
Authorization: {{auth_qm_super}}
HTTP 200
[Asserts]
jsonpath "$" count == 12
jsonpath "$[0].id" == 963412
jsonpath "$[11].id" == 963401

# 7. No match is an empty list; another class's quizzes are never in it
GET {{base_url}}/mcq/copy/classes/9631/quizzes?topic=A2%20topic%20second
Authorization: {{auth_qm_super}}
HTTP 200
[Asserts]
jsonpath "$" count == 0
