# GET /classes/teachers contract: teacher candidates for a class not yet created. Runs against any implementation.
# Variables: base_url and auth_<alias>. Pool: active students of any class. Fixtures: gents 900311 "Cls Student Gents", 900322 "Cls Child One"; ladies 900312 "Cls Student Ladies", 900323 "Cls Child Two"
# (the removed 900316 and the teachers 900301/900302 are not in it).

# 1. Without sign-in: 401
GET {{base_url}}/classes/teachers?q=Cls
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A student may create for no gender: 403
GET {{base_url}}/classes/teachers?q=Cls
Authorization: {{auth_student_g}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to create a class"

# 3. A gents class takes gents only (the gender defaults to 1; anything but "2" is 1), by name
GET {{base_url}}/classes/teachers?q=Cls
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.teachers" count == 2
jsonpath "$.teachers[0].token" == 900322
jsonpath "$.teachers[0].name" == "Cls Child One"
jsonpath "$.teachers[1].token" == 900311
jsonpath "$.teachers[1].name" == "Cls Student Gents"

GET {{base_url}}/classes/teachers?gender=abc&q=Cls
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.teachers" count == 2

# 4. A ladies class takes anyone; the text is trimmed and its case does not matter
GET {{base_url}}/classes/teachers?gender=2&q=Cls
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.teachers" count == 4
jsonpath "$.teachers[1].name" == "Cls Child Two"
jsonpath "$.teachers[3].name" == "Cls Student Ladies"

GET {{base_url}}/classes/teachers?gender=2&q=%20cls%20student%20
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.teachers" count == 2
jsonpath "$.teachers[0].token" == 900311
jsonpath "$.teachers[1].token" == 900312

# 5. An exact token matches; a woman is no candidate for a gents class
GET {{base_url}}/classes/teachers?gender=2&q=900312
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.teachers" count == 1
jsonpath "$.teachers[0].token" == 900312
jsonpath "$.teachers[0].name" == "Cls Student Ladies"

GET {{base_url}}/classes/teachers?q=900312
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.teachers" count == 0

# 6. No text, or a wildcard (escaped, so it matches nothing): an empty list
GET {{base_url}}/classes/teachers
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.teachers" count == 0

GET {{base_url}}/classes/teachers?q=%25
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.teachers" count == 0

# A NUL byte inside q matches nobody (PHP: 200 and an empty list; it must not be a server error).
GET {{base_url}}/classes/teachers?q=a%00b
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.teachers" count == 0
