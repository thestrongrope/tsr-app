# GET /subscribers/{token} contract: a registered person who is in no class, for a caller who reaches every class. Variables: base_url and auth_<alias>.
# Fixtures: 901171 (ladies; registrations 951311 for class 9562 and the latest, 951312 for 9561), 901172 (in a live class), 901173 (gender Male, no registration), 901174 (no gender; a registration for a class that no longer exists),
# 901175 (only a closed class), 901176 (enrolment removed). 901107 is a super admin, 901109 a gents admin (role 3), 901110 a plain member.

# 1. Without sign-in: 401
GET {{base_url}}/subscribers/901171
HTTP 401

# 2. A super admin gets the card: name, gender, the day of the latest registration and its class code, no contact details
GET {{base_url}}/subscribers/901171
Authorization: {{auth_b4b_card_admin}}
HTTP 200
[Asserts]
jsonpath "$.token" == 901171
jsonpath "$.name" == "B4B Member 901171"
jsonpath "$.gender" == 2
jsonpath "$.registeredOn" == "2025-03-04"
jsonpath "$.requestedClass" == "B4B-G-61"
jsonpath "$.email" not exists
jsonpath "$.mobile" not exists

# 3. The word Male is gender 1; no registration is null twice
GET {{base_url}}/subscribers/901173
Authorization: {{auth_b4b_card_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.registeredOn" == null
jsonpath "$.requestedClass" == null

# 4. No gender is null; a registration for a class that is gone has a day and no class
GET {{base_url}}/subscribers/901174
Authorization: {{auth_b4b_card_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == null
jsonpath "$.registeredOn" == "2025-03-05"
jsonpath "$.requestedClass" == null

# 5. A closed class or a removal does not make a student
GET {{base_url}}/subscribers/901175
Authorization: {{auth_b4b_card_admin}}
HTTP 200

GET {{base_url}}/subscribers/901176
Authorization: {{auth_b4b_card_admin}}
HTTP 200

# 6. A student, an unknown member, token 0 and text are all the same 404
GET {{base_url}}/subscribers/901172
Authorization: {{auth_b4b_card_admin}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Person not found"

GET {{base_url}}/subscribers/999999999
Authorization: {{auth_b4b_card_admin}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Person not found"

GET {{base_url}}/subscribers/0
Authorization: {{auth_b4b_card_admin}}
HTTP 404

GET {{base_url}}/subscribers/abc
Authorization: {{auth_b4b_card_admin}}
HTTP 404

# 7. A caller who reaches only one gender's classes, or only their own, learns nothing: the same 404
GET {{base_url}}/subscribers/901171
Authorization: {{auth_b4b_gents_admin}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Person not found"

GET {{base_url}}/subscribers/901171
Authorization: {{auth_b4b_plain}}
HTTP 404
