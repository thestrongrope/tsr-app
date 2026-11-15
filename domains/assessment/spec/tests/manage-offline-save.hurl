# POST /mcq/manage/{quiz_id}/offline contract: record the answers students gave on paper, ALL students or none. Runs against any implementation.
# Variables: base_url and auth_quizwrites_<alias> (tools/contract-quizwrites.sh). Fixtures: db/synthetic/quizwrites-fixtures.sql (read its header).
# Writes quizzes 9720003 (3 questions 9720507 to 9720509; 922015 already has an offline submission; students 922013 and 922014 get answers here) and 9720004 (2 questions; 922012 answered on their phone: answers but NO submission row) only.
# Students of class 98201: 922002, 922003, 922011 to 922015 (922005 and 922016 were removed); 922006 is a student of another class.

# 1. Without sign-in: 401
POST {{base_url}}/mcq/manage/9720003/offline
Content-Type: application/json
{"students": [{"token": 922013, "correct": [9720507]}]}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A missing or non-numeric quiz is a 404, a quiz of a closed class is a class 404 (before any permission check)
POST {{base_url}}/mcq/manage/99999999/offline
Authorization: {{auth_quizwrites_student}}
Content-Type: application/json
{"students": [{"token": 922013, "correct": []}]}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

POST {{base_url}}/mcq/manage/abc/offline
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"students": [{"token": 922013, "correct": []}]}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

POST {{base_url}}/mcq/manage/9720012/offline
Authorization: {{auth_quizwrites_student}}
Content-Type: application/json
{"students": [{"token": 922013, "correct": []}]}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 3. Refused, nothing written: a plain student, a student of another class, the teacher and the class admin of another class, a removed class admin, a member of no class (an empty body is still 403: permission comes before the body)
POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_student}}
Content-Type: application/json
{"students": [{"token": 922013, "correct": [9720507]}]}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_phone_student}}
Content-Type: application/json
{}
HTTP 403

POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_other_student}}
Content-Type: application/json
{"students": [{"token": 922013, "correct": [9720507]}]}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_other_teacher}}
Content-Type: application/json
{"students": [{"token": 922013, "correct": [9720507]}]}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_other_admin}}
Content-Type: application/json
{"students": [{"token": 922013, "correct": [9720507]}]}
HTTP 403

POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_removed_admin}}
Content-Type: application/json
{"students": [{"token": 922013, "correct": [9720507]}]}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_nobody}}
Content-Type: application/json
{"students": [{"token": 922013, "correct": [9720507]}]}
HTTP 403

# 4. Body rules (422): students must be a non-empty list; each entry needs a correct list
POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "students is required"

POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"students": []}
HTTP 422
[Asserts]
jsonpath "$.detail" == "students is required"

POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"students": "922013"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "students is required"

POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"students": [{"token": 922013}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "each student needs a token and a correct list"

POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"students": [{"token": 922013, "correct": "9720507"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "each student needs a token and a correct list"

POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"students": [5]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "each student needs a token and a correct list"

# 5. Student by student: no token (400), a student not enrolled in this class, one who was removed (403), a question of another quiz (400); the first refusal wins
POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"students": [{"correct": []}]}
HTTP 400
[Asserts]
jsonpath "$.detail" == "Malformed response payload."

POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"students": [{"token": 922013, "correct": [9720507]}, {"token": 922006, "correct": []}]}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Student 922006 is not enrolled in this class."

POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"students": [{"token": 922016, "correct": []}]}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Student 922016 is not enrolled in this class."

POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"students": [{"token": 922013, "correct": [9720504]}]}
HTTP 400
[Asserts]
jsonpath "$.detail" == "Question 9720504 does not belong to this quiz."

POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"students": [{"token": 922006, "correct": [9720504]}]}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Student 922006 is not enrolled in this class."

# 6. A student who already has an offline submission: 409 with the conflict list, and the other students of the batch are NOT saved
POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"students": [{"token": 922013, "correct": [9720507]}, {"token": 922015, "correct": [9720507]}]}
HTTP 409
[Asserts]
jsonpath "$.detail" == "One or more students already have submissions."
jsonpath "$.conflicts" count == 1
jsonpath "$.conflicts[0]" == 922015

GET {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_teacher}}
HTTP 200
[Asserts]
jsonpath "$.students[?(@.token==922013)].submitted" == false

# 7. A student who answered on their phone (answers but no submission row): refused too, but the answer has NO conflicts list, and the rest of the batch is not saved
POST {{base_url}}/mcq/manage/9720004/offline
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"students": [{"token": 922012, "correct": [9720510]}]}
HTTP 409
[Asserts]
jsonpath "$.detail" == "One or more students already have submissions."
jsonpath "$.conflicts" not exists

POST {{base_url}}/mcq/manage/9720004/offline
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"students": [{"token": 922013, "correct": [9720510]}, {"token": 922012, "correct": []}]}
HTTP 409
[Asserts]
jsonpath "$.conflicts" not exists

GET {{base_url}}/mcq/manage/9720004/offline
Authorization: {{auth_quizwrites_teacher}}
HTTP 200
[Asserts]
jsonpath "$.students[?(@.token==922013)].submitted" == false
jsonpath "$.students[?(@.token==922012)].submitted" == false

# 8. The teacher saves one student, a class admin another: 200 {saved}; the students then show as submitted
POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"students": [{"token": 922013, "correct": [9720507, 9720509]}]}
HTTP 200
[Asserts]
jsonpath "$.saved" == 1

POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_admin}}
Content-Type: application/json
{"students": [{"token": 922014, "correct": []}]}
HTTP 200
[Asserts]
jsonpath "$.saved" == 1

GET {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_teacher}}
HTTP 200
[Asserts]
jsonpath "$.students[?(@.token==922013)].submitted" == true
jsonpath "$.students[?(@.token==922014)].submitted" == true

# 9. The students' own scores are what the teacher entered: the listed questions right, the others wrong (as an online result is counted)
GET {{base_url}}/mcq/quizzes/9720003/my-score
Authorization: {{auth_quizwrites_s13}}
HTTP 200
[Asserts]
jsonpath "$.total" == 3
jsonpath "$.answered" == 3
jsonpath "$.correct" == 2

GET {{base_url}}/mcq/quizzes/9720003/my-score
Authorization: {{auth_quizwrites_s14}}
HTTP 200
[Asserts]
jsonpath "$.total" == 3
jsonpath "$.answered" == 3
jsonpath "$.correct" == 0

# 10. Entering the same student again is a conflict with the list
POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"students": [{"token": 922013, "correct": []}]}
HTTP 409
[Asserts]
jsonpath "$.conflicts[0]" == 922013

# 11. Two entries for one token in a batch: the first position and the LAST list count (one student saved)
POST {{base_url}}/mcq/manage/9720003/offline
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{"students": [{"token": 922011, "correct": [9720507]}, {"token": 922011, "correct": [9720507, 9720508]}]}
HTTP 200
[Asserts]
jsonpath "$.saved" == 1
