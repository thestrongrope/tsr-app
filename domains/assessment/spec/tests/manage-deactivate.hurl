# POST /mcq/manage/{quiz_id}/deactivate contract: deactivate (or reactivate) a quiz. Runs against any implementation.
# Variables: base_url and auth_qm_<alias> (tools/assessment-contract.sh). Fixtures: db/synthetic/assessment-a2-fixtures.sql (read its header).
# Writes quizzes 963406 and 963407 only (no other file does) and leaves both active again, so the file can be run twice.

# 1. Without sign-in: 401
POST {{base_url}}/mcq/manage/963406/deactivate
Content-Type: application/json
{}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A missing quiz is 404 before any permission check; a quiz of a closed class is a class 404; a non-number is a quiz that does not exist
POST {{base_url}}/mcq/manage/99999999/deactivate
Authorization: {{auth_qm_nobody}}
Content-Type: application/json
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

POST {{base_url}}/mcq/manage/abc/deactivate
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

POST {{base_url}}/mcq/manage/963441/deactivate
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 3. Refused, and the quiz is not touched: a plain student, the admin of another class, a removed admin, a member of no class, the teacher of another class, a gender admin, a coordinator
POST {{base_url}}/mcq/manage/963406/deactivate
Authorization: {{auth_qm_student}}
Content-Type: application/json
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

POST {{base_url}}/mcq/manage/963406/deactivate
Authorization: {{auth_qm_other_admin}}
Content-Type: application/json
{}
HTTP 403

POST {{base_url}}/mcq/manage/963406/deactivate
Authorization: {{auth_qm_removed_admin}}
Content-Type: application/json
{}
HTTP 403

POST {{base_url}}/mcq/manage/963406/deactivate
Authorization: {{auth_qm_nobody}}
Content-Type: application/json
{}
HTTP 403

POST {{base_url}}/mcq/manage/963406/deactivate
Authorization: {{auth_qm_teacher2}}
Content-Type: application/json
{}
HTTP 403

POST {{base_url}}/mcq/manage/963406/deactivate
Authorization: {{auth_qm_gents_admin}}
Content-Type: application/json
{}
HTTP 403

POST {{base_url}}/mcq/manage/963406/deactivate
Authorization: {{auth_qm_coord}}
Content-Type: application/json
{}
HTTP 403

GET {{base_url}}/mcq/manage/963406
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.deactivatedAt" == null

# 4. A body that is not a JSON object or list is 422 (checked after the permission)
POST {{base_url}}/mcq/manage/963406/deactivate
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
"just text"
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

# 5. No body, an empty object or a list means deactivate; the class teacher, a class admin and a super admin may
POST {{base_url}}/mcq/manage/963406/deactivate
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{}
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.deactivated" == true
jsonpath "$.deactivatedAt" matches /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$/

GET {{base_url}}/mcq/manage/963406
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.deactivatedAt" matches /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$/

# deactivating again is accepted (PHP overwrites the time)
POST {{base_url}}/mcq/manage/963406/deactivate
Authorization: {{auth_qm_admin}}
Content-Type: application/json
```
[1]
```
HTTP 200
[Asserts]
jsonpath "$.deactivated" == true

# reactivating clears it
POST {{base_url}}/mcq/manage/963406/deactivate
Authorization: {{auth_qm_super}}
Content-Type: application/json
{"deactivate": false}
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.deactivated" == false
jsonpath "$.deactivatedAt" == null

GET {{base_url}}/mcq/manage/963406
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.deactivatedAt" == null

# 6. The flag is read as PHP's filter_var boolean: true, "1", "true", "on", "yes" and 1 deactivate; "no", "abc", 2, 0 and a list reactivate; null means deactivate
POST {{base_url}}/mcq/manage/963407/deactivate
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"deactivate": "YES"}
HTTP 200
[Asserts]
jsonpath "$.deactivated" == true

POST {{base_url}}/mcq/manage/963407/deactivate
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"deactivate": "abc"}
HTTP 200
[Asserts]
jsonpath "$.deactivated" == false

POST {{base_url}}/mcq/manage/963407/deactivate
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"deactivate": 1}
HTTP 200
[Asserts]
jsonpath "$.deactivated" == true

POST {{base_url}}/mcq/manage/963407/deactivate
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"deactivate": 2}
HTTP 200
[Asserts]
jsonpath "$.deactivated" == false

POST {{base_url}}/mcq/manage/963407/deactivate
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"deactivate": null}
HTTP 200
[Asserts]
jsonpath "$.deactivated" == true

POST {{base_url}}/mcq/manage/963407/deactivate
Authorization: {{auth_qm_teacher}}
Content-Type: application/json
{"deactivate": [true]}
HTTP 200
[Asserts]
jsonpath "$.deactivated" == false

# the quiz is active again, so a second run starts from the fixture
GET {{base_url}}/mcq/manage/963407
Authorization: {{auth_qm_teacher}}
HTTP 200
[Asserts]
jsonpath "$.deactivatedAt" == null
