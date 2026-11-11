# PUT /classes/{class_id} contract: edit a class's details, teacher, tags and schedule; answers with the manage payload. Runs against any implementation.
# Variables: base_url and auth_<alias>. WRITE fixtures (reset by tools/classes-contract.sh): class 9403 (gents, MIQDAD, teacher 900403, address "Wr Address", tag 9401, live slot 9404 (Tuesday 18:00) with topic row 9401,
# deleted slot 9405); tags 9401 to 9403, topics 9401 and 9402; 900404 may be given the class, 900406 may not; the write admin 900331.

# 1. Without sign-in: 401
PUT {{base_url}}/classes/9403
{}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Unknown or closed class: 404 before the permission check
PUT {{base_url}}/classes/999999
Authorization: {{auth_student_g}}
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

PUT {{base_url}}/classes/9303
Authorization: {{auth_admin}}
{}
HTTP 404

# 3. A student, an outsider and another class's teacher: 403
PUT {{base_url}}/classes/9403
Authorization: {{auth_student_g}}
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage this class"

PUT {{base_url}}/classes/9403
Authorization: {{auth_outsider}}
{}
HTTP 403

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_teacher1}}
{}
HTTP 403

# 4. The body, in PHP's order of checks
PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
Content-Type: application/json
```
{"languageId":
```
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"languageId": 4}
HTTP 422
[Asserts]
jsonpath "$.detail" == "languageId is not a known language"

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"languageId": "x", "startedOn": "bad"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "languageId is not a known language"

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"startedOn": "2025-02-30"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "startedOn must be a date as YYYY-MM-DD"

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"startedOn": "2025-2-3"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "startedOn must be a date as YYYY-MM-DD"

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"startedOn": 20250901}
HTTP 422

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"startedOn": "2025-09-01"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be Online or Offline"

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"format": "online"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be Online or Offline"

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"format": "Online", "city": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "city must be at most 300 characters"

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"format": "Online", "address": "{{newUuid}}", "location": ["x"]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "location must be at most 300 characters"

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"format": "Online"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "teacher is required"

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"format": "Online", "teacher": "900403"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "teacher is required"

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"format": "Online", "teacher": 900406}
HTTP 422
[Asserts]
jsonpath "$.detail" == "teacher is not a member who can be assigned"

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"format": "Online", "teacher": 900403, "tags": [9401, "9402"]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "tags must be a list of tag ids"

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"format": "Online", "teacher": 900403, "tags": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "tags must be a list of tag ids"

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"format": "Online", "teacher": 900403}
HTTP 422
[Asserts]
jsonpath "$.detail" == "schedules must be a list of at most 21 entries"

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"format": "Online", "teacher": 900403, "schedules": [{"day": 9, "hour": 1, "minute": 1, "timezone": "Asia/Kolkata"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "each schedule needs a day (1-7), hour (0-23), minute (0-59) and timezone"

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"format": "Online", "teacher": 900403, "schedules": [{"day": 1, "hour": 1, "minute": 1, "timezone": "Nowhere/Land"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "timezone is not one of the supported timezones"

PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"format": "Online", "teacher": 900403, "schedules": [{"day": 1, "hour": 1, "minute": 1, "timezone": "Asia/Kolkata", "topics": [{"topicId": 999999}]}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "each topic needs a topicId from the topics list"

# ... nothing was changed by the refusals
GET {{base_url}}/classes/9403/manage
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.class.format" == "Offline"
jsonpath "$.class.address" == "Wr Address"
jsonpath "$.class.teacher" == 900403
jsonpath "$.tags" count == 1
jsonpath "$.schedules" count == 1
jsonpath "$.schedules[0].topics" count == 1

# 5. The admin edits everything: a new teacher, blanked address, trimmed text, tags swapped, the slot edited and its topic swapped, a new slot with a topic; the deleted slot 9405 named by id stays deleted
PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"languageId": "2", "startedOn": "2025-10-05", "format": "Online", "address": "   ", "city": "  Pune ", "country": "India", "location": "Wr New Hall", "teacher": 900404, "tags": [9402, 9403, 9402, 5],
 "schedules": [
  {"id": 9404, "day": 3, "hour": 19, "minute": 30, "timezone": "Asia/Calcutta", "topics": [{"id": 9401, "topicId": 9402}, {"topicId": 9401}]},
  {"id": 9405, "day": 7, "hour": 5, "minute": 5, "timezone": "Asia/Kolkata"},
  {"day": 1, "hour": 6, "minute": 0, "timezone": "Asia/Karachi", "topics": [{"topicId": 9401}]}
 ]}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.class.id" == 9403
jsonpath "$.class.languageId" == 2
jsonpath "$.class.startedOn" == "2025-10-05"
jsonpath "$.class.format" == "Online"
jsonpath "$.class.address" == null
jsonpath "$.class.city" == "Pune"
jsonpath "$.class.country" == "India"
jsonpath "$.class.location" == "Wr New Hall"
jsonpath "$.class.teacher" == 900404
jsonpath "$.class.teacherName" == "Wr Candidate"
jsonpath "$.class.code" == "WR-G-003"
jsonpath "$.class.name" == "Wr Update Class"
jsonpath "$.tags" count == 2
jsonpath "$.tags[0].name" == "wr-beta"
jsonpath "$.tags[1].name" == "wr-gamma"
jsonpath "$.schedules" count == 2
jsonpath "$.schedules[?(@.id==9404)].day" == 3
jsonpath "$.schedules[?(@.id==9404)].hour" == 19
jsonpath "$.schedules[?(@.id==9404)].timezone" == "Asia/Kolkata"
jsonpath "$.schedules[?(@.id==9404)].topics" count == 2
jsonpath "$.schedules[?(@.id==9404)].topics[?(@.id==9401)].topicId" == 9402
jsonpath "$.schedules[?(@.id==9405)]" not exists
jsonpath "$.schedules[?(@.day==1)].timezone" == "Asia/Karachi"
jsonpath "$.schedules[?(@.day==1)].topics" count == 1
jsonpath "$.schedules[?(@.day==1)].topics[0].topicId" == 9401
jsonpath "$.can.update" == true
jsonpath "$.students" isCollection

# ... the class read afterwards shows the same
GET {{base_url}}/classes/9403/manage
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.class.teacherName" == "Wr Candidate"
jsonpath "$.class.address" == null
jsonpath "$.tags" count == 2
jsonpath "$.schedules" count == 2

# 6. The same teacher again needs no candidacy check; omitted tags, null language and date clear them; an empty schedule drops every slot
PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_admin}}
{"languageId": null, "startedOn": null, "format": "Offline", "teacher": 900404, "schedules": []}
HTTP 200
[Asserts]
jsonpath "$.class.languageId" == null
jsonpath "$.class.startedOn" == null
jsonpath "$.class.format" == "Offline"
jsonpath "$.tags" count == 0
jsonpath "$.schedules" count == 0

# 7. The class's teacher is not a manager of it
PUT {{base_url}}/classes/9403
Authorization: {{auth_wr_teacher3}}
{}
HTTP 403
