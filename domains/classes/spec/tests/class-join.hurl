# POST /classes/join contract: the caller joins, or rejoins, the class a link names. Runs against any implementation.
# Variables: base_url and auth_<alias>. ENROLMENT fixtures (reset by tools/classes-contract.sh): class 9418 (gents, link WrJoin9418; 900563 enrolled, 900564 removed by an admin, 900565 removed by themself), the closed
# class 9419 (link wrjoin9419), the ladies class 9414 (link enlnk9414); callers en_j_free 900561 (gents), en_j_ladies 900562, en_j_in, en_j_removed, en_j_left, en_j_nogender 900566 (no gender); the write admin sees the roster.

# 1. Without sign-in: 401
POST {{base_url}}/classes/join
{"link": "WrJoin9418"}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A caller whose gender is not set: 400, before the body is looked at
POST {{base_url}}/classes/join
Authorization: {{auth_en_j_nogender}}
{"link": "WrJoin9418"}
HTTP 400
[Asserts]
jsonpath "$.detail" == "User gender not set; update profile first"

POST {{base_url}}/classes/join
Authorization: {{auth_en_j_nogender}}
{}
HTTP 400

# 3. The link: required, trimmed
POST {{base_url}}/classes/join
Authorization: {{auth_en_j_free}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "link is required"

POST {{base_url}}/classes/join
Authorization: {{auth_en_j_free}}
{"link": "   "}
HTTP 422
[Asserts]
jsonpath "$.detail" == "link is required"

POST {{base_url}}/classes/join
Authorization: {{auth_en_j_free}}
{"link": null}
HTTP 422

POST {{base_url}}/classes/join
Authorization: {{auth_en_j_free}}
Content-Type: application/json
```
{"link": "Wr
```
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

# 4. No such class, or a closed one
POST {{base_url}}/classes/join
Authorization: {{auth_en_j_free}}
{"link": "nosuchlink"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Invalid class link or class not active"

POST {{base_url}}/classes/join
Authorization: {{auth_en_j_free}}
{"link": "wrjoin9419"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Invalid class link or class not active"

# 5. A class of the other gender: 403 either way round
POST {{base_url}}/classes/join
Authorization: {{auth_en_j_ladies}}
{"link": "WrJoin9418"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This class is not available for your gender"

POST {{base_url}}/classes/join
Authorization: {{auth_en_j_free}}
{"link": "enlnk9414"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This class is not available for your gender"

# 6. A member removed by someone else may not rejoin
POST {{base_url}}/classes/join
Authorization: {{auth_en_j_removed}}
{"link": "WrJoin9418"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You were removed from this class. Please contact the class coordinator."

# 7. Already enrolled: 200 with success false, nothing written
POST {{base_url}}/classes/join
Authorization: {{auth_en_j_in}}
{"link": "WrJoin9418"}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.success" == false
jsonpath "$.message" == "You are already enrolled in this class"
jsonpath "$.classId" == 9418
jsonpath "$.className" == "En Join Class"

GET {{base_url}}/classes/9418/students
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 1

# 8. A new member joins: the link is trimmed and matches in any case; they are on the roster; joining again says so
POST {{base_url}}/classes/join
Authorization: {{auth_en_j_free}}
{"link": "  wrjoin9418  "}
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.message" == "Successfully joined the class!"
jsonpath "$.classId" == 9418
jsonpath "$.className" == "En Join Class"

GET {{base_url}}/classes/9418/students
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 2
jsonpath "$.students[?(@.token==900561)].name" == "En Member 900561"

POST {{base_url}}/classes/join
Authorization: {{auth_en_j_free}}
{"link": "WrJoin9418"}
HTTP 200
[Asserts]
jsonpath "$.success" == false
jsonpath "$.message" == "You are already enrolled in this class"

# 9. A member who left may rejoin
POST {{base_url}}/classes/join
Authorization: {{auth_en_j_left}}
{"link": "WrJoin9418"}
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.message" == "Welcome back! You have re-joined the class"
jsonpath "$.classId" == 9418

GET {{base_url}}/classes/9418/students
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 3
jsonpath "$.students[?(@.token==900565)].name" == "En Member 900565"

POST {{base_url}}/classes/join
Authorization: {{auth_en_j_left}}
{"link": "WrJoin9418"}
HTTP 200
[Asserts]
jsonpath "$.success" == false
