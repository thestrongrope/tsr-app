# POST /classes/{class_id}/conduction on the NEW API only (skipped on PHP, which stores a NUL byte, which PostgreSQL text cannot, and truncates or fails on a text over its column): such input is a 422, never a server error.
# Variables: base_url and auth_<alias>. CONDUCTION fixtures: class 9478 (gents, teacher 900801 "cd_teacher", student 900841, no session). Checks run after PHP's own, and only on what is stored.

POST {{base_url}}/classes/9478/conduction
Authorization: {{auth_cd_teacher}}
{"conductedOn": "2025-11-17", "conducted": false, "nonConductionReason": "Ra\u0000in"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "nonConductionReason must not contain a NUL byte"

POST {{base_url}}/classes/9478/conduction
Authorization: {{auth_cd_teacher}}
{"conductedOn": "2025-11-17", "conducted": false, "nonConductionReason": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "nonConductionReason must be at most 100 characters"

POST {{base_url}}/classes/9478/conduction
Authorization: {{auth_cd_teacher}}
{"conductedOn": "2025-11-17", "duration": 30, "students": [{"token": 900841, "present": true}], "aqaedConducted": true, "aqaedTopic": "Wu\u0000du"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "aqaedTopic must not contain a NUL byte"

POST {{base_url}}/classes/9478/conduction
Authorization: {{auth_cd_teacher}}
{"conductedOn": "2025-11-17", "duration": 30, "students": [{"token": 900841, "present": true}], "aqaedConducted": true, "aqaedTopic": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "aqaedTopic must be at most 1000 characters"

POST {{base_url}}/classes/9478/conduction
Authorization: {{auth_cd_teacher}}
{"conductedOn": "2025-11-17", "duration": 30, "students": [{"token": 900841, "present": true}], "aqaedConducted": true, "aqaedTopic": "T", "extraStudents": [{"name": "Ex\u0000tra", "present": true}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "extraStudents name must not contain a NUL byte"

POST {{base_url}}/classes/9478/conduction
Authorization: {{auth_cd_teacher}}
{"conductedOn": "2025-11-17", "duration": 30, "students": [{"token": 900841, "present": true}], "aqaedConducted": true, "aqaedTopic": "T", "extraStudents": [{"name": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "present": true}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "extraStudents name must be at most 100 characters"

# A number beyond what a column holds
POST {{base_url}}/classes/9478/conduction
Authorization: {{auth_cd_teacher}}
{"conductedOn": "2025-11-17", "duration": 99999999999, "students": [{"token": 900841, "present": true}], "aqaedConducted": true, "aqaedTopic": "T"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "duration is out of range"

POST {{base_url}}/classes/9478/conduction
Authorization: {{auth_cd_teacher}}
{"conductedOn": "2025-11-17", "duration": 30, "quranRecitationSurah": 99999999999, "students": [{"token": 900841, "present": true}], "aqaedConducted": true, "aqaedTopic": "T"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "quranRecitationSurah is out of range"

POST {{base_url}}/classes/9478/conduction
Authorization: {{auth_cd_teacher}}
{"conductedOn": "2025-11-17", "duration": 30, "students": [{"token": 900841, "present": true, "recitation": 99999999999}], "aqaedConducted": true, "aqaedTopic": "T"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "recitation is out of range"

# The refusals wrote nothing
GET {{base_url}}/classes/9478/conduction
Authorization: {{auth_cd_teacher}}
HTTP 200
[Asserts]
jsonpath "$.totalRecords" == 0

# What is not stored is not checked: a NUL in the topic of an unselected subject, and in the reason of a class that was held. Texts at their limits are kept whole
POST {{base_url}}/classes/9478/conduction
Authorization: {{auth_cd_teacher}}
{"conductedOn": "2025-11-17", "duration": 30, "students": [{"token": 900841, "present": true}], "aqaedConducted": true, "aqaedTopic": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "arabicTopic": "a\u0000b", "nonConductionReason": "a\u0000b", "extraStudents": [{"name": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "present": true}]}
HTTP 201
[Asserts]
jsonpath "$.aqaedTopic" matches "^x{1000}$"
jsonpath "$.arabicTopic" == null
jsonpath "$.nonConductionReason" == null
jsonpath "$.attendance" == 2

POST {{base_url}}/classes/9478/conduction
Authorization: {{auth_cd_teacher}}
{"conductedOn": "2025-11-18", "conducted": false, "nonConductionReason": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
HTTP 201
[Asserts]
jsonpath "$.nonConductionReason" matches "^x{100}$"
