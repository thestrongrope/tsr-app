# POST /mcq/manage/{quiz_id}/publish contract: release a quiz to its class (the push to the class's devices is queued, never sent here). Runs against any implementation.
# Variables: base_url and auth_quizwrites_<alias> (tools/contract-quizwrites.sh). Fixtures: db/synthetic/quizwrites-fixtures.sql (read its header). Quizzes 9720007 (class 98201) and 9720008 (class 98202) are drafts.
# NO fixture member has a device, so nothing can be queued or sent on either side: the counts are 0. What the new API writes (the notification, the inbox rows, the queue rows with their dedupe key, the event) is checked by db/tests/TestQuizwritesTests.cs.

# 1. Without sign-in: 401
POST {{base_url}}/mcq/manage/9720007/publish
Content-Type: application/json
{}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A missing or non-numeric quiz is a 404, a quiz of a closed class is a class 404 (before any permission check)
POST {{base_url}}/mcq/manage/99999999/publish
Authorization: {{auth_quizwrites_student}}
Content-Type: application/json
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

POST {{base_url}}/mcq/manage/abc/publish
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Quiz not found"

POST {{base_url}}/mcq/manage/9720012/publish
Authorization: {{auth_quizwrites_student}}
Content-Type: application/json
{}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

# 3. Refused, the quiz stays a draft: a plain student, a student of another class, the teacher and the class admin of another class, a removed class admin, a member of no class
POST {{base_url}}/mcq/manage/9720007/publish
Authorization: {{auth_quizwrites_student}}
Content-Type: application/json
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

POST {{base_url}}/mcq/manage/9720007/publish
Authorization: {{auth_quizwrites_other_student}}
Content-Type: application/json
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

POST {{base_url}}/mcq/manage/9720007/publish
Authorization: {{auth_quizwrites_other_teacher}}
Content-Type: application/json
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

POST {{base_url}}/mcq/manage/9720007/publish
Authorization: {{auth_quizwrites_other_admin}}
Content-Type: application/json
{}
HTTP 403

POST {{base_url}}/mcq/manage/9720007/publish
Authorization: {{auth_quizwrites_removed_admin}}
Content-Type: application/json
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage MCQs for this class"

POST {{base_url}}/mcq/manage/9720007/publish
Authorization: {{auth_quizwrites_nobody}}
Content-Type: application/json
{}
HTTP 403

GET {{base_url}}/mcq/manage/9720007
Authorization: {{auth_quizwrites_teacher}}
HTTP 200
[Asserts]
jsonpath "$.publishedAt" == null

# 4. The teacher publishes: the reply carries the time and the counts (no device: all 0); the quiz is then published
POST {{base_url}}/mcq/manage/9720007/publish
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{}
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.publishedAt" matches /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}/
jsonpath "$.deviceCount" == 0
jsonpath "$.successCount" == 0
jsonpath "$.failureCount" == 0

GET {{base_url}}/mcq/manage/9720007
Authorization: {{auth_quizwrites_teacher}}
HTTP 200
[Asserts]
jsonpath "$.publishedAt" matches /^[0-9]{4}-/
jsonpath "$.questions" count == 2

# 5. The class admin of 98201 cannot publish a quiz of 98202; the teacher and a super admin can (a quiz with no topic), and publishing again is allowed and answers the same
POST {{base_url}}/mcq/manage/9720008/publish
Authorization: {{auth_quizwrites_admin}}
Content-Type: application/json
{}
HTTP 403

POST {{base_url}}/mcq/manage/9720008/publish
Authorization: {{auth_quizwrites_teacher}}
Content-Type: application/json
{}
HTTP 200
[Asserts]
jsonpath "$.success" == true

POST {{base_url}}/mcq/manage/9720008/publish
Authorization: {{auth_quizwrites_super}}
Content-Type: application/json
{}
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.deviceCount" == 0
jsonpath "$.successCount" == 0
jsonpath "$.failureCount" == 0

# 6. The class admin of the class (98201) publishes a second time a quiz of 98201
POST {{base_url}}/mcq/manage/9720007/publish
Authorization: {{auth_quizwrites_admin}}
Content-Type: application/json
{}
HTTP 200
[Asserts]
jsonpath "$.success" == true
