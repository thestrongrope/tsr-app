# POST /classes contract: create a class; 201 {classId}. Runs against any implementation.
# Variables: base_url and auth_<alias>. WRITE fixtures (reset by tools/classes-contract.sh, which deletes every class created by the write admin 900331): tags 9401 to 9403, topic 9401;
# 900404 is a valid teacher (an enrolled student), 900406 is not. The location of the class made is unique per run (the same class twice within a minute is a 409).

# 1. Without sign-in: 401
POST {{base_url}}/classes
{}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. The gender is checked before the permission: a student sending 3 gets the 422
POST {{base_url}}/classes
Authorization: {{auth_student_g}}
{"gender": 3}
HTTP 422
[Asserts]
jsonpath "$.detail" == "gender must be 1 (gents) or 2 (ladies)"

POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
{"gender": "1"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "gender must be 1 (gents) or 2 (ladies)"

POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
Content-Type: application/json
```
{"gender":
```
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

# 3. A plain student and an outsider may not create: 403
POST {{base_url}}/classes
Authorization: {{auth_student_g}}
{"gender": 1}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to create a class"

POST {{base_url}}/classes
Authorization: {{auth_outsider}}
{"gender": 2}
HTTP 403

# 4. The fields, in PHP's order (422)
POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
{"gender": 1}
HTTP 422
[Asserts]
jsonpath "$.detail" == "levelId is required"

POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
{"gender": 1, "levelId": 0}
HTTP 422
[Asserts]
jsonpath "$.detail" == "levelId is required"

POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
{"gender": 1, "levelId": 3}
HTTP 422
[Asserts]
jsonpath "$.detail" == "location is required"

POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
{"gender": 1, "levelId": 3, "location": "   ", "city": "Pune"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "location is required"

POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
{"gender": 1, "levelId": 3, "location": "Hall", "city": 7}
HTTP 422
[Asserts]
jsonpath "$.detail" == "city is required"

POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
{"gender": 1, "levelId": 3, "location": "Hall", "city": "Pune"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "country is required"

POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
{"gender": 1, "levelId": 3, "location": "Hall", "city": "Pune", "country": "{{newUuid}}{{newUuid}}{{newUuid}}{{newUuid}}{{newUuid}}{{newUuid}}{{newUuid}}{{newUuid}}{{newUuid}}"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "country must be at most 300 characters"

POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
{"gender": 1, "levelId": 3, "location": "Hall", "city": "Pune", "country": "India"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "teacher is required"

POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
{"gender": 1, "levelId": 3, "location": "Hall", "city": "Pune", "country": "India", "teacher": 900406}
HTTP 422
[Asserts]
jsonpath "$.detail" == "teacher is not a member who can be assigned"

POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
{"gender": 1, "levelId": 3, "location": "Hall", "city": "Pune", "country": "India", "teacher": 900404, "tags": [1, "2"]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "tags must be a list of tag ids"

POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
{"gender": 1, "levelId": 3, "location": "Hall", "city": "Pune", "country": "India", "teacher": 900404}
HTTP 422
[Asserts]
jsonpath "$.detail" == "schedules must be a list of at most 21 entries"

POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
{"gender": 1, "levelId": 3, "location": "Hall", "city": "Pune", "country": "India", "teacher": 900404, "schedules": []}
HTTP 422
[Asserts]
jsonpath "$.detail" == "schedules needs at least one weekly slot"

POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
{"gender": 1, "levelId": 3, "location": "Hall", "city": "Pune", "country": "India", "teacher": 900404, "schedules": [{"day": 1, "hour": 5, "minute": 0, "timezone": "Asia/Kolkata", "topics": [{"topicId": 999999}]}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "each topic needs a topicId from the topics list"

# 5. The admin creates a gents class: tags (an unknown id is dropped), slots (topics ignored); the code and name come from the level and a count
POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
{"gender": 1, "levelId": 3, "location": "  Wr {{newUuid}} ", "city": " Pune ", "country": "India", "teacher": 900404, "tags": [9401, 9403, 5],
 "schedules": [{"day": 2, "hour": 18, "minute": 30, "timezone": "Asia/Calcutta", "topics": [{"topicId": 9401}]}, {"day": 6, "hour": 9, "minute": 0, "timezone": "Asia/Karachi"}]}
HTTP 201
[Captures]
gents_id: jsonpath "$.classId"
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.classId" > 0

GET {{base_url}}/classes/{{gents_id}}/manage
Authorization: {{auth_wr_admin}}
HTTP 200
[Captures]
gents_location: jsonpath "$.class.location"
[Asserts]
jsonpath "$.class.id" == {{gents_id}}
jsonpath "$.class.code" matches /^MK[0-9]+$/
jsonpath "$.class.name" matches /^MIQDAD[0-9]+$/
jsonpath "$.class.levelId" == 3
jsonpath "$.class.gender" == 1
jsonpath "$.class.city" == "Pune"
jsonpath "$.class.country" == "India"
jsonpath "$.class.location" matches /^Wr [0-9a-f-]{36}$/
jsonpath "$.class.teacher" == 900404
jsonpath "$.class.teacherName" == "Wr Candidate"
jsonpath "$.class.format" == "Offline"
jsonpath "$.tags" count == 2
jsonpath "$.tags[0].name" == "wr-alpha"
jsonpath "$.tags[1].name" == "wr-gamma"
jsonpath "$.schedules" count == 2
jsonpath "$.schedules[?(@.day==2)].timezone" == "Asia/Kolkata"
jsonpath "$.schedules[?(@.day==2)].topics" count == 0
jsonpath "$.schedules[?(@.day==6)].hour" == 9

# ... and the detail read shows it to the teacher, who now conducts it
GET {{base_url}}/classes/{{gents_id}}
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.id" == {{gents_id}}
jsonpath "$.status" == "A"

# 6. The same class again within a minute (the gender, level, location, city and country, whatever the spacing and case): 409
POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
{"gender": 1, "levelId": 3, "location": "{{gents_location}}", "city": "PUNE", "country": "india", "teacher": 900404,
 "schedules": [{"day": 2, "hour": 18, "minute": 30, "timezone": "Asia/Kolkata"}]}
HTTP 409
[Asserts]
jsonpath "$.detail" == "This class was just created"

# 7. A ladies class (any enrolled member may teach it) gets the ladies code of its level
POST {{base_url}}/classes
Authorization: {{auth_wr_admin}}
{"gender": 2, "levelId": 5, "location": "Wr {{newUuid}}", "city": "Dubai", "country": "UAE", "teacher": 900404,
 "schedules": [{"day": 7, "hour": 10, "minute": 0, "timezone": "Asia/Muscat"}]}
HTTP 201
[Captures]
ladies_id: jsonpath "$.classId"

GET {{base_url}}/classes/{{ladies_id}}/manage
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.class.code" matches /^BL[0-9]+$/
jsonpath "$.class.name" matches /^BILAL[0-9]+$/
jsonpath "$.class.gender" == 2
jsonpath "$.tags" count == 0
