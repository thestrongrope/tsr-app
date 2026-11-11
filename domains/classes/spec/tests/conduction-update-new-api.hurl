# PUT /classes/{class_id}/conduction/{session_id} on the NEW API only (skipped on PHP): a NUL byte, a text over its column and a number beyond its column are a 422, never a server error.
# Variables: base_url and auth_<alias>. CONDUCTION fixtures: class 9475 (teacher 900804 "cd_teacher4"), session 947502 (made 1 day ago). Refusals change nothing, so this file can run beside conduction-update.hurl.

PUT {{base_url}}/classes/9475/conduction/947502
Authorization: {{auth_cd_teacher4}}
{"conductedOn": "2025-11-04", "conducted": false, "nonConductionReason": "Ra\u0000in"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "nonConductionReason must not contain a NUL byte"

PUT {{base_url}}/classes/9475/conduction/947502
Authorization: {{auth_cd_teacher4}}
{"conductedOn": "2025-11-04", "conducted": false, "nonConductionReason": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "nonConductionReason must be at most 100 characters"

PUT {{base_url}}/classes/9475/conduction/947502
Authorization: {{auth_cd_teacher4}}
{"conductedOn": "2025-11-04", "duration": 30, "students": [{"token": 900831, "present": true}], "extraStudents": [{"name": "Ex\u0000tra", "present": true}], "aqaedConducted": true, "aqaedTopic": "T"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "extraStudents name must not contain a NUL byte"

PUT {{base_url}}/classes/9475/conduction/947502
Authorization: {{auth_cd_teacher4}}
{"conductedOn": "2025-11-04", "duration": 99999999999, "students": [{"token": 900831, "present": true}], "aqaedConducted": true, "aqaedTopic": "T"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "duration is out of range"
