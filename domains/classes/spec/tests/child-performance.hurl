# GET /me/children/{child_token}/classes/{class_id}/performance contract: a linked child's attendance and quiz summary. Runs against any implementation.
# Variables: base_url and auth_<alias>. Fixtures: child 900322 in class 9301 attended both sessions and answered one quiz question, rightly.

# 1. Without sign-in: 401
GET {{base_url}}/me/children/900322/classes/9301/performance
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Not the caller's child, or a class the child never joined: 404
GET {{base_url}}/me/children/900322/classes/9301/performance
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Child or class not found"

GET {{base_url}}/me/children/900322/classes/9302/performance
Authorization: {{auth_parent}}
HTTP 404

# 3. A linked, enrolled child: the figures, percentages as floats
GET {{base_url}}/me/children/900322/classes/9301/performance
Authorization: {{auth_parent}}
HTTP 200
[Asserts]
jsonpath "$.attendance.total_sessions" == 2
jsonpath "$.attendance.attended_sessions" == 2
jsonpath "$.attendance.attendance_percentage" == 100.0
jsonpath "$.attendance.total_recitation" == 5
jsonpath "$.quizzes.quizzes_attempted" == 1
jsonpath "$.quizzes.quiz_average_score" == 100.0

# 4. The dates bound the quiz responses by their own time (answered "now") and the sessions
GET {{base_url}}/me/children/900322/classes/9301/performance?start_date=2030-01-01
Authorization: {{auth_parent}}
HTTP 200
[Asserts]
jsonpath "$.attendance.total_sessions" == 0
jsonpath "$.quizzes.quizzes_attempted" == 0
jsonpath "$.quizzes.quiz_average_score" == 0.0

GET {{base_url}}/me/children/900322/classes/9301/performance?start_date=2025-9-10
Authorization: {{auth_parent}}
HTTP 200
[Asserts]
jsonpath "$.attendance.total_sessions" == 1
