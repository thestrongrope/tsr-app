# GET /classes/{class_id}/manage contract: everything the manage screen needs. Runs against any implementation.
# Variables: base_url and auth_<alias>. Fixtures: class 9301 (gents, MIQDAD, teacher 900301, tags cls-beginners and cls-evening, slots 9301 and 9302; students 900311 with a note, 900322; 900316 removed),
# 9302 (ladies), 9303 (closed). Only fixture rows are asserted: the lookups and the destinations also hold the rest of the database.

# 1. Without sign-in: 401
GET {{base_url}}/classes/9301/manage
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Unknown or closed class: 404 (before any permission check)
GET {{base_url}}/classes/999999/manage
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/classes/9303/manage
Authorization: {{auth_admin}}
HTTP 404

# 3. A plain student, an outsider and the teachers (who may read the roster but not manage): 403
GET {{base_url}}/classes/9301/manage
Authorization: {{auth_student_g}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage this class"

GET {{base_url}}/classes/9301/manage
Authorization: {{auth_outsider}}
HTTP 403

GET {{base_url}}/classes/9301/manage
Authorization: {{auth_teacher_l}}
HTTP 403

# 4. An admin gets the whole payload
GET {{base_url}}/classes/9301/manage
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.class.id" == 9301
jsonpath "$.class.code" == "CLS-G-001"
jsonpath "$.class.name" == "Cls Gents Class"
jsonpath "$.class.levelId" == 3
jsonpath "$.class.levelName" == "MIQDAD"
jsonpath "$.class.gender" == 1
jsonpath "$.class.genderName" matches /\S/
jsonpath "$.class.languageId" == 1
jsonpath "$.class.startedOn" == "2025-09-01"
jsonpath "$.class.format" == "Offline"
jsonpath "$.class.address" == null
jsonpath "$.class.city" == "Mumbai"
jsonpath "$.class.country" == "India"
jsonpath "$.class.location" == "Cls Hall"
jsonpath "$.class.teacher" == 900301
jsonpath "$.class.teacherName" == "Cls Teacher Gents"
jsonpath "$.class.joinUrl" == null
jsonpath "$.tags" count == 2
jsonpath "$.tags[0].name" == "cls-beginners"
jsonpath "$.tags[1].name" == "cls-evening"
jsonpath "$.schedules" count == 2
jsonpath "$.schedules[?(@.id==9301)].day" == 6
jsonpath "$.schedules[?(@.id==9301)].hour" == 18
jsonpath "$.schedules[?(@.id==9301)].minute" == 30
jsonpath "$.schedules[?(@.id==9301)].timezone" == "Asia/Kolkata"
jsonpath "$.schedules[?(@.id==9302)].day" == 2
jsonpath "$.schedules[?(@.id==9301)].topics" count == 0
jsonpath "$.lookups.languages" count == 3
jsonpath "$.lookups.languages[0].id" == 1
jsonpath "$.lookups.languages[0].name" == "English"
jsonpath "$.lookups.languages[2].name" == "Gujarati"
jsonpath "$.lookups.tags[?(@.name=='cls-beginners')].id" == 9301
jsonpath "$.lookups.timezones[?(@.timezone=='Asia/Kolkata')].label" matches /\S/
jsonpath "$.can.update" == true
jsonpath "$.can.enrol" == true
jsonpath "$.can.setClassAdmin" == true
jsonpath "$.can.transfer" == true
jsonpath "$.students[?(@.token==900311)].name" == "Cls Student Gents"
jsonpath "$.students[?(@.token==900311)].email" == "cls.student.gents@example.invalid"
jsonpath "$.students[?(@.token==900311)].mobile" == "+910000003011"
jsonpath "$.students[?(@.token==900311)].joinedOn" == "2025-09-01"
jsonpath "$.students[?(@.token==900311)].notes" == "Cls note & more"
jsonpath "$.students[?(@.token==900311)].mcqAdmin" == false
jsonpath "$.students[?(@.token==900316)]" not exists
jsonpath "$.removedStudents[?(@.token==900316)].name" == "Cls Removed"
jsonpath "$.removedStudents[?(@.token==900316)].removedAt" == "2025-10-01T00:00:00"
jsonpath "$.removedStudents[?(@.token==900316)].removedReason" == "Cls removed"
jsonpath "$.removedStudents[?(@.token==900316)].removedByName" == "Cls Admin"
jsonpath "$.mcqStudents" isCollection
jsonpath "$.transferHistory" isCollection
jsonpath "$.destinations[?(@.id==9302)].code" == "CLS-L-001"
jsonpath "$.destinations[?(@.id==9301)]" not exists
jsonpath "$.destinations[?(@.id==9303)]" not exists

# 5. The same class for the ladies class: the quiz taker who is not enrolled is the candidate to add (900312 answered the ladies quiz and is enrolled, so none of the fixtures)
GET {{base_url}}/classes/9302/manage
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.class.id" == 9302
jsonpath "$.class.format" == "Online"
jsonpath "$.class.location" == null
jsonpath "$.students[?(@.token==900312)].name" == "Cls Student Ladies"
jsonpath "$.mcqStudents[?(@.token==900312)]" not exists
