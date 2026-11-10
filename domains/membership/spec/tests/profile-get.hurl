# GET /me contract: one file per slice, runs against any implementation.
# Variables: base_url and auth_<alias>. Synthetic members only. tools/membership-contract.sh resets the fixtures and runs it.
# Ids differ per side, so id is only checked as a number.

# 1. Without sign-in: 401
GET {{base_url}}/me
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A member with every field set: the sixteen fields, with PHP's types
GET {{base_url}}/me
Authorization: {{auth_gender_one}}
HTTP 200
[Asserts]
jsonpath "$.id" isInteger
jsonpath "$.token" == 900201
jsonpath "$.email" == "gender.one@example.invalid"
jsonpath "$.name" == "Synthetic Gender One"
jsonpath "$.roleid" == 0
jsonpath "$.picture" == null
jsonpath "$.gender" == 1
jsonpath "$.age_range" == null
jsonpath "$.mobile" == "+911234567801"
jsonpath "$.country" == "Switzerland"
jsonpath "$.state" == "Zürich"
jsonpath "$.city" == "Zürich"
jsonpath "$.language" == 1
jsonpath "$.zip" == "8001"
jsonpath "$.sendupdates" == "N"
jsonpath "$.unsubscribe" == "N"
body contains "\"gender\":1,"
body contains "\"language\":1,"
body contains "\"token\":900201,"

# 3. Gender: '2' is 2; 'Male', 'Female', empty and NULL are all null, never 0
GET {{base_url}}/me
Authorization: {{auth_gender_two}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.mobile" == null
jsonpath "$.language" == 0
jsonpath "$.country" == null

GET {{base_url}}/me
Authorization: {{auth_gender_male}}
HTTP 200
[Asserts]
jsonpath "$.gender" == null

GET {{base_url}}/me
Authorization: {{auth_gender_female}}
HTTP 200
[Asserts]
jsonpath "$.gender" == null

GET {{base_url}}/me
Authorization: {{auth_gender_empty}}
HTTP 200
[Asserts]
jsonpath "$.gender" == null

GET {{base_url}}/me
Authorization: {{auth_gender_null}}
HTTP 200
[Asserts]
jsonpath "$.gender" == null

# 4. Text is entity-decoded (a name, a city, a state) and the picture is not
GET {{base_url}}/me
Authorization: {{auth_profile_entity}}
HTTP 200
[Asserts]
jsonpath "$.name" == "O'Brien & Sons"
jsonpath "$.city" == "St's"
jsonpath "$.state" == "Zürich"
jsonpath "$.picture" == "https://example.invalid/a.png?x=1&amp;y=2"
jsonpath "$.mobile" == "+911234567802"
jsonpath "$.language" == 2

# 5. An empty name is the integer 0, and empty text elsewhere is null
GET {{base_url}}/me
Authorization: {{auth_profile_noname}}
HTTP 200
[Asserts]
jsonpath "$.name" == 0
jsonpath "$.picture" == null
jsonpath "$.mobile" == null
jsonpath "$.gender" == null
body contains "\"name\":0,"
