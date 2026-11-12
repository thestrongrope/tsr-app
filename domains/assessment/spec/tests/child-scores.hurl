# GET /me/children/{child_token}/classes/{class_id}/scores contract: a linked child's quiz scores in a class. Runs against any implementation.
# Variables: base_url and auth_qz_<alias>. Fixtures: db/synthetic/assessment-a1-fixtures.sql. Parent 902410 has an active link to 902401 (the reader of the other files, classes 9621 and 9624); 902411's link is revoked;
# 902412 is the parent of 902402; 902413 of 902403 (removed from 9621); 902414 of 902405 (in no class).

# 1. Without sign-in: 401
GET {{base_url}}/me/children/902401/classes/9621/scores
HTTP 401

# 2. A linked, enrolled child: snake_case keys, newest attempt first, the percentage to one place as a float, the time with a space
GET {{base_url}}/me/children/902401/classes/9621/scores
Authorization: {{auth_qz_parent}}
HTTP 200
[Asserts]
jsonpath "$" count == 3
jsonpath "$[0].quiz_id" == 962406
jsonpath "$[0].quiz_name" == "A1 Quiz Zero Score"
jsonpath "$[0].score" == 0
jsonpath "$[0].total_questions" == 2
jsonpath "$[0].percentage" == 0.0
jsonpath "$[0].attempted_on" == "2026-02-03 11:00:00"
jsonpath "$[1].quiz_id" == 962404
jsonpath "$[1].percentage" == 100.0
jsonpath "$[2].quiz_id" == 962401
jsonpath "$[2].score" == 3
jsonpath "$[2].total_questions" == 4
jsonpath "$[2].percentage" == 75.0
jsonpath "$[2].attempted_on" == "2026-02-01 09:00:04"
jsonpath "$[2].questions" not exists
jsonpath "$[2].correctText" not exists

# A class the child is in with no answers: an empty list
GET {{base_url}}/me/children/902401/classes/9624/scores
Authorization: {{auth_qz_parent}}
HTTP 200
[Asserts]
jsonpath "$" count == 0

# 3. Dates bound each response's own time
GET {{base_url}}/me/children/902401/classes/9621/scores?start_date=2026-02-02&end_date=2026-02-02%2023:00:00
Authorization: {{auth_qz_parent}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].quiz_id" == 962404

GET {{base_url}}/me/children/902401/classes/9621/scores?end_date=2026-02-01
Authorization: {{auth_qz_parent}}
HTTP 200
[Asserts]
jsonpath "$" count == 0

GET {{base_url}}/me/children/902401/classes/9621/scores?start_date=abc
Authorization: {{auth_qz_parent}}
HTTP 200
[Asserts]
jsonpath "$" count == 3

GET {{base_url}}/me/children/902401/classes/9621/scores?end_date=abc
Authorization: {{auth_qz_parent}}
HTTP 200
[Asserts]
jsonpath "$" count == 0

# 4. Not this parent's child, or a link that is not active, or a class the child never joined: one 404
GET {{base_url}}/me/children/902401/classes/9621/scores
Authorization: {{auth_qz_parent_revoked}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Child or class not found"

GET {{base_url}}/me/children/902401/classes/9621/scores
Authorization: {{auth_qz_parent_other}}
HTTP 404

GET {{base_url}}/me/children/902401/classes/9621/scores
Authorization: {{auth_qz_stranger}}
HTTP 404

GET {{base_url}}/me/children/902401/classes/9621/scores
Authorization: {{auth_qz_reader}}
HTTP 404

GET {{base_url}}/me/children/902401/classes/9621/scores
Authorization: {{auth_qz_teacher}}
HTTP 404

GET {{base_url}}/me/children/902401/classes/9622/scores
Authorization: {{auth_qz_parent}}
HTTP 404

GET {{base_url}}/me/children/902405/classes/9621/scores
Authorization: {{auth_qz_parent_stranger_child}}
HTTP 404

GET {{base_url}}/me/children/902402/classes/9621/scores
Authorization: {{auth_qz_parent}}
HTTP 404

# The parent of the other child sees that child's own (empty) list
GET {{base_url}}/me/children/902402/classes/9621/scores
Authorization: {{auth_qz_parent_other}}
HTTP 200
[Asserts]
jsonpath "$" count == 0

# 5. PHP's own check, copied: any enrolment row counts, also a removed one
GET {{base_url}}/me/children/902403/classes/9621/scores
Authorization: {{auth_qz_parent_removed_child}}
HTTP 200
[Asserts]
jsonpath "$" count == 0

# 6. Ids that match nothing: 404
GET {{base_url}}/me/children/abc/classes/9621/scores
Authorization: {{auth_qz_parent}}
HTTP 404

GET {{base_url}}/me/children/0/classes/9621/scores
Authorization: {{auth_qz_parent}}
HTTP 404

GET {{base_url}}/me/children/-5/classes/9621/scores
Authorization: {{auth_qz_parent}}
HTTP 404

GET {{base_url}}/me/children/902401/classes/abc/scores
Authorization: {{auth_qz_parent}}
HTTP 404

GET {{base_url}}/me/children/902401/classes/99999999/scores
Authorization: {{auth_qz_parent}}
HTTP 404

GET {{base_url}}/me/children/99999999999999999999/classes/9621/scores
Authorization: {{auth_qz_parent}}
HTTP 404
