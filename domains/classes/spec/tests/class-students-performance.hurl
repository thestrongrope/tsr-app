# GET /classes/{class_id}/students/performance?from&to contract: each current student's attendance, quiz results and recitation over a range. Runs against any implementation.
# Variables: base_url and auth_<alias>. Fixtures: class 9301 (students 900311 and 900322; sessions on 2025-09-06 (60 min, both present, recitation 5 and 3), 2025-09-13 (not conducted), 2025-09-20 (900311 absent,
# 900322 present, recitation 0 and 2); quiz 9301 published 2025-09-06 12:00 with three questions, answered by 900311 (two, one right) and 900322 (one, right)). Quiz topics are set in the fixtures.

# 1. Without sign-in: 401
GET {{base_url}}/classes/9301/students/performance
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Unknown or closed class: 404 before the permission check
GET {{base_url}}/classes/999999/students/performance
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/classes/9303/students/performance
Authorization: {{auth_admin}}
HTTP 404

# 3. A plain student and an outsider: 403
GET {{base_url}}/classes/9301/students/performance
Authorization: {{auth_student_g}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to see this class's student figures"

GET {{base_url}}/classes/9301/students/performance
Authorization: {{auth_outsider}}
HTTP 403

# 4. Range rules: 422
GET {{base_url}}/classes/9301/students/performance?from=2025-9-1&to=2025-12-31
Authorization: {{auth_admin}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be dates as YYYY-MM-DD"

GET {{base_url}}/classes/9301/students/performance?from=2025-02-30&to=2025-12-31
Authorization: {{auth_admin}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be dates as YYYY-MM-DD"

GET {{base_url}}/classes/9301/students/performance?from=2025-12-31&to=2025-01-01
Authorization: {{auth_admin}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from must not be after to"

GET {{base_url}}/classes/9301/students/performance?from=2024-01-01&to=2025-01-02
Authorization: {{auth_admin}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The range can cover at most a year"

# 5. The range of 366 days is allowed; the figures of the whole of 2025
GET {{base_url}}/classes/9301/students/performance?from=2025-01-01&to=2025-12-31
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.from" == "2025-01-01"
jsonpath "$.to" == "2025-12-31"
jsonpath "$.totalMcqs" == 1
jsonpath "$.maxMarks.total" == 3
jsonpath "$.maxMarks.topics" count == 1
jsonpath "$.maxMarks.topics[0].name" == "Quran"
jsonpath "$.maxMarks.topics[0].max" == 3
jsonpath "$.students" count == 2
jsonpath "$.students[?(@.token==900311)].name" == "Cls Student Gents"
jsonpath "$.students[?(@.token==900311)].expected" == 2
jsonpath "$.students[?(@.token==900311)].present" == 1
jsonpath "$.students[?(@.token==900311)].attendance" == 50
jsonpath "$.students[?(@.token==900311)].mcqAttempted" == 1
jsonpath "$.students[?(@.token==900311)].mcqCorrect" == 1
jsonpath "$.students[?(@.token==900311)].topics.Quran" == 1
jsonpath "$.students[?(@.token==900311)].recitation" == 5
jsonpath "$.students[?(@.token==900322)].expected" == 2
jsonpath "$.students[?(@.token==900322)].present" == 2
jsonpath "$.students[?(@.token==900322)].attendance" == 100
jsonpath "$.students[?(@.token==900322)].mcqCorrect" == 1
jsonpath "$.students[?(@.token==900322)].recitation" == 5
jsonpath "$.students[?(@.token==900316)]" not exists

# 6. A quiz published on the day `to` after midnight is out of the range (PHP compares the time with the date's midnight); sessions of the day `to` are in
GET {{base_url}}/classes/9301/students/performance?from=2025-09-01&to=2025-09-06
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.totalMcqs" == 0
jsonpath "$.maxMarks.total" == 0
jsonpath "$.maxMarks.topics" count == 0
jsonpath "$.students[?(@.token==900311)].expected" == 1
jsonpath "$.students[?(@.token==900311)].attendance" == 100
jsonpath "$.students[?(@.token==900311)].mcqAttempted" == 0
jsonpath "$.students[?(@.token==900311)].topics" count == 0

# 7. An empty range of sessions: zeros
GET {{base_url}}/classes/9301/students/performance?from=2024-01-01&to=2024-06-30
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.totalMcqs" == 0
jsonpath "$.students[?(@.token==900311)].expected" == 0
jsonpath "$.students[?(@.token==900311)].attendance" == 0
jsonpath "$.students[?(@.token==900311)].recitation" == 0

# 8. Without dates the range is the last year up to today: the fixture sessions are older, so the figures are zero
GET {{base_url}}/classes/9301/students/performance
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.from" matches /^\d{4}-\d{2}-\d{2}$/
jsonpath "$.to" matches /^\d{4}-\d{2}-\d{2}$/
jsonpath "$.students" count == 2
