# POST /registrations/{registration_id}/place contract: put a waiting registrant in a class. Runs against any implementation.
# Variables: base_url and auth_<alias>. ENROLMENT fixtures (reset by tools/classes-contract.sh): registrations 9571 (900571, gents, waiting), 9572 (900572, ladies, waiting), 9573 (rejected), 9574 (already enrolled),
# 9575 and 9576 (900575: 9576 is the latest row); class 9420 (gents, empty), the ladies class 9414, the closed class 9417; the write admin (all), the gents admin 900501, the ladies admin 900502.

# 1. Without sign-in: 401
POST {{base_url}}/registrations/9571/place
{"classId": 9420}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A caller who may read no registrations: 403; nobody waiting under the id: 409
POST {{base_url}}/registrations/9571/place
Authorization: {{auth_en_teacher}}
{"classId": 9420}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/registrations/999999/place
Authorization: {{auth_wr_admin}}
{"classId": 9420}
HTTP 409
[Asserts]
jsonpath "$.detail" == "This registrant is no longer waiting: they have been placed or rejected."

POST {{base_url}}/registrations/9573/place
Authorization: {{auth_wr_admin}}
{"classId": 9420}
HTTP 409

POST {{base_url}}/registrations/9574/place
Authorization: {{auth_wr_admin}}
{"classId": 9420}
HTTP 409

POST {{base_url}}/registrations/9575/place
Authorization: {{auth_wr_admin}}
{"classId": 9420}
HTTP 409

# 3. An admin of the other gender than the registrant: 403
POST {{base_url}}/registrations/9571/place
Authorization: {{auth_en_ladmin}}
{"classId": 9420}
HTTP 403

POST {{base_url}}/registrations/9572/place
Authorization: {{auth_en_gadmin}}
{"classId": 14}
HTTP 403

# 4. The class: a JSON integer above 0 (422), an active class (404), one the caller may enrol into (403), of the registrant's gender (422)
POST {{base_url}}/registrations/9571/place
Authorization: {{auth_wr_admin}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "classId must be a class id"

POST {{base_url}}/registrations/9571/place
Authorization: {{auth_wr_admin}}
{"classId": "9420"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "classId must be a class id"

POST {{base_url}}/registrations/9571/place
Authorization: {{auth_wr_admin}}
{"classId": 0}
HTTP 422

POST {{base_url}}/registrations/9571/place
Authorization: {{auth_wr_admin}}
{"classId": -3}
HTTP 422

POST {{base_url}}/registrations/9571/place
Authorization: {{auth_wr_admin}}
Content-Type: application/json
```
{"classId": 94
```
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

POST {{base_url}}/registrations/9571/place
Authorization: {{auth_wr_admin}}
{"classId": 999999}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

POST {{base_url}}/registrations/9571/place
Authorization: {{auth_wr_admin}}
{"classId": 9417}
HTTP 404

POST {{base_url}}/registrations/9572/place
Authorization: {{auth_en_ladmin}}
{"classId": 9420}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to place members in this class"

POST {{base_url}}/registrations/9571/place
Authorization: {{auth_wr_admin}}
{"classId": 9414}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Could not place them: their gender does not match this class."

# ... and nobody was placed: still waiting, the class empty
GET {{base_url}}/classes/9420/students
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 0

# 5. The gents admin places the gents registrant: the class has them, and they stop waiting
POST {{base_url}}/registrations/9571/place
Authorization: {{auth_en_gadmin}}
{"classId": 9420}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.placed" == true
jsonpath "$.registrationId" == 9571
jsonpath "$.classId" == 9420

GET {{base_url}}/classes/9420/students
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 1
jsonpath "$.students[?(@.token==900571)].name" == "En Member 900571"

POST {{base_url}}/registrations/9571/place
Authorization: {{auth_wr_admin}}
{"classId": 9420}
HTTP 409
[Asserts]
jsonpath "$.detail" == "This registrant is no longer waiting: they have been placed or rejected."

# 6. The write admin places a member whose latest registration is 9576
POST {{base_url}}/registrations/9576/place
Authorization: {{auth_wr_admin}}
{"classId": 9420}
HTTP 200
[Asserts]
jsonpath "$.registrationId" == 9576
jsonpath "$.classId" == 9420

GET {{base_url}}/classes/9420/students
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 2
