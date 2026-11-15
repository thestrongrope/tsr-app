# POST /classes/{class_id}/students/{token}/transfer contract: move a student to another class of the same gender; answers with the SOURCE class's roster. Runs against any implementation.
# Variables: base_url and auth_<alias>. ENROLMENT fixtures (reset by tools/classes-contract.sh): source class 9415 (gents; teacher 900511; 900551, 900552, 900553, 900554 active, 900555 removed), destination 9416
# (gents; 900552 is already in it), the ladies class 9414, the closed class 9417, the other class 9412 (900532), the write admin 900331 (the only caller with students:transfer), the gents admin 900501.

# 1. Without sign-in: 401
POST {{base_url}}/classes/9415/students/900551/transfer
{"toClassId": 9416}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Unknown or closed class: 404 before the permission check
POST {{base_url}}/classes/999999/students/900551/transfer
Authorization: {{auth_en_student}}
{"toClassId": 9416}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

POST {{base_url}}/classes/9417/students/900551/transfer
Authorization: {{auth_wr_admin}}
{"toClassId": 9416}
HTTP 404

# 3. Only the all-scope administrator may transfer: a student, the class's teacher, and the gents and ladies admins are refused
POST {{base_url}}/classes/9415/students/900551/transfer
Authorization: {{auth_en_student}}
{"toClassId": 9416}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only administrators can transfer students"

POST {{base_url}}/classes/9415/students/900551/transfer
Authorization: {{auth_en_teacher}}
{"toClassId": 9416}
HTTP 403

POST {{base_url}}/classes/9415/students/900551/transfer
Authorization: {{auth_en_gadmin}}
{"toClassId": 9416}
HTTP 403

POST {{base_url}}/classes/9415/students/900551/transfer
Authorization: {{auth_en_ladmin}}
{"toClassId": 9416}
HTTP 403

# 4. A member who is not on the active roster of THIS class (removed, in another class, no such member): 404 before the body is read
POST {{base_url}}/classes/9415/students/900555/transfer
Authorization: {{auth_wr_admin}}
{"toClassId": 9416}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Student not found in this class"

POST {{base_url}}/classes/9415/students/900532/transfer
Authorization: {{auth_wr_admin}}
{"toClassId": 9416}
HTTP 404

POST {{base_url}}/classes/9415/students/999999999/transfer
Authorization: {{auth_wr_admin}}
{}
HTTP 404

# 5. The body, in PHP's order: toClassId, type, reason
POST {{base_url}}/classes/9415/students/900551/transfer
Authorization: {{auth_wr_admin}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "toClassId must be a different class"

POST {{base_url}}/classes/9415/students/900551/transfer
Authorization: {{auth_wr_admin}}
{"toClassId": "9416"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "toClassId must be a different class"

POST {{base_url}}/classes/9415/students/900551/transfer
Authorization: {{auth_wr_admin}}
{"toClassId": 9415}
HTTP 422
[Asserts]
jsonpath "$.detail" == "toClassId must be a different class"

POST {{base_url}}/classes/9415/students/900551/transfer
Authorization: {{auth_wr_admin}}
{"toClassId": 9416, "type": "move"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "type must be transfer, promotion or demotion"

POST {{base_url}}/classes/9415/students/900551/transfer
Authorization: {{auth_wr_admin}}
{"toClassId": 9416, "type": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "type must be transfer, promotion or demotion"

POST {{base_url}}/classes/9415/students/900551/transfer
Authorization: {{auth_wr_admin}}
{"toClassId": 9416, "reason": "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason must be at most 500 characters"

POST {{base_url}}/classes/9415/students/900551/transfer
Authorization: {{auth_wr_admin}}
Content-Type: application/json
```
{"toClassId": 94
```
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

# 6. The destination: an active class (404), of the same gender (422), without the student already in it (422)
POST {{base_url}}/classes/9415/students/900551/transfer
Authorization: {{auth_wr_admin}}
{"toClassId": 999999}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

POST {{base_url}}/classes/9415/students/900551/transfer
Authorization: {{auth_wr_admin}}
{"toClassId": 9417}
HTTP 404

POST {{base_url}}/classes/9415/students/900551/transfer
Authorization: {{auth_wr_admin}}
{"toClassId": 0}
HTTP 404

POST {{base_url}}/classes/9415/students/900551/transfer
Authorization: {{auth_wr_admin}}
{"toClassId": 9414}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A student can only move to a class of the same gender"

POST {{base_url}}/classes/9415/students/900552/transfer
Authorization: {{auth_wr_admin}}
{"toClassId": 9416}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Student 900552 is already enrolled in destination class #9416"

# ... and nothing moved
GET {{base_url}}/classes/9415/students
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 4

# 7. A plain transfer: off the source roster, on the destination's, in the history, not on the removed list
POST {{base_url}}/classes/9415/students/900551/transfer
Authorization: {{auth_wr_admin}}
{"toClassId": 9416}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.students" count == 3
jsonpath "$.students[?(@.token==900551)]" not exists
jsonpath "$.removedStudents" count == 1
jsonpath "$.removedStudents[0].token" == 900555
jsonpath "$.transferHistory" count == 1
jsonpath "$.transferHistory[0].studentToken" == 900551
jsonpath "$.transferHistory[0].fromClassId" == 9415
jsonpath "$.transferHistory[0].toClassId" == 9416
jsonpath "$.transferHistory[0].type" == "transfer"
jsonpath "$.transferHistory[0].reason" == null
jsonpath "$.transferHistory[0].transferredBy" == "Wr Admin"

# 8. A promotion with a reason (trimmed) and a demotion without one
POST {{base_url}}/classes/9415/students/900553/transfer
Authorization: {{auth_wr_admin}}
{"toClassId": 9416, "type": "promotion", "reason": "  good progress  "}
HTTP 200
[Asserts]
jsonpath "$.students" count == 2
jsonpath "$.transferHistory" count == 2
jsonpath "$.transferHistory[?(@.studentToken==900553)].type" == "promotion"
jsonpath "$.transferHistory[?(@.studentToken==900553)].reason" == "good progress"

POST {{base_url}}/classes/9415/students/900554/transfer
Authorization: {{auth_wr_admin}}
{"toClassId": 9416, "type": "demotion"}
HTTP 200
[Asserts]
jsonpath "$.students" count == 1
jsonpath "$.students[0].token" == 900552
jsonpath "$.transferHistory[?(@.studentToken==900554)].type" == "demotion"

# 9. The destination now holds all four (900552 already did), once each
GET {{base_url}}/classes/9416/students
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 4

# 10. Moving the same student again: not on the source roster any more, 404
POST {{base_url}}/classes/9415/students/900551/transfer
Authorization: {{auth_wr_admin}}
{"toClassId": 9416}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Student not found in this class"
