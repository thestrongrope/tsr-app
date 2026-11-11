# PUT /classes/{class_id}/students/{token} contract: edit a student's name, email, mobile and notes; answers with the roster. Runs against any implementation.
# Variables: base_url and auth_<alias>. B2C fixtures (reset by tools/classes-contract.sh): class 9433 (gents; students 900621 with note "Bc note" and 900622 active, 900623 removed), class 9434 (900624), the ladies class 9414,
# the closed class 9432, the gents admin 900501, the ladies admin 900502, the teacher 900511 (no classes:update), a student 900521. Every fixture email is example.invalid, so an email change away from a placeholder
# has no success case here (the synthetic-stack guard forbids a placeholder member); db/tests/StudentEditTests.cs covers it.

# 1. Without sign-in: 401
PUT {{base_url}}/classes/9433/students/900621
{"name": "x"}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Unknown or closed class: 404 before the permission check
PUT {{base_url}}/classes/999999/students/900621
Authorization: {{auth_en_student}}
{"name": "x"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

PUT {{base_url}}/classes/9432/students/900621
Authorization: {{auth_en_gadmin}}
{"name": "x"}
HTTP 404

# 3. Who may edit: not a student, not the class's teacher, not the other gender's admin, not an admin on a class of the other gender
PUT {{base_url}}/classes/9433/students/900621
Authorization: {{auth_en_student}}
{"name": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage this class"

PUT {{base_url}}/classes/9433/students/900621
Authorization: {{auth_en_teacher}}
{"name": "x"}
HTTP 403

PUT {{base_url}}/classes/9433/students/900621
Authorization: {{auth_en_ladmin}}
{"name": "x"}
HTTP 403

PUT {{base_url}}/classes/9414/students/900621
Authorization: {{auth_en_gadmin}}
{"name": "x"}
HTTP 403

# 4. A member who is not on the active roster of THIS class (removed, in another class, no such member): 404 before the body is read
PUT {{base_url}}/classes/9433/students/900623
Authorization: {{auth_en_gadmin}}
{"name": "x"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Student not found in this class"

PUT {{base_url}}/classes/9433/students/900624
Authorization: {{auth_en_gadmin}}
{"name": "x"}
HTTP 404

PUT {{base_url}}/classes/9433/students/999999999
Authorization: {{auth_en_gadmin}}
{}
HTTP 404

# 5. The four fields are text of at most 500 characters
PUT {{base_url}}/classes/9433/students/900621
Authorization: {{auth_en_gadmin}}
{"name": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "name must be text of at most 500 characters"

PUT {{base_url}}/classes/9433/students/900621
Authorization: {{auth_en_gadmin}}
{"email": ["a@example.invalid"]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "email must be text of at most 500 characters"

PUT {{base_url}}/classes/9433/students/900621
Authorization: {{auth_en_gadmin}}
{"mobile": true}
HTTP 422
[Asserts]
jsonpath "$.detail" == "mobile must be text of at most 500 characters"

PUT {{base_url}}/classes/9433/students/900621
Authorization: {{auth_en_gadmin}}
{"notes": "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "notes must be text of at most 500 characters"

PUT {{base_url}}/classes/9433/students/900621
Authorization: {{auth_en_gadmin}}
Content-Type: application/json
```
{"name": "tru
```
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

# 6. The email: another member's token address, a malformed address, then a change the member's own sign-in forbids
PUT {{base_url}}/classes/9433/students/900621
Authorization: {{auth_en_gadmin}}
{"email": "900999@thestrongrope.com"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Email can only be 900621@thestrongrope.com (your token) or a real email address. Cannot use other token emails."

PUT {{base_url}}/classes/9433/students/900621
Authorization: {{auth_en_gadmin}}
{"email": "not an email"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Please provide a valid email address"

PUT {{base_url}}/classes/9433/students/900621
Authorization: {{auth_en_gadmin}}
{"email": "someone.else@example.invalid", "name": "Must Not Be Saved", "notes": "Must not be saved"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "This member signs in with their own email; it cannot be changed here."

PUT {{base_url}}/classes/9433/students/900621
Authorization: {{auth_en_gadmin}}
{"email": "900621@thestrongrope.com"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "This member signs in with their own email; it cannot be changed here."

# ... and the refusals changed nothing
GET {{base_url}}/classes/9433/manage
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students[?(@.token==900621)].name" == "Bc Member 900621"
jsonpath "$.students[?(@.token==900621)].email" == "en.900621@example.invalid"
jsonpath "$.students[?(@.token==900621)].notes" == "Bc note"

# 7. The write admin may edit too; the member's own address (any case) is accepted; fields are trimmed; an unknown field is ignored
PUT {{base_url}}/classes/9433/students/900621
Authorization: {{auth_wr_admin}}
{"name": "  New Name  ", "email": "EN.900621@example.invalid", "mobile": " +910000069999 ", "notes": "  a note  ", "gender": "2", "roleid": 1, "token": 5}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.students" count == 2
jsonpath "$.students[?(@.token==900621)].name" == "New Name"
jsonpath "$.students[?(@.token==900621)].email" == "EN.900621@example.invalid"
jsonpath "$.students[?(@.token==900621)].mobile" == "+910000069999"
jsonpath "$.students[?(@.token==900621)].notes" == "a note"
jsonpath "$.students[?(@.token==900622)].name" == "Bc Member 900622"

# ... the roster read afterwards
GET {{base_url}}/classes/9433/manage
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students[?(@.token==900621)].name" == "New Name"
jsonpath "$.students[?(@.token==900621)].mobile" == "+910000069999"
jsonpath "$.students[?(@.token==900621)].notes" == "a note"

# 8. A body with nothing in it blanks the mobile and the notes and keeps the name; a name of "0" is not written (PHP empty())
PUT {{base_url}}/classes/9433/students/900621
Authorization: {{auth_en_gadmin}}
{}
HTTP 200
[Asserts]
jsonpath "$.students[?(@.token==900621)].name" == "New Name"
jsonpath "$.students[?(@.token==900621)].mobile" == null
jsonpath "$.students[?(@.token==900621)].notes" == null

PUT {{base_url}}/classes/9433/students/900622
Authorization: {{auth_en_gadmin}}
{"name": "0", "mobile": "+910000066222", "notes": "0"}
HTTP 200
[Asserts]
jsonpath "$.students[?(@.token==900622)].name" == "Bc Member 900622"
jsonpath "$.students[?(@.token==900622)].mobile" == "+910000066222"
jsonpath "$.students[?(@.token==900622)].notes" == "0"

# 9. Values the columns cannot hold are refused as a failed update, and nothing is changed
PUT {{base_url}}/classes/9433/students/900622
Authorization: {{auth_en_gadmin}}
{"name": "mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm", "mobile": "+910000066000"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Failed to update student"

PUT {{base_url}}/classes/9433/students/900622
Authorization: {{auth_en_gadmin}}
{"mobile": "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Failed to update student"

GET {{base_url}}/classes/9433/manage
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.students[?(@.token==900622)].mobile" == "+910000066222"
