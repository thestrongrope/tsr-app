# POST /mcq/manage/{quiz_id}/copy contract: copy a quiz and its questions into another class. Runs against any implementation.
# Variables: base_url and auth_quizwrites_<alias> (tools/contract-quizwrites.sh). Fixtures: db/synthetic/quizwrites-fixtures.sql (read its header).
# Sources 9720009 (class 98201, 2 questions, not restricted) and 9720011 (98201; 9720010 in 98202 has the same name and topic in another case). Creates quizzes in classes 98202 and 98203 only (the next run's preparation deletes them).
# Copying is mcqs:copy on the source AND the target class: a super admin or a gender admin of that gender; the class teacher and a class admin student may NOT copy.

# 1. Without sign-in: 401
POST {{base_url}}/mcq/manage/9720009/copy
Content-Type: application/json
{"targetClassId": 98202}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A missing or non-numeric quiz is a 404, a quiz of a closed class is a class 404 (before any permission check)
POST {{base_url}}/mcq/manage/99999999/copy
Authorization: {{auth_quizwrites_nobody}}
Content-Type: application/json
{"targetClassId": 98202}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

POST {{base_url}}/mcq/manage/abc/copy
Authorization: {{auth_quizwrites_super}}
Content-Type: application/json
{"targetClassId": 98202}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

POST {{base_url}}/mcq/manage/9720012/copy
Authorization: {{auth_quizwrites_super}}
Content-Type: application/json
{"targetClassId": 98202}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 3. Refused on the source class, before the body is read (an empty body is still 403): the class teacher, a class admin student, a plain student, a student and the teacher of another class, a removed class admin, a member of no class, a ladies admin on a gents class
POST {{base_url}}/mcq/manage/9720009/copy
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to copy MCQs between these classes"

POST {{base_url}}/mcq/manage/9720009/copy
Authorization: {{auth_quizwrites_admin}}
Content-Type: application/json
{"targetClassId": 98202}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to copy MCQs between these classes"

POST {{base_url}}/mcq/manage/9720009/copy
Authorization: {{auth_quizwrites_student}}
Content-Type: application/json
{"targetClassId": 98202}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to copy MCQs between these classes"

POST {{base_url}}/mcq/manage/9720009/copy
Authorization: {{auth_quizwrites_other_student}}
Content-Type: application/json
{"targetClassId": 98202}
HTTP 403

POST {{base_url}}/mcq/manage/9720009/copy
Authorization: {{auth_quizwrites_other_teacher}}
Content-Type: application/json
{"targetClassId": 98203}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to copy MCQs between these classes"

POST {{base_url}}/mcq/manage/9720009/copy
Authorization: {{auth_quizwrites_removed_admin}}
Content-Type: application/json
{"targetClassId": 98202}
HTTP 403

POST {{base_url}}/mcq/manage/9720009/copy
Authorization: {{auth_quizwrites_nobody}}
Content-Type: application/json
{"targetClassId": 98202}
HTTP 403

POST {{base_url}}/mcq/manage/9720009/copy
Authorization: {{auth_quizwrites_ladies_admin}}
Content-Type: application/json
{"targetClassId": 98202}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to copy MCQs between these classes"

# 4. Body: targetClassId must be a number above 0 (422), then the target must be an active class (404), then permission on the target (403)
POST {{base_url}}/mcq/manage/9720009/copy
Authorization: {{auth_quizwrites_super}}
Content-Type: application/json
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "targetClassId is required"

POST {{base_url}}/mcq/manage/9720009/copy
Authorization: {{auth_quizwrites_super}}
Content-Type: application/json
{"targetClassId": "abc"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "targetClassId is required"

POST {{base_url}}/mcq/manage/9720009/copy
Authorization: {{auth_quizwrites_super}}
Content-Type: application/json
{"targetClassId": 0}
HTTP 422
[Asserts]
jsonpath "$.detail" == "targetClassId is required"

POST {{base_url}}/mcq/manage/9720009/copy
Authorization: {{auth_quizwrites_super}}
Content-Type: application/json
{"targetClassId": -5}
HTTP 422

POST {{base_url}}/mcq/manage/9720009/copy
Authorization: {{auth_quizwrites_super}}
Content-Type: application/json
{"targetClassId": 99999999}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

POST {{base_url}}/mcq/manage/9720009/copy
Authorization: {{auth_quizwrites_super}}
Content-Type: application/json
{"targetClassId": 98204}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

POST {{base_url}}/mcq/manage/9720009/copy
Authorization: {{auth_quizwrites_gents_admin}}
Content-Type: application/json
{"targetClassId": 98205}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to copy MCQs between these classes"

# 5. A quiz of the target class with the same name and topic (the case of the topic does not matter) is a conflict; nothing is created
POST {{base_url}}/mcq/manage/9720011/copy
Authorization: {{auth_quizwrites_super}}
Content-Type: application/json
{"targetClassId": 98202}
HTTP 409
[Asserts]
jsonpath "$.detail" == "A quiz with the same name & topic already exists in target class"

# 6. A super admin copies: 201 {success, id}; the copy is a draft with the same name, topic and restriction, a code of its own, and the questions with all five options
POST {{base_url}}/mcq/manage/9720009/copy
Authorization: {{auth_quizwrites_super}}
Content-Type: application/json
{"targetClassId": 98203}
HTTP 201
[Asserts]
jsonpath "$.success" == true
jsonpath "$.id" isInteger
[Captures]
copy_id: jsonpath "$.id"

GET {{base_url}}/mcq/manage/{{copy_id}}
Authorization: {{auth_quizwrites_other_teacher}}
HTTP 200
[Asserts]
jsonpath "$.classId" == 98203
jsonpath "$.code" matches /^[0-9A-Z]{8}$/
jsonpath "$.code" != "QWQ9720009"
jsonpath "$.name" == "Qw Copy Source"
jsonpath "$.topic" == "Qw copy topic"
jsonpath "$.restrictToClass" == 0
jsonpath "$.publishedAt" == null
jsonpath "$.questions" count == 2
jsonpath "$.questions[0].question" == "Qw copy q1"
jsonpath "$.questions[0].answer" == "Right a"
jsonpath "$.questions[0].option2" == "Wrong b"
jsonpath "$.questions[0].option3" == "Wrong c"
jsonpath "$.questions[0].option4" == "Wrong d"
jsonpath "$.questions[0].option5" == "Wrong e"
jsonpath "$.questions[1].answer" == "Right x"

# 7. The same copy again is now a duplicate
POST {{base_url}}/mcq/manage/9720009/copy
Authorization: {{auth_quizwrites_super}}
Content-Type: application/json
{"targetClassId": 98203}
HTTP 409
[Asserts]
jsonpath "$.detail" == "A quiz with the same name & topic already exists in target class"

# 8. A gents admin may copy between gents classes; so may the copy go into the class the quiz came from (no other quiz there has its name and topic... the source itself does: a conflict)
POST {{base_url}}/mcq/manage/9720011/copy
Authorization: {{auth_quizwrites_gents_admin}}
Content-Type: application/json
{"targetClassId": 98203}
HTTP 201

POST {{base_url}}/mcq/manage/9720011/copy
Authorization: {{auth_quizwrites_gents_admin}}
Content-Type: application/json
{"targetClassId": 98201}
HTTP 409
