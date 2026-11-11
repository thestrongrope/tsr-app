# GET /classes/{class_id}/my-performance contract: the caller's attendance and quiz figures in a class. Runs against any implementation.
# Variables: base_url and auth_<alias>. Fixtures: student 900311 in class 9301: 2 conducted sessions, present once (recitation 5), one quiz answered 1 of 2 right.

# 1. Without sign-in: 401
GET {{base_url}}/classes/9301/my-performance
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Not in the class: 404. No numeric gender: 400
GET {{base_url}}/classes/9301/my-performance
Authorization: {{auth_outsider}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found or not enrolled"

GET {{base_url}}/classes/9301/my-performance
Authorization: {{auth_nogender}}
HTTP 400
[Asserts]
jsonpath "$.detail" == "User gender not set; update profile first"

# 3. A student: the figures, with percentages as floats
GET {{base_url}}/classes/9301/my-performance
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$.totalSessions" == 2
jsonpath "$.attendedSessions" == 1
jsonpath "$.attendancePercent" == 50.0
jsonpath "$.totalRecitation" == 5
jsonpath "$.averageRecitation" == 5.0
jsonpath "$.quizzesAttempted" == 1
jsonpath "$.quizAverageScore" == 50.0

# 4. The teacher is in the class but attends nothing: zeros, floats still floats
GET {{base_url}}/classes/9301/my-performance
Authorization: {{auth_teacher_g}}
HTTP 200
[Asserts]
jsonpath "$.totalSessions" == 2
jsonpath "$.attendedSessions" == 0
jsonpath "$.attendancePercent" == 0.0
jsonpath "$.averageRecitation" == 0.0
jsonpath "$.quizzesAttempted" == 0
jsonpath "$.quizAverageScore" == 0.0

# 5. A start date bounds the sessions
GET {{base_url}}/classes/9301/my-performance?start_date=2025-09-10
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$.totalSessions" == 1
jsonpath "$.attendedSessions" == 0
jsonpath "$.attendancePercent" == 0.0

# 6. The dates bound the sessions (what MariaDB reads as a date: not only Y-m-d) and the quiz responses by their own time (the fixture answered "now")
GET {{base_url}}/classes/9301/my-performance?start_date=2030-01-01
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$.totalSessions" == 0
jsonpath "$.quizzesAttempted" == 0
jsonpath "$.quizAverageScore" == 0.0

GET {{base_url}}/classes/9301/my-performance?end_date=2030-01-01
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$.totalSessions" == 2
jsonpath "$.quizzesAttempted" == 1
jsonpath "$.quizAverageScore" == 50.0

GET {{base_url}}/classes/9301/my-performance?end_date=2025-09-06T00:00:00
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$.totalSessions" == 1
jsonpath "$.attendedSessions" == 1
jsonpath "$.quizzesAttempted" == 0

GET {{base_url}}/classes/9301/my-performance?start_date=2025-9-10
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$.totalSessions" == 1
jsonpath "$.attendedSessions" == 0

GET {{base_url}}/classes/9301/my-performance?start_date=20250910
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$.totalSessions" == 1
jsonpath "$.attendedSessions" == 0

# 7. A figure that is not 50 or 100: the ladies student answered 3 of the ladies quiz, one right (1 of 3, two places)
GET {{base_url}}/classes/9302/my-performance
Authorization: {{auth_student_l}}
HTTP 200
[Asserts]
jsonpath "$.quizzesAttempted" == 1
jsonpath "$.quizAverageScore" == 33.33

