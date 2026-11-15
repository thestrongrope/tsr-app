# GET /classes/create-options contract: what the create-class form offers. Runs against any implementation.
# Variables: base_url and auth_<alias>. Fixtures: tag 9301 "cls-beginners"; the admin may create for both genders.

# 1. Without sign-in: 401
GET {{base_url}}/classes/create-options
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A student and a teacher may create for no gender: 403
GET {{base_url}}/classes/create-options
Authorization: {{auth_student_g}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to create a class"

GET {{base_url}}/classes/create-options
Authorization: {{auth_teacher_g}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to create a class"

# 3. An admin gets both genders, the tags and the 121 zones
GET {{base_url}}/classes/create-options
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.genders" count == 2
jsonpath "$.genders[0]" == 1
jsonpath "$.genders[1]" == 2
jsonpath "$.tags[?(@.id==9301)].name" == "cls-beginners"
jsonpath "$.tags[?(@.id==9302)].name" == "cls-evening"
jsonpath "$.timezones" count == 121
jsonpath "$.timezones[0].timezone" == "Pacific/Midway"
jsonpath "$.timezones[4].label" == "(UTC-08:00) Pacific Time (US & Canada)"
jsonpath "$.timezones[120].label" == "(UTC+13:00) Nuku'alofa"
