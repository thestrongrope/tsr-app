# GET /mcq/manage/{quiz_id}/offline contract: what recording answers students gave on paper needs: the questions WITH the right option marked (the answer key), and the class's students. Runs against any implementation.
# Variables: base_url and auth_quizwrites_<alias> (tools/contract-quizwrites.sh). Fixtures: db/synthetic/quizwrites-fixtures.sql (read its header). Quiz 9720002 (class 98201): question 1 has no stored option order,
# question 2 has "3,1,2", question 3 has a blank option 2 and an option 5. 922015 has an offline submission; 922012 answered on their phone (answers, NO submission row); 922011 has a @thestrongrope.com address. Writes nothing.

# 1. Without sign-in: 401
GET {{base_url}}/mcq/manage/9720002/offline
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A missing or non-numeric quiz is a 404, a quiz of a closed class is a class 404 (before any permission check)
GET {{base_url}}/mcq/manage/99999999/offline
Authorization: {{auth_quizwrites_student}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

GET {{base_url}}/mcq/manage/abc/offline
Authorization: {{auth_quizwrites_teacher}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

GET {{base_url}}/mcq/manage/9720012/offline
Authorization: {{auth_quizwrites_student}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 3. Refused, and no answer key in the reply: a plain student, a student of another class, the teacher and the class admin of another class, a removed class admin, a member of no class
GET {{base_url}}/mcq/manage/9720002/offline
Authorization: {{auth_quizwrites_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"
body not contains "isCorrect"

GET {{base_url}}/mcq/manage/9720002/offline
Authorization: {{auth_quizwrites_other_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"
body not contains "Right"

GET {{base_url}}/mcq/manage/9720002/offline
Authorization: {{auth_quizwrites_other_teacher}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"
body not contains "Right"

GET {{base_url}}/mcq/manage/9720002/offline
Authorization: {{auth_quizwrites_other_admin}}
HTTP 403

GET {{base_url}}/mcq/manage/9720002/offline
Authorization: {{auth_quizwrites_removed_admin}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"
body not contains "Right"

GET {{base_url}}/mcq/manage/9720002/offline
Authorization: {{auth_quizwrites_nobody}}
HTTP 403

# 4. The class teacher reads it: the options in the stored order (else natural order, blanks left out, option 5 only when no order is stored), the right one marked; the class's current students by name
GET {{base_url}}/mcq/manage/9720002/offline
Authorization: {{auth_quizwrites_teacher}}
HTTP 200
[Asserts]
jsonpath "$.quiz.id" == 9720002
jsonpath "$.quiz.name" == "Qw Offline Read"
jsonpath "$.quiz.topic" == "Qw topic offline"
jsonpath "$.quiz.classCode" == "QW-G-201"
jsonpath "$.quiz.className" == "Qw Class Main"
jsonpath "$.questions" count == 3
jsonpath "$.questions[0].id" == 9720504
jsonpath "$.questions[0].question" == "Qw offline q1"
jsonpath "$.questions[0].options" count == 4
jsonpath "$.questions[0].options[0].text" == "Right a"
jsonpath "$.questions[0].options[0].isCorrect" == true
jsonpath "$.questions[0].options[3].text" == "Wrong d"
jsonpath "$.questions[0].options[3].isCorrect" == false
jsonpath "$.questions[1].options" count == 3
jsonpath "$.questions[1].options[0].text" == "Wrong z"
jsonpath "$.questions[1].options[0].isCorrect" == false
jsonpath "$.questions[1].options[1].text" == "Right x"
jsonpath "$.questions[1].options[1].isCorrect" == true
jsonpath "$.questions[1].options[2].text" == "Wrong y"
jsonpath "$.questions[2].options" count == 3
jsonpath "$.questions[2].options[0].text" == "Right m"
jsonpath "$.questions[2].options[1].text" == "Wrong n"
jsonpath "$.questions[2].options[2].text" == "Wrong five"
jsonpath "$.students" count == 7
jsonpath "$.students[0].token" == 922002
jsonpath "$.students[0].name" == "Qw Member 922002"
jsonpath "$.students[0].isOffline" == false
jsonpath "$.students[0].submitted" == false
jsonpath "$.students[2].token" == 922011
jsonpath "$.students[2].isOffline" == true
jsonpath "$.students[3].token" == 922012
jsonpath "$.students[3].submitted" == false
jsonpath "$.students[6].token" == 922015
jsonpath "$.students[6].submitted" == true
jsonpath "$.students[6].isOffline" == false

# 5. A class admin student and a super admin read it too; the removed students (922005, 922016) are not listed
GET {{base_url}}/mcq/manage/9720002/offline
Authorization: {{auth_quizwrites_admin}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 7
jsonpath "$.questions" count == 3

GET {{base_url}}/mcq/manage/9720002/offline
Authorization: {{auth_quizwrites_super}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 7
