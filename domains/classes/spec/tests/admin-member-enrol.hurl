# POST /admin/members/{token}/enrolments contract: the super admin enrols a member, found by token, in a class (30 an hour each). Runs against any implementation.
# Variables: base_url and auth_<alias>. B4a fixtures (reset by tools/classes-contract.sh): class 9531 (gents, active; 900981 in it, 900982 removed with the MCQ flag on), 9532 (ladies), 9533 (closed); 900983 and 900984
# free gents, 900985 with no gender, 900995 shared by two members; the enrolment admins 900906 to 900909 (role 1; at most three counted calls each), the gents admin 900501.

# 1. Without sign-in: 401
POST {{base_url}}/admin/members/900984/enrolments
{"classId": 9531}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Only members:enrol-by-token
POST {{base_url}}/admin/members/900984/enrolments
Authorization: {{auth_en_student}}
{"classId": 9531}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/admin/members/900984/enrolments
Authorization: {{auth_en_gadmin}}
{"classId": 9531}
HTTP 403

# 3. The class id must be a JSON integer above 0, then the class must exist and be active (none of these is counted against the limit)
POST {{base_url}}/admin/members/900984/enrolments
Authorization: {{auth_b4_enrol_d}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "classId must be a class id"

POST {{base_url}}/admin/members/900984/enrolments
Authorization: {{auth_b4_enrol_d}}
{"classId": "9531"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "classId must be a class id"

POST {{base_url}}/admin/members/900984/enrolments
Authorization: {{auth_b4_enrol_d}}
{"classId": 0}
HTTP 422

POST {{base_url}}/admin/members/900984/enrolments
Authorization: {{auth_b4_enrol_d}}
{"classId": 999999}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

POST {{base_url}}/admin/members/900984/enrolments
Authorization: {{auth_b4_enrol_d}}
{"classId": 9533}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 4. A free member is enrolled; the answer is the class's roster with saved first (the super admin sees contacts and the transfer history)
POST {{base_url}}/admin/members/900984/enrolments
Authorization: {{auth_b4_enrol_a}}
{"classId": 9531}
HTTP 200
[Asserts]
jsonpath "$.saved" == true
jsonpath "$.students[?(@.token==900984)].name" == "B4 Member 900984"
jsonpath "$.students[?(@.token==900984)].email" == "b4.900984@example.invalid"
jsonpath "$.students[?(@.token==900984)].joinedOn" matches /^\d{4}-\d{2}-\d{2}$/
jsonpath "$.students[?(@.token==900981)].name" == "B4 Member 900981"
jsonpath "$.removedStudents[?(@.token==900982)].name" == "B4 Member 900982"
jsonpath "$.transferHistory" isCollection

# 5. Already in the class: 409 with a code; no token like that: 404
POST {{base_url}}/admin/members/900984/enrolments
Authorization: {{auth_b4_enrol_a}}
{"classId": 9531}
HTTP 409
[Asserts]
jsonpath "$.detail" == "This member is already in this class"
jsonpath "$.code" == "already_enrolled"

POST {{base_url}}/admin/members/999000001/enrolments
Authorization: {{auth_b4_enrol_a}}
{"classId": 9531}
HTTP 404
[Asserts]
jsonpath "$.detail" == "No registered member has this token"

# 6. A member with a removed row gets that row back (the MCQ flag cleared), not a second row
POST {{base_url}}/admin/members/900982/enrolments
Authorization: {{auth_b4_enrol_b}}
{"classId": 9531}
HTTP 200
[Asserts]
jsonpath "$.saved" == true
jsonpath "$.students[?(@.token==900982)].mcqAdmin" == false
jsonpath "$.removedStudents[?(@.token==900982)]" not exists

# 7. A known gender other than the class's: 422 with a code; a token two members share: 422 with its own code
POST {{base_url}}/admin/members/900983/enrolments
Authorization: {{auth_b4_enrol_b}}
{"classId": 9532}
HTTP 422
[Asserts]
jsonpath "$.detail" == "This class is for the other gender"
jsonpath "$.code" == "other_gender"

POST {{base_url}}/admin/members/900995/enrolments
Authorization: {{auth_b4_enrol_b}}
{"classId": 9531}
HTTP 422
[Asserts]
jsonpath "$.detail" == "More than one member has that token number. Please contact an admin."
jsonpath "$.code" == "ambiguous_token"

# 8. A member whose gender is not known may join any class
POST {{base_url}}/admin/members/900985/enrolments
Authorization: {{auth_b4_enrol_c}}
{"classId": 9531}
HTTP 200
[Asserts]
jsonpath "$.students[?(@.token==900985)].name" == "B4 Member 900985"
