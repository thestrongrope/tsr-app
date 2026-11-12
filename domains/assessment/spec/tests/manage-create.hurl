# POST /classes/{class_id}/mcq contract: create an empty quiz (a draft) in a class. Runs against any implementation.
# Variables: base_url and auth_quizwrites_<alias> (tools/contract-quizwrites.sh). Fixtures: db/synthetic/quizwrites-fixtures.sql (read its header).
# Creates quizzes in class 98201 only (the next run's preparation deletes them).

# 1. Without sign-in: 401
POST {{base_url}}/classes/98201/mcq
Content-Type: application/json
{"name": "Qw New", "topic": "Qw new topic"}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A missing, non-numeric or closed class is a 404 before any permission check
POST {{base_url}}/classes/99999999/mcq
Authorization: {{auth_quizwrites_nobody}}
Content-Type: application/json
{"name": "Qw New", "topic": "Qw new topic"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

POST {{base_url}}/classes/abc/mcq
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"name": "Qw New", "topic": "Qw new topic"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

POST {{base_url}}/classes/98204/mcq
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"name": "Qw New", "topic": "Qw new topic"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 3. Refused: a plain student, a student of another class, the teacher of another class, a class admin of another class, a removed class admin, a member of no class
POST {{base_url}}/classes/98201/mcq
Authorization: {{auth_quizwrites_student}}
Content-Type: application/json
{"name": "Qw New", "topic": "Qw new topic"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

POST {{base_url}}/classes/98201/mcq
Authorization: {{auth_quizwrites_other_student}}
Content-Type: application/json
{"name": "Qw New", "topic": "Qw new topic"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

POST {{base_url}}/classes/98201/mcq
Authorization: {{auth_quizwrites_other_teacher}}
Content-Type: application/json
{"name": "Qw New", "topic": "Qw new topic"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

POST {{base_url}}/classes/98201/mcq
Authorization: {{auth_quizwrites_other_admin}}
Content-Type: application/json
{"name": "Qw New", "topic": "Qw new topic"}
HTTP 403

POST {{base_url}}/classes/98201/mcq
Authorization: {{auth_quizwrites_removed_admin}}
Content-Type: application/json
{"name": "Qw New", "topic": "Qw new topic"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

POST {{base_url}}/classes/98201/mcq
Authorization: {{auth_quizwrites_nobody}}
Content-Type: application/json
{"name": "Qw New", "topic": "Qw new topic"}
HTTP 403

# 4. The permission check comes before the body check: a student with an empty body is 403
POST {{base_url}}/classes/98201/mcq
Authorization: {{auth_quizwrites_student}}
Content-Type: application/json
{}
HTTP 403

# 5. Body rules, the name first: blank (spaces only) or missing is "name is required", then the topic
POST {{base_url}}/classes/98201/mcq
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"topic": "Qw new topic"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "name is required"

POST {{base_url}}/classes/98201/mcq
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"name": "   ", "topic": "Qw new topic"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "name is required"

POST {{base_url}}/classes/98201/mcq
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"name": "Qw New"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "topic is required"

POST {{base_url}}/classes/98201/mcq
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"name": "Qw New", "topic": "   "}
HTTP 422
[Asserts]
jsonpath "$.detail" == "topic is required"

# 6. The teacher creates: 201 {id}; the quiz is a draft with the trimmed name and topic, restricted to the class, and a code of 8 characters (digits and upper-case letters, as PHP's trigger makes)
POST {{base_url}}/classes/98201/mcq
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"name": "  Qw New  ", "topic": "  Qw new topic  "}
HTTP 201
[Asserts]
jsonpath "$.id" isInteger
[Captures]
new_id: jsonpath "$.id"

GET {{base_url}}/mcq/manage/{{new_id}}
Authorization: {{auth_quizwrites_teacher}}
HTTP 200
[Asserts]
jsonpath "$.id" == {{new_id}}
jsonpath "$.code" matches /^[0-9A-Z]{8}$/
jsonpath "$.name" == "Qw New"
jsonpath "$.topic" == "Qw new topic"
jsonpath "$.classId" == 98201
jsonpath "$.restrictToClass" == 1
jsonpath "$.publishedAt" == null
jsonpath "$.deactivatedAt" == null
jsonpath "$.link" == null
jsonpath "$.questions" count == 0
[Captures]
new_code: jsonpath "$.code"

# 7. A class admin student creates too; restrictToClass 0 opens the quiz; two quizzes get two different codes
POST {{base_url}}/classes/98201/mcq
Authorization: {{auth_quizwrites_admin}}
Content-Type: application/json
{"name": "Qw Open", "topic": "Qw new topic", "restrictToClass": 0}
HTTP 201
[Captures]
open_id: jsonpath "$.id"

GET {{base_url}}/mcq/manage/{{open_id}}
Authorization: {{auth_quizwrites_admin}}
HTTP 200
[Asserts]
jsonpath "$.restrictToClass" == 0
jsonpath "$.code" matches /^[0-9A-Z]{8}$/
jsonpath "$.code" != {{new_code}}

# 8. Any other restrictToClass keeps the quiz restricted (a text "0" too: PHP compares the integer of it)
POST {{base_url}}/classes/98201/mcq
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"name": "Qw Text Zero", "topic": "Qw new topic", "restrictToClass": "0"}
HTTP 201
[Captures]
zero_id: jsonpath "$.id"

GET {{base_url}}/mcq/manage/{{zero_id}}
Authorization: {{auth_quizwrites_teacher}}
HTTP 200
[Asserts]
jsonpath "$.restrictToClass" == 0

POST {{base_url}}/classes/98201/mcq
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"name": "Qw Two", "topic": "Qw new topic", "restrictToClass": 2}
HTTP 201
[Captures]
two_id: jsonpath "$.id"

GET {{base_url}}/mcq/manage/{{two_id}}
Authorization: {{auth_quizwrites_teacher}}
HTTP 200
[Asserts]
jsonpath "$.restrictToClass" == 1
