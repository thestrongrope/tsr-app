# POST /classes/{class_id}/deactivate contract: retire a class and remove its students. Runs against any implementation.
# Variables: base_url and auth_<alias>. B2C fixtures (reset by tools/classes-contract.sh): class 9431 (gents, active; students 900611 and 900612 active, 900613 removed; two live schedule slots), class 9432 (already inactive),
# the write admin 900331 (the only holder of deactivated-classes:manage), the gents admin 900501, a student 900521, the teacher 900511.

# 1. Without sign-in: 401
POST {{base_url}}/classes/9431/deactivate
{"type": "completed", "effectiveDate": "2026-01-05", "reason": "x"}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Only the super admin: a student, a teacher and the gents admin are refused before the body or the class is looked at
POST {{base_url}}/classes/9431/deactivate
Authorization: {{auth_en_student}}
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/classes/999999/deactivate
Authorization: {{auth_en_teacher}}
{"type": "completed", "effectiveDate": "2026-01-05", "reason": "x"}
HTTP 403

POST {{base_url}}/classes/9431/deactivate
Authorization: {{auth_en_gadmin}}
{"type": "completed", "effectiveDate": "2026-01-05", "reason": "x"}
HTTP 403

# 3. The body, in PHP's order: type, date, reason (a field that is not text counts as empty); all before the class is looked up
POST {{base_url}}/classes/999999/deactivate
Authorization: {{auth_wr_admin}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid type; expected completed or shutdown"

POST {{base_url}}/classes/9431/deactivate
Authorization: {{auth_wr_admin}}
{"type": 5, "effectiveDate": "2026-01-05", "reason": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid type; expected completed or shutdown"

POST {{base_url}}/classes/9431/deactivate
Authorization: {{auth_wr_admin}}
{"type": "Completed", "effectiveDate": "2026-01-05", "reason": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid type; expected completed or shutdown"

POST {{base_url}}/classes/9431/deactivate
Authorization: {{auth_wr_admin}}
{"type": "completed", "reason": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid effective date; expected YYYY-MM-DD"

POST {{base_url}}/classes/9431/deactivate
Authorization: {{auth_wr_admin}}
{"type": "completed", "effectiveDate": "2026-02-30", "reason": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid effective date; expected YYYY-MM-DD"

POST {{base_url}}/classes/9431/deactivate
Authorization: {{auth_wr_admin}}
{"type": "completed", "effectiveDate": "2026-1-05", "reason": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid effective date; expected YYYY-MM-DD"

POST {{base_url}}/classes/9431/deactivate
Authorization: {{auth_wr_admin}}
{"type": "completed", "effectiveDate": 20260105, "reason": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid effective date; expected YYYY-MM-DD"

POST {{base_url}}/classes/9431/deactivate
Authorization: {{auth_wr_admin}}
{"type": "shutdown", "effectiveDate": "2026-01-05"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Reason is required"

POST {{base_url}}/classes/9431/deactivate
Authorization: {{auth_wr_admin}}
{"type": "shutdown", "effectiveDate": "2026-01-05", "reason": "   "}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Reason is required"

POST {{base_url}}/classes/9431/deactivate
Authorization: {{auth_wr_admin}}
{"type": "shutdown", "effectiveDate": "2026-01-05", "reason": ["x"]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Reason is required"

POST {{base_url}}/classes/9431/deactivate
Authorization: {{auth_wr_admin}}
{"type": "shutdown", "effectiveDate": "2026-01-05", "reason": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Reason must be 300 characters or fewer"

POST {{base_url}}/classes/9431/deactivate
Authorization: {{auth_wr_admin}}
Content-Type: application/json
```
{"type": "comp
```
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

# 4. The class: unknown (404), already inactive (409)
POST {{base_url}}/classes/999999/deactivate
Authorization: {{auth_wr_admin}}
{"type": "completed", "effectiveDate": "2026-01-05", "reason": "x"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class #999999 not found"

POST {{base_url}}/classes/9432/deactivate
Authorization: {{auth_wr_admin}}
{"type": "completed", "effectiveDate": "2026-01-05", "reason": "x"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "Class #9432 is not active (status=I)"

# 5. Before: the class answers
GET {{base_url}}/classes/9431/manage
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 2

GET {{base_url}}/classes/9431/schedule
Authorization: {{auth_wr_admin}}
HTTP 200

# 6. The super admin deactivates it: the reason is trimmed, the answer names the class and the audit row
POST {{base_url}}/classes/9431/deactivate
Authorization: {{auth_wr_admin}}
{"type": "completed", "effectiveDate": "2026-01-05", "reason": "  Course finished  "}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.deactivated" == true
jsonpath "$.classId" == 9431
jsonpath "$.auditId" isInteger

# ... and the class is gone for every reader (a deactivated class answers 404, never closed)
GET {{base_url}}/classes/9431/manage
Authorization: {{auth_wr_admin}}
HTTP 404

GET {{base_url}}/classes/9431/schedule
Authorization: {{auth_wr_admin}}
HTTP 404

GET {{base_url}}/classes/9431
Authorization: {{auth_wr_admin}}
HTTP 404

# 7. Repeating it: the class is no longer active
POST {{base_url}}/classes/9431/deactivate
Authorization: {{auth_wr_admin}}
{"type": "shutdown", "effectiveDate": "2026-01-06", "reason": "again"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "Class #9431 is not active (status=I)"
