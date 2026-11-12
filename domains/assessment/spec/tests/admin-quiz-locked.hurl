# POST /admin/quiz/settings/refresh and /admin/quiz/reset contract: the two actions that take the quiz admin lock. Runs against any implementation.
# Variables: base_url and auth_sheets_<alias> (tools/contract-sheets.sh). Fixtures: db/synthetic/sheets-fixtures.sql.
# Both are in ONE file because Hurl runs files in parallel and the lock is global. No Google on either side: a refresh cannot read the settings sheet (502) and leaves any loaded settings as they were
# (here none, so the overview stays "not loaded"); a reset of an empty cycle succeeds and changes nothing a reader can see. What a readable sheet does is proved by db/tests/TestSheetsTests.cs.

# 1. Refresh without sign-in: 401; without quiz:admin: 403
POST {{base_url}}/admin/quiz/settings/refresh
Content-Type: application/json
{}
HTTP 401
[Asserts]
jsonpath "$.detail" == "Not authenticated"

POST {{base_url}}/admin/quiz/settings/refresh
Authorization: {{auth_sheets_plain}}
Content-Type: application/json
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/admin/quiz/settings/refresh
Authorization: {{auth_sheets_reset}}
Content-Type: application/json
{}
HTTP 403

POST {{base_url}}/admin/quiz/settings/refresh
Authorization: {{auth_sheets_super}}
Content-Type: application/json
{}
HTTP 403

POST {{base_url}}/admin/quiz/settings/refresh
Authorization: {{auth_sheets_revoked}}
Content-Type: application/json
{}
HTTP 403

# 2. Refresh with no settings sheet configured and no credential: 502, the settings are unchanged (a body is not read)
POST {{base_url}}/admin/quiz/settings/refresh
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{}
HTTP 502
[Asserts]
jsonpath "$.detail" == "The settings sheet could not be read. The settings are unchanged."

POST {{base_url}}/admin/quiz/settings/refresh
Authorization: {{auth_sheets_quizreset}}
Content-Type: application/json
`not json`
HTTP 502
[Asserts]
jsonpath "$.detail" == "The settings sheet could not be read. The settings are unchanged."

GET {{base_url}}/admin/quiz
Authorization: {{auth_sheets_quiz}}
HTTP 200
[Asserts]
jsonpath "$.settings.loaded" == false

# 3. Reset without sign-in: 401; without quiz:admin: 403 (quiz:reset alone is not enough)
POST {{base_url}}/admin/quiz/reset
Content-Type: application/json
{}
HTTP 401

POST {{base_url}}/admin/quiz/reset
Authorization: {{auth_sheets_plain}}
Content-Type: application/json
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/admin/quiz/reset
Authorization: {{auth_sheets_reset}}
Content-Type: application/json
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/admin/quiz/reset
Authorization: {{auth_sheets_super}}
Content-Type: application/json
{}
HTTP 403

# 4. quiz:admin without quiz:reset: 403 with its own text, nothing deleted
POST {{base_url}}/admin/quiz/reset
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Deleting all quiz data needs the quiz reset permission."

# 5. Both permissions: the cycle's data is deleted (nothing to delete here); the body is not read
POST {{base_url}}/admin/quiz/reset
Authorization: {{auth_sheets_quizreset}}
Content-Type: application/json
{}
HTTP 200
[Asserts]
jsonpath "$.outcome" == "complete"
jsonpath "$.message" == "All quiz data was deleted."
jsonpath "$.changed" == true

POST {{base_url}}/admin/quiz/reset
Authorization: {{auth_sheets_quizreset}}
Content-Type: application/json
`not json`
HTTP 200
[Asserts]
jsonpath "$.message" == "All quiz data was deleted."

GET {{base_url}}/admin/quiz
Authorization: {{auth_sheets_quizreset}}
HTTP 200
[Asserts]
jsonpath "$.quiz_day" == 0
jsonpath "$.download" == null
jsonpath "$.winners.episodes" count == 0
jsonpath "$.can_reset" == true
