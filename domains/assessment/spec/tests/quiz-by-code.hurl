# GET /mcq/by-code/{code} contract: what opening an MCQ link does for the caller. Runs against any implementation.
# Variables: base_url and auth_qz_<alias>. Fixtures: db/synthetic/assessment-a1-fixtures.sql (codes A1Q<quiz id>).

# 1. Without sign-in: 401
GET {{base_url}}/mcq/by-code/A1Q962402
HTTP 401

# 2. open (released, live, not answered), whatever the case of the code; the quiz id is given
GET {{base_url}}/mcq/by-code/A1Q962402
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.state" == "open"
jsonpath "$.quizId" == 962402
jsonpath "$.name" not exists

GET {{base_url}}/mcq/by-code/a1q962402
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.state" == "open"
jsonpath "$.quizId" == 962402

# 3. attempted (the caller has answers; also when the quiz is deactivated now), with the id
GET {{base_url}}/mcq/by-code/A1Q962401
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.state" == "attempted"
jsonpath "$.quizId" == 962401

GET {{base_url}}/mcq/by-code/A1Q962404
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.state" == "attempted"
jsonpath "$.quizId" == 962404

# 4. closed (released, deactivated, not answered) and not_released (a draft): no id
GET {{base_url}}/mcq/by-code/A1Q962405
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.state" == "closed"
jsonpath "$.quizId" == null

GET {{base_url}}/mcq/by-code/A1Q962403
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.state" == "not_released"
jsonpath "$.quizId" == null

# A closed class's quiz is open to its student (PHP does not look at the class status)
GET {{base_url}}/mcq/by-code/A1Q962421
Authorization: {{auth_qz_closed_fresh}}
HTTP 200
[Asserts]
jsonpath "$.state" == "open"

# 5. not_eligible: not a current student of the quiz's class says only that, whatever the quiz's state (another class, left, status I, a teacher, a stranger)
GET {{base_url}}/mcq/by-code/A1Q962431
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.state" == "not_eligible"
jsonpath "$.quizId" == null

GET {{base_url}}/mcq/by-code/A1Q962403
Authorization: {{auth_qz_stranger}}
HTTP 200
[Asserts]
jsonpath "$.state" == "not_eligible"

GET {{base_url}}/mcq/by-code/A1Q962402
Authorization: {{auth_qz_removed}}
HTTP 200
[Asserts]
jsonpath "$.state" == "not_eligible"

GET {{base_url}}/mcq/by-code/A1Q962402
Authorization: {{auth_qz_inactive}}
HTTP 200
[Asserts]
jsonpath "$.state" == "not_eligible"

GET {{base_url}}/mcq/by-code/A1Q962402
Authorization: {{auth_qz_teacher}}
HTTP 200
[Asserts]
jsonpath "$.state" == "not_eligible"

# 6. not_found: no such code, or not 1 to 32 ASCII letters and digits
GET {{base_url}}/mcq/by-code/nope
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.state" == "not_found"
jsonpath "$.quizId" == null

GET {{base_url}}/mcq/by-code/a-b
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.state" == "not_found"

GET {{base_url}}/mcq/by-code/A1Q962402%20
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.state" == "not_found"

GET {{base_url}}/mcq/by-code/A1Q%C3%A9
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.state" == "not_found"

GET {{base_url}}/mcq/by-code/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
Authorization: {{auth_qz_reader}}
HTTP 200
[Asserts]
jsonpath "$.state" == "not_found"

# 7. No gender check on this route: a member without a gender gets the same answers
GET {{base_url}}/mcq/by-code/A1Q962402
Authorization: {{auth_qz_nogender}}
HTTP 200
[Asserts]
jsonpath "$.state" == "open"
