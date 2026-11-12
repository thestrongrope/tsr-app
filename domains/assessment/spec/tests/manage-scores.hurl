# GET /mcq/manage/{quiz_id}/scores contract: every student who answered a quiz with their correct count (students' names and scores: the class's managers only). Runs against any implementation.
# Variables: base_url and auth_quizwrites_<alias> (tools/contract-quizwrites.sh). Fixtures: db/synthetic/quizwrites-fixtures.sql (read its header). Quiz 9720001 (class 98201, 3 questions) is answered by 922003 (2 right of 3),
# 922012 (3 of 3), two members both named "Qw Twin" (2 right of 2, 0 of 1) and a token that has no member row (left out). Writes nothing.

# 1. Without sign-in: 401
GET {{base_url}}/mcq/manage/9720001/scores
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A missing or non-numeric quiz is a 404, a quiz of a closed class is a class 404 (before any permission check)
GET {{base_url}}/mcq/manage/99999999/scores
Authorization: {{auth_quizwrites_student}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

GET {{base_url}}/mcq/manage/abc/scores
Authorization: {{auth_quizwrites_teacher}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

GET {{base_url}}/mcq/manage/9720012/scores
Authorization: {{auth_quizwrites_student}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 3. Refused, and no name or score in the answer: a plain student (one who answered it too), a student of another class, the teacher and the class admin of another class, a removed class admin, a member of no class
GET {{base_url}}/mcq/manage/9720001/scores
Authorization: {{auth_quizwrites_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"
body not contains "Qw Member"

GET {{base_url}}/mcq/manage/9720001/scores
Authorization: {{auth_quizwrites_phone_student}}
HTTP 403

GET {{base_url}}/mcq/manage/9720001/scores
Authorization: {{auth_quizwrites_other_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

GET {{base_url}}/mcq/manage/9720001/scores
Authorization: {{auth_quizwrites_other_teacher}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

GET {{base_url}}/mcq/manage/9720001/scores
Authorization: {{auth_quizwrites_other_admin}}
HTTP 403

GET {{base_url}}/mcq/manage/9720001/scores
Authorization: {{auth_quizwrites_removed_admin}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

GET {{base_url}}/mcq/manage/9720001/scores
Authorization: {{auth_quizwrites_nobody}}
HTTP 403

# 4. The class teacher, a class admin student and a super admin read the scores: rows grouped by NAME (the two twins are one row), newest first, the member without a row left out
GET {{base_url}}/mcq/manage/9720001/scores
Authorization: {{auth_quizwrites_teacher}}
HTTP 200
[Asserts]
jsonpath "$.quiz.id" == 9720001
jsonpath "$.quiz.name" == "Qw Scores"
jsonpath "$.quiz.topic" == "Qw topic scores"
jsonpath "$.quiz.classCode" == "QW-G-201"
jsonpath "$.total" == 3
jsonpath "$.items" count == 3
jsonpath "$.items[0].name" == "Qw Twin"
jsonpath "$.items[0].correct" == 2
jsonpath "$.items[0].outof" == 3
jsonpath "$.items[0].submitted" == "2026-02-03T09:00:03"
jsonpath "$.items[1].name" == "Qw Member 922012"
jsonpath "$.items[1].correct" == 3
jsonpath "$.items[1].outof" == 3
jsonpath "$.items[1].submitted" == "2026-02-02T09:00:03"
jsonpath "$.items[2].name" == "Qw Member 922003"
jsonpath "$.items[2].correct" == 2
jsonpath "$.items[2].outof" == 3
jsonpath "$.items[2].submitted" == "2026-02-01T09:00:03"

GET {{base_url}}/mcq/manage/9720001/scores
Authorization: {{auth_quizwrites_admin}}
HTTP 200
[Asserts]
jsonpath "$.total" == 3

GET {{base_url}}/mcq/manage/9720001/scores
Authorization: {{auth_quizwrites_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 3

# 5. A quiz nobody answered: an empty list
GET {{base_url}}/mcq/manage/9720007/scores
Authorization: {{auth_quizwrites_teacher}}
HTTP 200
[Asserts]
jsonpath "$.total" == 0
jsonpath "$.items" count == 0
jsonpath "$.quiz.classCode" == "QW-G-201"
