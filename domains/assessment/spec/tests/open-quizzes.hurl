# GET /mcq/open contract: the quizzes the caller may attempt now, across their classes. Runs against any implementation.
# Variables: base_url and auth_qz_<alias>. Fixtures: db/synthetic/assessment-a1-fixtures.sql. Reader (classes 9621 and 9624) answered 962401, 962404 and 962406.

# 1. Without sign-in: 401
GET {{base_url}}/mcq/open
HTTP 401

# 2. Across classes, newest published first; answered, deactivated and draft quizzes are left out
GET {{base_url}}/mcq/open
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.items" count == 3
jsonpath "$.items[0].id" == 962411
jsonpath "$.items[0].code" == "A1Q962411"
jsonpath "$.items[0].name" == "A1 Second Class Quiz"
jsonpath "$.items[0].topic" == null
jsonpath "$.items[0].classCode" == "A1-G-624"
jsonpath "$.items[1].id" == 962402
jsonpath "$.items[1].classCode" == "A1-G-621"
jsonpath "$.items[2].id" == 962407

# 3. Another student of the class sees the quizzes the reader answered, and the order is by publish time (the answered quiz comes back for them)
GET {{base_url}}/mcq/open
Authorization: {{auth_qz_fresh}}
HTTP 200
[Asserts]
jsonpath "$.items" count == 4
jsonpath "$.items[0].id" == 962402
jsonpath "$.items[1].id" == 962401
jsonpath "$.items[1].topic" == "A1 topic one"
jsonpath "$.items[2].id" == 962407
jsonpath "$.items[3].id" == 962406

# 4. A closed class's quiz is listed for its student (PHP does not read the class status)
GET {{base_url}}/mcq/open
Authorization: {{auth_qz_closed_fresh}}
HTTP 200
[Asserts]
jsonpath "$.items" count == 1
jsonpath "$.items[0].id" == 962421
jsonpath "$.items[0].classCode" == "A1-G-623"

# 5. No gender check: the member without gender gets their list (962401 is answered)
GET {{base_url}}/mcq/open
Authorization: {{auth_qz_nogender}}
HTTP 200
[Asserts]
jsonpath "$.items" count == 3
jsonpath "$.items[0].id" == 962402

# 6. Nothing for a student who left, one whose enrolment is not active, a teacher, a stranger
GET {{base_url}}/mcq/open
Authorization: {{auth_qz_removed}}
HTTP 200
[Asserts]
jsonpath "$.items" count == 0

GET {{base_url}}/mcq/open
Authorization: {{auth_qz_inactive}}
HTTP 200
[Asserts]
jsonpath "$.items" count == 0

GET {{base_url}}/mcq/open
Authorization: {{auth_qz_teacher}}
HTTP 200
[Asserts]
jsonpath "$.items" count == 0

GET {{base_url}}/mcq/open
Authorization: {{auth_qz_stranger}}
HTTP 200
[Asserts]
jsonpath "$.items" count == 0
