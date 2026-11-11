# POST /classes/{class_id}/students contract: enrol one member; answers with the roster. Runs against any implementation.
# Variables: base_url and auth_<alias>. ENROLMENT fixtures (reset by tools/classes-contract.sh): class 9413 (gents; teacher 900511; 900544 active, 900545 removed), free members 900541 (gents), 900542 (ladies),
# 900543 (no gender), 900546 (gender text 'Male'), the closed class 9417, the gents admin 900501, the ladies admin 900502, the write admin 900331.

# 1. Without sign-in: 401
POST {{base_url}}/classes/9413/students
{"token": 900541}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Unknown or closed class: 404 before the permission check
POST {{base_url}}/classes/999999/students
Authorization: {{auth_en_student}}
{"token": 900541}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

POST {{base_url}}/classes/9417/students
Authorization: {{auth_wr_admin}}
{"token": 900541}
HTTP 404

# 3. A student, the class's own teacher, and an admin of the other gender: 403
POST {{base_url}}/classes/9413/students
Authorization: {{auth_en_student}}
{"token": 900541}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to change this class's students"

POST {{base_url}}/classes/9413/students
Authorization: {{auth_en_teacher}}
{"token": 900541}
HTTP 403

POST {{base_url}}/classes/9413/students
Authorization: {{auth_en_ladmin}}
{"token": 900541}
HTTP 403

# 4. The token: a JSON integer above zero
POST {{base_url}}/classes/9413/students
Authorization: {{auth_wr_admin}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "token must be a member's token"

POST {{base_url}}/classes/9413/students
Authorization: {{auth_wr_admin}}
{"token": "900541"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "token must be a member's token"

POST {{base_url}}/classes/9413/students
Authorization: {{auth_wr_admin}}
{"token": 900541.5}
HTTP 422

POST {{base_url}}/classes/9413/students
Authorization: {{auth_wr_admin}}
{"token": 0}
HTTP 422

POST {{base_url}}/classes/9413/students
Authorization: {{auth_wr_admin}}
{"token": -5}
HTTP 422

POST {{base_url}}/classes/9413/students
Authorization: {{auth_wr_admin}}
Content-Type: application/json
```
{"token": 9005
```
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

# 5. Not a member, or a gender that does not match the class: the same refusal
POST {{base_url}}/classes/9413/students
Authorization: {{auth_wr_admin}}
{"token": 900549}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Could not add 900549: not a registered member, or their gender does not match this class."

POST {{base_url}}/classes/9413/students
Authorization: {{auth_wr_admin}}
{"token": 99999999999}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Could not add 99999999999: not a registered member, or their gender does not match this class."

POST {{base_url}}/classes/9413/students
Authorization: {{auth_wr_admin}}
{"token": 900542}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Could not add 900542: not a registered member, or their gender does not match this class."

# ... and nobody was added
GET {{base_url}}/classes/9413/students
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 1

# 6. The gents admin adds a member of the class's gender: on the roster with the contact details of the roster payload
POST {{base_url}}/classes/9413/students
Authorization: {{auth_en_gadmin}}
{"token": 900541}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.students" count == 2
jsonpath "$.students[?(@.token==900541)].name" == "En Member 900541"
jsonpath "$.students[?(@.token==900541)].email" == "en.900541@example.invalid"
jsonpath "$.students[?(@.token==900541)].mcqAdmin" == false

# 7. A member with no recorded gender, and one whose gender is the text 'Male', may be added
POST {{base_url}}/classes/9413/students
Authorization: {{auth_wr_admin}}
{"token": 900543}
HTTP 200
[Asserts]
jsonpath "$.students" count == 3

POST {{base_url}}/classes/9413/students
Authorization: {{auth_wr_admin}}
{"token": 900546}
HTTP 200
[Asserts]
jsonpath "$.students" count == 4

# 8. Adding a member who is already enrolled changes nothing
POST {{base_url}}/classes/9413/students
Authorization: {{auth_wr_admin}}
{"token": 900541}
HTTP 200
[Asserts]
jsonpath "$.students" count == 4

POST {{base_url}}/classes/9413/students
Authorization: {{auth_wr_admin}}
{"token": 900544}
HTTP 200
[Asserts]
jsonpath "$.students" count == 4

# 9. A removed member is enrolled again (a new row): on the roster, off the removed list
POST {{base_url}}/classes/9413/students
Authorization: {{auth_wr_admin}}
{"token": 900545}
HTTP 200
[Asserts]
jsonpath "$.students" count == 5
jsonpath "$.students[?(@.token==900545)].name" == "En Member 900545"
jsonpath "$.removedStudents" count == 0

GET {{base_url}}/classes/9413/students
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 5
