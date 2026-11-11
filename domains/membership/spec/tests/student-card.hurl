# GET /students/{token} contract: a member in an active class, with only the classes the caller's classes:read reaches. Variables: base_url and auth_<alias>.
# Fixtures (B4b and B5b): 901172 is in 9561 (B4B-G-61, MIQDAD, gents); 901181 is in 9561 and in 9562 (B4B-L-62, ABUZAR, ladies); 901175 only in the closed class 9563; 901176 left 9561; 901173 is in no class.
# 901107 (b4b_card_admin) is a super admin, 901109 (b4b_gents_admin) a gents admin (role 3), b5b_ladies_admin a ladies admin (role 4), b5b_plain a plain member.

# 1. Without sign-in: 401; a plain member holds classes:read but reaches no class: 404
GET {{base_url}}/students/901172
HTTP 401

GET {{base_url}}/students/901172
Authorization: {{auth_b5b_plain}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Person not found"

# 2. A super admin gets the card: name, gender, every current class with its level name, no contact details
GET {{base_url}}/students/901172
Authorization: {{auth_b4b_card_admin}}
HTTP 200
[Asserts]
jsonpath "$.token" == 901172
jsonpath "$.name" == "B4B Member 901172"
jsonpath "$.gender" == 1
jsonpath "$.classes" count == 1
jsonpath "$.classes[0].id" == 9561
jsonpath "$.classes[0].code" == "B4B-G-61"
jsonpath "$.classes[0].level" == "MIQDAD"
jsonpath "$.email" not exists
jsonpath "$.mobile" not exists

GET {{base_url}}/students/901181
Authorization: {{auth_b4b_card_admin}}
HTTP 200
[Asserts]
jsonpath "$.classes" count == 2
jsonpath "$.classes[0].code" == "B4B-G-61"
jsonpath "$.classes[1].id" == 9562
jsonpath "$.classes[1].code" == "B4B-L-62"
jsonpath "$.classes[1].level" == "ABUZAR"

# 3. A gender administrator sees only the classes of their gender; a member in none of them is 404
GET {{base_url}}/students/901181
Authorization: {{auth_b4b_gents_admin}}
HTTP 200
[Asserts]
jsonpath "$.classes" count == 1
jsonpath "$.classes[0].code" == "B4B-G-61"

GET {{base_url}}/students/901181
Authorization: {{auth_b5b_ladies_admin}}
HTTP 200
[Asserts]
jsonpath "$.classes" count == 1
jsonpath "$.classes[0].code" == "B4B-L-62"

GET {{base_url}}/students/901172
Authorization: {{auth_b5b_ladies_admin}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Person not found"

# 4. Not a student, a closed class, a removed enrolment, an unknown member, a token that is not positive: all the same 404
GET {{base_url}}/students/901173
Authorization: {{auth_b4b_card_admin}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Person not found"

GET {{base_url}}/students/901175
Authorization: {{auth_b4b_card_admin}}
HTTP 404

GET {{base_url}}/students/901176
Authorization: {{auth_b4b_card_admin}}
HTTP 404

GET {{base_url}}/students/8
Authorization: {{auth_b4b_card_admin}}
HTTP 404

GET {{base_url}}/students/0
Authorization: {{auth_b4b_card_admin}}
HTTP 404

GET {{base_url}}/students/-5
Authorization: {{auth_b4b_card_admin}}
HTTP 404

GET {{base_url}}/students/abc
Authorization: {{auth_b4b_card_admin}}
HTTP 404
