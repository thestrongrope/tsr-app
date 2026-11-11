# GET /classes/{class_id}/conduction/new contract: the data of the new-record form. Runs against any implementation.
# Variables: base_url and auth_<alias>. CONDUCTION fixtures: class 9471 (sessions on Saturdays 2025-09-06, 09-13 (not held), 09-20; slots on days 2 and 5 and a deleted one on day 7; extra students), class 9474 (one Monday slot; its
# newest session is on Monday 2099-01-05), class 9476 (no session, started Wednesday 2025-10-01, no schedule).

# 1. Without sign-in: 401. Unknown class: 404. A student, another class's teacher, the ladies' admin: 403
GET {{base_url}}/classes/9471/conduction/new
HTTP 401

GET {{base_url}}/classes/999999/conduction/new
Authorization: {{auth_cd_teacher}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/classes/9471/conduction/new
Authorization: {{auth_cd_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage this class"

GET {{base_url}}/classes/9471/conduction/new
Authorization: {{auth_cd_teacher2}}
HTTP 403

GET {{base_url}}/classes/9471/conduction/new
Authorization: {{auth_en_ladmin}}
HTTP 403

# 2. A class with sessions: the last session day (any kind), the next day from the schedule (a deleted slot counts), the newest topic of each subject among held sessions (trimmed), the newest surah
GET {{base_url}}/classes/9471/conduction/new
Authorization: {{auth_cd_teacher}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.class.id" == 9471
jsonpath "$.class.name" == "Cd Read Class"
jsonpath "$.class.students" count == 2
jsonpath "$.class.extraStudents" count == 2
jsonpath "$.class.totalStudents" == 4
jsonpath "$.lastSessionDate" == "2025-09-20"
jsonpath "$.nextSessionDate" == "2025-09-21"
jsonpath "$.futureDate" == null
jsonpath "$.latestTopics.arabicTopic" == "Arabic Seed"
jsonpath "$.latestTopics.aqaedTopic" == "Aqaed Newest"
jsonpath "$.latestTopics.ahkamTopic" == "Ahkam Newest"
jsonpath "$.latestTopics.akhlaqTopic" == null
jsonpath "$.latestTopics.otherTopic" == null
jsonpath "$.latestSurah" == 2
jsonpath "$.holyQuran" isCollection

# 3. The next day is in the future: futureDate repeats it
GET {{base_url}}/classes/9474/conduction/new
Authorization: {{auth_cd_teacher}}
HTTP 200
[Asserts]
jsonpath "$.lastSessionDate" == "2099-01-05"
jsonpath "$.nextSessionDate" == "2099-01-12"
jsonpath "$.futureDate" == "2099-01-12"
jsonpath "$.latestTopics.aqaedTopic" == "Future Seed"
jsonpath "$.latestSurah" == null

# 4. A class with no session starts from its start day; with no schedule PHP counts 7 minus the weekday (Wednesday 3: four days on). PHP's parity stack prints PHP warnings
#    (an undefined index) before the JSON for this class, so the body is matched as text
GET {{base_url}}/classes/9476/conduction/new
Authorization: {{auth_cd_teacher}}
HTTP 200
[Asserts]
body contains "\"lastSessionDate\":\"2025-10-01\""
body contains "\"nextSessionDate\":\"2025-10-05\""
body contains "\"futureDate\":null"
body contains "\"latestTopics\":{\"arabicTopic\":null,\"aqaedTopic\":null,\"ahkamTopic\":null,\"akhlaqTopic\":null,\"otherTopic\":null}"
body contains "\"latestSurah\":null"
body contains "\"students\":[],\"extraStudents\":[]"

# 5. A super admin and the gents' admin may open the form
GET {{base_url}}/classes/9474/conduction/new
Authorization: {{auth_admin}}
HTTP 200

GET {{base_url}}/classes/9474/conduction/new
Authorization: {{auth_en_gadmin}}
HTTP 200
