# GET /me/children/{child_token}/classes/{class_id}/attendance contract: a linked child's attendance in a class. Runs against any implementation.
# Variables: base_url and auth_<alias>. Fixtures: child 900322 in class 9301 was present at both conducted sessions (recitation 3 and 2).

# 1. Without sign-in: 401
GET {{base_url}}/me/children/900322/classes/9301/attendance
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Not the caller's child, a revoked link, or a class the child never joined: 404
GET {{base_url}}/me/children/900322/classes/9301/attendance
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Child or class not found"

GET {{base_url}}/me/children/900323/classes/9302/attendance
Authorization: {{auth_parent}}
HTTP 404

GET {{base_url}}/me/children/900322/classes/9302/attendance
Authorization: {{auth_parent}}
HTTP 404

GET {{base_url}}/me/children/900324/classes/9301/attendance
Authorization: {{auth_parent}}
HTTP 404

# 3. A linked, enrolled child: summary and history, newest first
GET {{base_url}}/me/children/900322/classes/9301/attendance
Authorization: {{auth_parent}}
HTTP 200
[Asserts]
jsonpath "$.summary.total_sessions" == 2
jsonpath "$.summary.attended_sessions" == 2
jsonpath "$.summary.attendance_percentage" == 100.0
jsonpath "$.summary.total_recitation" == 5
jsonpath "$.history" count == 2
jsonpath "$.history[0].date" == "2025-09-20"
jsonpath "$.history[0].duration" == 45
jsonpath "$.history[0].present" == true
jsonpath "$.history[0].recitation" == 2
jsonpath "$.history[1].date" == "2025-09-06"
jsonpath "$.history[1].duration" == 60
jsonpath "$.history[1].recitation" == 3

# 4. A date bound narrows both the summary and the history
GET {{base_url}}/me/children/900322/classes/9301/attendance?end_date=2025-09-10
Authorization: {{auth_parent}}
HTTP 200
[Asserts]
jsonpath "$.summary.total_sessions" == 1
jsonpath "$.history" count == 1
jsonpath "$.history[0].date" == "2025-09-06"
