# GET /mcq/manage/{quiz_id}/sheet contract: the printable question sheet of a quiz as a PDF (no answer marked). Runs against any implementation.
# Variables: base_url and auth_quizwrites_<alias> (tools/contract-quizwrites.sh). Fixtures: db/synthetic/quizwrites-fixtures.sql (read its header). Quiz 9720005 (class 98201, code QWQ9720005) has two questions, one with markup, a quote and Arabic text,
# and no stored option order; 9720006 has no questions. The sheet FIXES AND STORES the option order of every question that has none (a GET that writes, as PHP): the second call must show the same order. The page itself is checked
# by a database test with a fake renderer (db/tests/TestQuizwritesTests.cs); here only the answer's status, headers and the PDF magic.

# 1. Without sign-in: 401
GET {{base_url}}/mcq/manage/9720005/sheet
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A missing or non-numeric quiz is a 404, a quiz of a closed class is a class 404 (before any permission check)
GET {{base_url}}/mcq/manage/99999999/sheet
Authorization: {{auth_quizwrites_student}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

GET {{base_url}}/mcq/manage/abc/sheet
Authorization: {{auth_quizwrites_teacher}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

GET {{base_url}}/mcq/manage/9720012/sheet
Authorization: {{auth_quizwrites_student}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 3. Refused, and no question text in the reply: a plain student, a student of another class, the teacher and the class admin of another class, a removed class admin, a member of no class
GET {{base_url}}/mcq/manage/9720005/sheet
Authorization: {{auth_quizwrites_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

GET {{base_url}}/mcq/manage/9720005/sheet
Authorization: {{auth_quizwrites_other_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

GET {{base_url}}/mcq/manage/9720005/sheet
Authorization: {{auth_quizwrites_other_teacher}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

GET {{base_url}}/mcq/manage/9720005/sheet
Authorization: {{auth_quizwrites_other_admin}}
HTTP 403

GET {{base_url}}/mcq/manage/9720005/sheet
Authorization: {{auth_quizwrites_removed_admin}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

GET {{base_url}}/mcq/manage/9720005/sheet
Authorization: {{auth_quizwrites_nobody}}
HTTP 403

# 4. A quiz with no questions: 404 (the check is after the permission check, so a student is still 403)
GET {{base_url}}/mcq/manage/9720006/sheet
Authorization: {{auth_quizwrites_student}}
HTTP 403

GET {{base_url}}/mcq/manage/9720006/sheet
Authorization: {{auth_quizwrites_teacher}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "This MCQ has no questions"

# 5. Before the first sheet the quiz shows its natural option order (the right answer first)
GET {{base_url}}/mcq/manage/9720005/offline
Authorization: {{auth_quizwrites_teacher}}
HTTP 200
[Asserts]
jsonpath "$.questions[0].options[0].isCorrect" == true

# 6. The teacher gets a PDF with a file name from the quiz code; a class admin student and a super admin too
GET {{base_url}}/mcq/manage/9720005/sheet
Authorization: {{auth_quizwrites_teacher}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/pdf"
header "Content-Disposition" contains "MCQ_QWQ9720005.pdf"
bytes startsWith hex,25504446;

GET {{base_url}}/mcq/manage/9720005/sheet
Authorization: {{auth_quizwrites_admin}}
HTTP 200
[Asserts]
bytes startsWith hex,25504446;

# 7. The order is now stored: the offline screen follows it (its right answer is still marked), and a second sheet leaves it as it was
GET {{base_url}}/mcq/manage/9720005/offline
Authorization: {{auth_quizwrites_teacher}}
HTTP 200
[Asserts]
jsonpath "$.questions[0].options" count == 4
jsonpath "$.questions[0].options[?(@.isCorrect==true)].text" == "Right <i>a</i>"
[Captures]
a0: jsonpath "$.questions[0].options[0].text"
a1: jsonpath "$.questions[0].options[1].text"
a2: jsonpath "$.questions[0].options[2].text"
a3: jsonpath "$.questions[0].options[3].text"
b0: jsonpath "$.questions[1].options[0].text"
b1: jsonpath "$.questions[1].options[1].text"

GET {{base_url}}/mcq/manage/9720005/sheet
Authorization: {{auth_quizwrites_super}}
HTTP 200
[Asserts]
bytes startsWith hex,25504446;

GET {{base_url}}/mcq/manage/9720005/offline
Authorization: {{auth_quizwrites_teacher}}
HTTP 200
[Asserts]
jsonpath "$.questions[0].options[0].text" == "{{a0}}"
jsonpath "$.questions[0].options[1].text" == "{{a1}}"
jsonpath "$.questions[0].options[2].text" == "{{a2}}"
jsonpath "$.questions[0].options[3].text" == "{{a3}}"
jsonpath "$.questions[1].options[0].text" == "{{b0}}"
jsonpath "$.questions[1].options[1].text" == "{{b1}}"
