# POST /classes/{class_id}/mcq/standard/{mcq_id}/copy contract: a new quiz in a class made from a standard MCQ. Runs against any implementation.
# Variables: base_url and auth_quizwrites_<alias> (tools/contract-quizwrites.sh). Fixtures: db/synthetic/quizwrites-fixtures.sql (read its header); standard MCQs QW-S1 (id 9720101, 2 questions) and QW-S2 (9720102, 1 question).
# Creates quizzes in classes 98201 and 98203 only (the next run's preparation deletes them).

# 1. Without sign-in: 401
POST {{base_url}}/classes/98201/mcq/standard/9720101/copy
Content-Type: application/json
{}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A missing, non-numeric or closed class is a 404 before any permission check
POST {{base_url}}/classes/99999999/mcq/standard/9720101/copy
Authorization: {{auth_quizwrites_nobody}}
Content-Type: application/json
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

POST {{base_url}}/classes/abc/mcq/standard/9720101/copy
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

POST {{base_url}}/classes/98204/mcq/standard/9720101/copy
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 3. Refused (and nothing created): a plain student, a student of another class, the teacher and the class admin of another class, a removed class admin, a member of no class
POST {{base_url}}/classes/98201/mcq/standard/9720101/copy
Authorization: {{auth_quizwrites_student}}
Content-Type: application/json
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

POST {{base_url}}/classes/98201/mcq/standard/9720101/copy
Authorization: {{auth_quizwrites_other_student}}
Content-Type: application/json
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

POST {{base_url}}/classes/98201/mcq/standard/9720101/copy
Authorization: {{auth_quizwrites_other_teacher}}
Content-Type: application/json
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

POST {{base_url}}/classes/98201/mcq/standard/9720101/copy
Authorization: {{auth_quizwrites_other_admin}}
Content-Type: application/json
{}
HTTP 403

POST {{base_url}}/classes/98201/mcq/standard/9720101/copy
Authorization: {{auth_quizwrites_removed_admin}}
Content-Type: application/json
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

POST {{base_url}}/classes/98201/mcq/standard/9720101/copy
Authorization: {{auth_quizwrites_nobody}}
Content-Type: application/json
{}
HTTP 403

# 4. The permission check comes before the standard MCQ is looked up: a student naming a missing standard is 403; a manager is 404
POST {{base_url}}/classes/98201/mcq/standard/99999999/copy
Authorization: {{auth_quizwrites_student}}
Content-Type: application/json
{}
HTTP 403

POST {{base_url}}/classes/98201/mcq/standard/99999999/copy
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Standard MCQ not found"

POST {{base_url}}/classes/98201/mcq/standard/abc/copy
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Standard MCQ not found"

# 5. The teacher copies: 201 {success, id}; the quiz is a draft named "subject - lesson - name" with the standard's topic, restricted to the class; its questions come with the standard's right answer first
POST {{base_url}}/classes/98201/mcq/standard/9720101/copy
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{}
HTTP 201
[Asserts]
jsonpath "$.success" == true
jsonpath "$.id" isInteger
[Captures]
copy_id: jsonpath "$.id"

GET {{base_url}}/mcq/manage/{{copy_id}}
Authorization: {{auth_quizwrites_teacher}}
HTTP 200
[Asserts]
jsonpath "$.classId" == 98201
jsonpath "$.code" matches /^[0-9A-Z]{8}$/
jsonpath "$.name" == "Qw Subject Two - Qw lesson 1 - Qw standard one"
jsonpath "$.topic" == "Qw Topic Beta"
jsonpath "$.restrictToClass" == 1
jsonpath "$.publishedAt" == null
jsonpath "$.questions" count == 2
jsonpath "$.questions[0].question" == "S1 q1"
jsonpath "$.questions[0].answer" == "Right1"
jsonpath "$.questions[0].option2" == "Wrong1a"
jsonpath "$.questions[0].option3" == "Wrong1b"
jsonpath "$.questions[0].option4" == null
jsonpath "$.questions[1].question" == "S1 q2"
jsonpath "$.questions[1].answer" == "Right2"
jsonpath "$.questions[1].option2" == "Wrong2a"
jsonpath "$.questions[1].option3" == null

# 6. There is no duplicate rule: the same standard MCQ copied again into the same class is another quiz
POST {{base_url}}/classes/98201/mcq/standard/9720101/copy
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{}
HTTP 201
[Asserts]
jsonpath "$.id" != {{copy_id}}

# 7. A class admin student and the teacher of another class (into their own class) copy too; a standard with three wrong options keeps all four
POST {{base_url}}/classes/98201/mcq/standard/9720102/copy
Authorization: {{auth_quizwrites_admin}}
Content-Type: application/json
{}
HTTP 201
[Captures]
admin_copy_id: jsonpath "$.id"

GET {{base_url}}/mcq/manage/{{admin_copy_id}}
Authorization: {{auth_quizwrites_admin}}
HTTP 200
[Asserts]
jsonpath "$.name" == "Qw Subject One - Qw lesson 2 - Qw standard two"
jsonpath "$.questions" count == 1
jsonpath "$.questions[0].answer" == "Right3"
jsonpath "$.questions[0].option2" == "Wrong3a"
jsonpath "$.questions[0].option3" == "Wrong3b"
jsonpath "$.questions[0].option4" == "Wrong3c"

POST {{base_url}}/classes/98203/mcq/standard/9720101/copy
Authorization: {{auth_quizwrites_other_teacher}}
Content-Type: application/json
{}
HTTP 201
