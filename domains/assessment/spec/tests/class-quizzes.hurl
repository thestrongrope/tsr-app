# GET /classes/{class_id}/mcq/quizzes contract: a class's published quizzes with the caller's own attempt. Runs against any implementation.
# Variables: base_url and auth_qz_<alias>. Fixtures: db/synthetic/assessment-a1-fixtures.sql. Class 9621 has 6 published quizzes (and a draft): newest first 962402, 962401, 962407, 962406, 962405, 962404.

# 1. Without sign-in: 401
GET {{base_url}}/classes/9621/mcq/quizzes
HTTP 401

# 2. A student's own attempts: score, total and percent only once attempted
GET {{base_url}}/classes/9621/mcq/quizzes
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.total" == 6
jsonpath "$.page" == 1
jsonpath "$.pageSize" == 20
jsonpath "$.hasNext" == false
jsonpath "$.items" count == 6
jsonpath "$.items[0].id" == 962402
jsonpath "$.items[0].code" == "A1Q962402"
jsonpath "$.items[0].topic" == null
jsonpath "$.items[0].classId" == 9621
jsonpath "$.items[0].publishedAt" == "2026-01-20T10:00:00"
jsonpath "$.items[0].questionCount" == 3
jsonpath "$.items[0].attempted" == false
jsonpath "$.items[0].score" == null
jsonpath "$.items[0].total" == null
jsonpath "$.items[0].percent" == null
jsonpath "$.items[1].id" == 962401
jsonpath "$.items[1].topic" == "A1 topic one"
jsonpath "$.items[1].attempted" == true
jsonpath "$.items[1].score" == 3
jsonpath "$.items[1].total" == 4
jsonpath "$.items[1].percent" == 75.0
jsonpath "$.items[2].id" == 962407
jsonpath "$.items[2].questionCount" == 0
jsonpath "$.items[2].attempted" == false
jsonpath "$.items[3].id" == 962406
jsonpath "$.items[3].attempted" == true
jsonpath "$.items[3].score" == 0
jsonpath "$.items[3].total" == 2
jsonpath "$.items[3].percent" == 0.0
jsonpath "$.items[4].id" == 962405
jsonpath "$.items[5].id" == 962404
jsonpath "$.items[5].score" == 2
jsonpath "$.items[5].percent" == 100.0
jsonpath "$.items[0].questions" not exists
jsonpath "$.items[0].correctText" not exists

# 3. A classmate has their own figures, not the reader's (another student answered 962401 4 of 4, the reader 3 of 4)
GET {{base_url}}/classes/9621/mcq/quizzes
Authorization: {{auth_qz_fresh}}
HTTP 200
[Asserts]
jsonpath "$.items[1].attempted" == false
jsonpath "$.items[1].score" == null
jsonpath "$.items[5].attempted" == false

# 4. Paging as PHP reads it
GET {{base_url}}/classes/9621/mcq/quizzes?pageSize=2&page=2
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.total" == 6
jsonpath "$.page" == 2
jsonpath "$.pageSize" == 2
jsonpath "$.hasNext" == true
jsonpath "$.items" count == 2
jsonpath "$.items[0].id" == 962407
jsonpath "$.items[1].id" == 962406

GET {{base_url}}/classes/9621/mcq/quizzes?pageSize=2&page=3
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.hasNext" == false
jsonpath "$.items" count == 2

GET {{base_url}}/classes/9621/mcq/quizzes?pageSize=2&page=9
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.hasNext" == false
jsonpath "$.items" count == 0
jsonpath "$.total" == 6

GET {{base_url}}/classes/9621/mcq/quizzes?pageSize=0&page=abc
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.page" == 1
jsonpath "$.pageSize" == 1
jsonpath "$.hasNext" == true

GET {{base_url}}/classes/9621/mcq/quizzes?pageSize=500&page=-3
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.page" == 1
jsonpath "$.pageSize" == 100

# 5. The second class of the reader
GET {{base_url}}/classes/9624/mcq/quizzes
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.total" == 1
jsonpath "$.items[0].id" == 962411

# 6. Not a current student of an active class: 403 from access (not 404): left, enrolment status I, the teacher, a stranger,
#    another class, a closed class (even for its own student), a class that does not exist
GET {{base_url}}/classes/9621/mcq/quizzes
Authorization: {{auth_qz_removed}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/classes/9621/mcq/quizzes
Authorization: {{auth_qz_inactive}}
HTTP 403

GET {{base_url}}/classes/9621/mcq/quizzes
Authorization: {{auth_qz_teacher}}
HTTP 403

GET {{base_url}}/classes/9621/mcq/quizzes
Authorization: {{auth_qz_stranger}}
HTTP 403

GET {{base_url}}/classes/9622/mcq/quizzes
Authorization: {{auth_qz_reader}}
HTTP 403

GET {{base_url}}/classes/9623/mcq/quizzes
Authorization: {{auth_qz_closed}}
HTTP 403

GET {{base_url}}/classes/99999999/mcq/quizzes
Authorization: {{auth_qz_reader}}
HTTP 403

GET {{base_url}}/classes/abc/mcq/quizzes
Authorization: {{auth_qz_reader}}
HTTP 403

GET {{base_url}}/classes/99999999999999999999/mcq/quizzes
Authorization: {{auth_qz_reader}}
HTTP 403

# 7. A member with no gender passes access and is then refused
GET {{base_url}}/classes/9621/mcq/quizzes
Authorization: {{auth_qz_nogender}}
HTTP 400
[Asserts]
jsonpath "$.detail" == "User gender not set; update profile first"
