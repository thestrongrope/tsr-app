# GET /classes contract: the caller's active classes. Runs against any implementation (tools/classes-contract.sh).
# Variables: base_url and auth_<alias>. Fixtures: class 9301 (gents, MIQDAD, two schedule slots, two tags; student 900311, teacher 900301), 9302 (ladies, BILAL), 9303 (closed).
# The admin sees every class of the database, so the admin cases pick the fixtures out of the list by id.

# 1. Without sign-in: 401
GET {{base_url}}/classes
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A student sees the active class they attend, with the card, the listing details and the schedule (day, hour, minute order)
GET {{base_url}}/classes
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$" count == 1
jsonpath "$[0].id" == 9301
jsonpath "$[0].code" == "CLS-G-001"
jsonpath "$[0].name" == "Cls Gents Class"
jsonpath "$[0].level" == 3
jsonpath "$[0].levelName" == "MIQDAD"
jsonpath "$[0].language" == 1
jsonpath "$[0].gender" == 1
jsonpath "$[0].status" == "A"
jsonpath "$[0].location" == "Cls Hall"
jsonpath "$[0].teacherName" == "Cls Teacher Gents"
jsonpath "$[0].teacherMobile" == "+910000003001"
jsonpath "$[0].format" == "Offline"
jsonpath "$[0].startedOn" == "2025-09-01"
jsonpath "$[0].role" == "attending"
jsonpath "$[0].joinUrl" == null
jsonpath "$[0].city" == "Mumbai"
jsonpath "$[0].country" == "India"
jsonpath "$[0].tags" count == 2
jsonpath "$[0].tags[0]" == "cls-beginners"
jsonpath "$[0].tags[1]" == "cls-evening"
jsonpath "$[0].studentCount" == null
jsonpath "$[0].schedules" count == 2
jsonpath "$[0].schedules[0].day" == 2
jsonpath "$[0].schedules[0].hour" == 9
jsonpath "$[0].schedules[0].minute" == 15
jsonpath "$[0].schedules[0].timezone" == "Asia/Kolkata"
jsonpath "$[0].schedules[1].day" == 6
jsonpath "$[0].link" not exists

# 3. The teacher sees the class as conducting; a closed class never shows
GET {{base_url}}/classes
Authorization: {{auth_teacher_g}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].id" == 9301
jsonpath "$[0].role" == "conducting"

# 4. A member in no class gets an empty list (a member without a gender too: the list needs no gender)
GET {{base_url}}/classes
Authorization: {{auth_outsider}}
HTTP 200
[Asserts]
jsonpath "$" count == 0

GET {{base_url}}/classes
Authorization: {{auth_nogender}}
HTTP 200
[Asserts]
jsonpath "$" count == 0

# 5. Filters: level and language are (int) casts. (q: PHP answers 500 to any q, a bug, so q is in classes-list-search-new-api.hurl)
GET {{base_url}}/classes?level=5
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$" count == 0

GET {{base_url}}/classes?level=3&language=1
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$" count == 1

# 6. include=managed gives a super admin every active class as managing, with the student count; conducting first, then newest id first
GET {{base_url}}/classes?include=managed
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$[?(@.id==9302)].role" == "managing"
jsonpath "$[?(@.id==9302)].studentCount" == 2
jsonpath "$[?(@.id==9301)].role" == "managing"
jsonpath "$[?(@.id==9301)].studentCount" == 2
jsonpath "$[?(@.id==9303)]" not exists

# 7. Without include=managed the admin sees only their own classes: none of the fixtures
GET {{base_url}}/classes
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$[?(@.id==9301)]" not exists
jsonpath "$[?(@.id==9302)]" not exists
