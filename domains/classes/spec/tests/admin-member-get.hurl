# GET /admin/members/{token} contract: a member's details by token, for the super admin (30 lookups an hour each). Runs against any implementation.
# Variables: base_url and auth_<alias>. B4a fixtures: 900991 (gents; Pune, India; a pending request for 9541; active in 9541 and 9542; a row of the closed 9543 that was never removed), 900992 (ladies, no mobile, city
# or country), 900993 (gender text "Male"; an accepted request; removed from 9541 on 2025-11-01), 900994 (gender "Other"), 900995 (two members hold the token), 900996 (a pending request for a class that is gone);
# the lookup admins 900904 and 900905 (role 1; four counted lookups each, so a run stays far from the limit), the gents admin 900501.

# 1. Without sign-in: 401
GET {{base_url}}/admin/members/900991
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Only members:enrol-by-token (checked before the lookup is counted)
GET {{base_url}}/admin/members/900991
Authorization: {{auth_en_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/admin/members/900991
Authorization: {{auth_en_gadmin}}
HTTP 403

# 3. A full card: contact details, the class asked for, the classes now (by code, with the level) and left (the closed class that was never left shows no day)
GET {{base_url}}/admin/members/900991
Authorization: {{auth_b4_look_a}}
HTTP 200
[Asserts]
jsonpath "$.token" == 900991
jsonpath "$.name" == "B4 Member 900991"
jsonpath "$.gender" == 1
jsonpath "$.email" == "b4.900991@example.invalid"
jsonpath "$.mobile" == "+910000090991"
jsonpath "$.city" == "Pune"
jsonpath "$.country" == "India"
jsonpath "$.registeredOn" == "2025-01-15"
jsonpath "$.requestedClass.id" == 9541
jsonpath "$.requestedClass.code" == "B4-G-41"
jsonpath "$.requestedClass.name" == "B4 Lookup One"
jsonpath "$.classesNow" count == 2
jsonpath "$.classesNow[0].id" == 9541
jsonpath "$.classesNow[0].code" == "B4-G-41"
jsonpath "$.classesNow[0].name" == "B4 Lookup One"
jsonpath "$.classesNow[0].level" == "MIQDAD"
jsonpath "$.classesNow[1].code" == "B4-G-42"
jsonpath "$.classesNow[1].level" == "AMMAR"
jsonpath "$.classesLeft" count == 1
jsonpath "$.classesLeft[0].id" == 9543
jsonpath "$.classesLeft[0].code" == "B4-G-43"
jsonpath "$.classesLeft[0].leftOn" == null

# 4. A bare card: empty contact fields are null, no request, no classes
GET {{base_url}}/admin/members/900992
Authorization: {{auth_b4_look_a}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.mobile" == null
jsonpath "$.city" == null
jsonpath "$.country" == null
jsonpath "$.requestedClass" == null
jsonpath "$.classesNow" count == 0
jsonpath "$.classesLeft" count == 0

# 5. Gender "Male" reads as 1; an accepted request says nothing about what was asked; a removed class shows the day
GET {{base_url}}/admin/members/900993
Authorization: {{auth_b4_look_a}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.requestedClass" == null
jsonpath "$.classesNow" count == 0
jsonpath "$.classesLeft[0].id" == 9541
jsonpath "$.classesLeft[0].leftOn" == "2025-11-01"

# 6. A gender that is neither is null
GET {{base_url}}/admin/members/900994
Authorization: {{auth_b4_look_a}}
HTTP 200
[Asserts]
jsonpath "$.gender" == null

# 7. A token two members share is 422 with a code; a request for a class that is gone is not shown
GET {{base_url}}/admin/members/900995
Authorization: {{auth_b4_look_b}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "More than one member has that token number. Please contact an admin."
jsonpath "$.code" == "ambiguous_token"

GET {{base_url}}/admin/members/900996
Authorization: {{auth_b4_look_b}}
HTTP 200
[Asserts]
jsonpath "$.requestedClass" == null

# 8. An unknown token, and one that is not plain digits, are 404
GET {{base_url}}/admin/members/999000001
Authorization: {{auth_b4_look_b}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "No registered member has this token"

GET {{base_url}}/admin/members/90099x
Authorization: {{auth_b4_look_b}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "No registered member has this token"
