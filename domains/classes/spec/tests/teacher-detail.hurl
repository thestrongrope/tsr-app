# GET /teachers/{token} contract: a teacher's details, trained levels, classes and training history. Runs against any implementation.
# Variables: base_url and auth_<alias>. Fixtures: teacher 900301 (gents; class 9301 active with two slots, class 9303 closed, enrolled nowhere), 900311 student of 9301 (and removed from the closed 9303), 900302 teacher of 9302.

# 1. Without sign-in: 401
GET {{base_url}}/teachers/900301
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A caller without teachers:lookup: 403
GET {{base_url}}/teachers/900301
Authorization: {{auth_student_g}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. No such member, or a member the caller may not see: 404, saying nothing of which
GET {{base_url}}/teachers/999999999
Authorization: {{auth_admin}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Teacher not found"

# 4. The super admin sees a teacher: contact, no training record, the classes now and before (PHP orders the slots by the day NAME, the alias of its select list: Saturday before Tuesday)
GET {{base_url}}/teachers/900301
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.token" == 900301
jsonpath "$.name" == "Cls Teacher Gents"
jsonpath "$.email" == "cls.teacher.gents@example.invalid"
jsonpath "$.mobile" == "+910000003001"
jsonpath "$.state" == null
jsonpath "$.trained" == false
jsonpath "$.flags.salman" == false
jsonpath "$.flags.bilal" == false
jsonpath "$.conducting" count == 1
jsonpath "$.conducting[0].id" == 9301
jsonpath "$.conducting[0].code" == "CLS-G-001"
jsonpath "$.conducting[0].level" == "MIQDAD"
jsonpath "$.conducting[0].city" == "Mumbai"
jsonpath "$.conducting[0].country" == "India"
jsonpath "$.conducting[0].startedOn" == "2025-09-01"
jsonpath "$.conducting[0].endedOn" == null
jsonpath "$.conducting[0].teacher" == null
jsonpath "$.conducting[0].teacherToken" == null
jsonpath "$.conducting[0].schedules" count == 2
jsonpath "$.conducting[0].schedules[0]" == "Saturday 18:30 Asia/Kolkata"
jsonpath "$.conducting[0].schedules[1]" == "Tuesday 09:15 Asia/Kolkata"
jsonpath "$.conducted" count == 1
jsonpath "$.conducted[0].id" == 9303
jsonpath "$.conducted[0].level" == "AMMAR"
jsonpath "$.conducted[0].comments" == null
jsonpath "$.conducted[0].schedules" count == 0
jsonpath "$.attending" count == 0
jsonpath "$.attended" count == 0
jsonpath "$.history" count == 0

# 5. A student: the class they attend with its teacher, and the closed class they left
GET {{base_url}}/teachers/900311
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.name" == "Cls Student Gents"
jsonpath "$.conducting" count == 0
jsonpath "$.attending" count == 1
jsonpath "$.attending[0].id" == 9301
jsonpath "$.attending[0].teacher" == "Cls Teacher Gents"
jsonpath "$.attending[0].teacherToken" == 900301
jsonpath "$.attending[0].schedules" count == 2
jsonpath "$.attended" count == 1
jsonpath "$.attended[0].id" == 9303
jsonpath "$.attended[0].endedOn" == "2025-06-30"
jsonpath "$.attended[0].comments" == "Cls closed"
jsonpath "$.attended[0].removedBy" == "Cls Admin"
jsonpath "$.attended[0].teacherToken" == 900301
jsonpath "$.attended[0].schedules" count == 0

# 6. A trained teacher: the levels and the history of the training (the comment, who recorded it, the day)
GET {{base_url}}/teachers/900302
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.trained" == true
jsonpath "$.flags.salman" == false
jsonpath "$.flags.miqdad" == true
jsonpath "$.flags.bilal" == true
jsonpath "$.conducting[0].id" == 9302
jsonpath "$.conducting[0].schedules[0]" == "Sunday 10:00 Asia/Dubai"
jsonpath "$.history" count == 1
jsonpath "$.history[0].comments" == "Cls trained"
jsonpath "$.history[0].by" == "Cls Admin"
jsonpath "$.history[0].on" == "2025-08-01"
