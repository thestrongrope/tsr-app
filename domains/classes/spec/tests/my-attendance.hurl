# GET /classes/{class_id}/my-attendance contract: the caller's own attendance, newest conducted session first. Runs against any implementation.
# Variables: base_url and auth_<alias>. Fixtures: class 9301 has two conducted sessions (2025-09-20, 2025-09-06) and one not conducted (09-13).
# Student 900311: absent on 09-20, present on 09-06 with recitation 5.

# 1. Without sign-in: 401
GET {{base_url}}/classes/9301/my-attendance
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Not in the class (never, or removed), unknown class, closed class: 404 with PHP's text
GET {{base_url}}/classes/9301/my-attendance
Authorization: {{auth_outsider}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found or not enrolled"

GET {{base_url}}/classes/9301/my-attendance
Authorization: {{auth_removed}}
HTTP 404

GET {{base_url}}/classes/9303/my-attendance
Authorization: {{auth_student_g}}
HTTP 404

GET {{base_url}}/classes/999999/my-attendance
Authorization: {{auth_student_g}}
HTTP 404

# 3. No numeric gender: 400
GET {{base_url}}/classes/9301/my-attendance
Authorization: {{auth_nogender}}
HTTP 400
[Asserts]
jsonpath "$.detail" == "User gender not set; update profile first"

# 4. A student sees the conducted sessions only, newest first, absent where no attendance row exists
GET {{base_url}}/classes/9301/my-attendance
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$" count == 2
jsonpath "$[0].sessionId" isInteger
jsonpath "$[0].conductedOn" == "2025-09-20"
jsonpath "$[0].present" == false
jsonpath "$[0].recitation" == 0
jsonpath "$[1].conductedOn" == "2025-09-06"
jsonpath "$[1].present" == true
jsonpath "$[1].recitation" == 5

# 5. The class's teacher passes the guard and sees every session as absent
GET {{base_url}}/classes/9301/my-attendance
Authorization: {{auth_teacher_g}}
HTTP 200
[Asserts]
jsonpath "$" count == 2
jsonpath "$[1].present" == false

# 6. A start date bounds the list (inclusive)
GET {{base_url}}/classes/9301/my-attendance?start_date=2025-09-10
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].conductedOn" == "2025-09-20"

GET {{base_url}}/classes/9301/my-attendance?start_date=2025-09-06&end_date=2025-09-06
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].conductedOn" == "2025-09-06"

# 7. A bound is read as MariaDB reads a date: a time part, one digit parts, or no separators
GET {{base_url}}/classes/9301/my-attendance?end_date=2025-09-06T00:00:00
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].conductedOn" == "2025-09-06"

GET {{base_url}}/classes/9301/my-attendance?start_date=2025-9-10
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].conductedOn" == "2025-09-20"

GET {{base_url}}/classes/9301/my-attendance?start_date=20250910
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].conductedOn" == "2025-09-20"
