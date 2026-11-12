# POST /admin/quiz/download, /winners/generate, /winners/regenerate and /publish contract: the refusals that come before the advisory lock, with the settings never loaded (no Google on either side).
# Runs against any implementation. Variables: base_url and auth_sheets_<alias> (tools/contract-sheets.sh). Fixtures: db/synthetic/sheets-fixtures.sql.
# None of these requests reaches the quiz admin lock, so this file may run in parallel with the others; refresh and reset (which do) are in admin-quiz-locked.hurl.
# Order everywhere: 401, quiz:admin 403, body 422, target 422 (kind or what), settings loaded 409.

# 1. Without sign-in: 401
POST {{base_url}}/admin/quiz/download
Content-Type: application/json
{}
HTTP 401

POST {{base_url}}/admin/quiz/winners/generate
Content-Type: application/json
{"kind": "daily"}
HTTP 401

POST {{base_url}}/admin/quiz/winners/regenerate
Content-Type: application/json
{"kind": "daily"}
HTTP 401

POST {{base_url}}/admin/quiz/publish
Content-Type: application/json
{"what": "winners"}
HTTP 401

# 2. No quiz:admin: no grant, quiz:reset alone, a super admin, a revoked grant (before the body is read)
POST {{base_url}}/admin/quiz/download
Authorization: {{auth_sheets_plain}}
Content-Type: application/json
{}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/admin/quiz/download
Authorization: {{auth_sheets_reset}}
Content-Type: application/json
{}
HTTP 403

POST {{base_url}}/admin/quiz/winners/generate
Authorization: {{auth_sheets_super}}
Content-Type: application/json
`not json`
HTTP 403

POST {{base_url}}/admin/quiz/winners/regenerate
Authorization: {{auth_sheets_revoked}}
Content-Type: application/json
{"kind": "daily"}
HTTP 403

POST {{base_url}}/admin/quiz/publish
Authorization: {{auth_sheets_reset}}
Content-Type: application/json
`not json`
HTTP 403

# 3. Download: the settings must be loaded first (409), whatever the body
POST {{base_url}}/admin/quiz/download
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{}
HTTP 409
[Asserts]
jsonpath "$.detail" == "The quiz settings have not been loaded yet. Refresh them first."

# 4. Draws: the body (422 invalid JSON), the kind (422 Unknown kind. for a missing, wrong or non-text kind), then the settings (409)
POST {{base_url}}/admin/quiz/winners/generate
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
`not json`
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

POST {{base_url}}/admin/quiz/winners/regenerate
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
`not json`
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

POST {{base_url}}/admin/quiz/winners/generate
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Unknown kind."

POST {{base_url}}/admin/quiz/winners/regenerate
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{"kind": "weekly"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Unknown kind."

POST {{base_url}}/admin/quiz/winners/generate
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{"kind": 1}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Unknown kind."

POST {{base_url}}/admin/quiz/winners/generate
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
[]
HTTP 422
[Asserts]
jsonpath "$.detail" == "Unknown kind."

POST {{base_url}}/admin/quiz/winners/generate
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{"kind": "daily"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "The quiz settings have not been loaded yet. Refresh them first."

POST {{base_url}}/admin/quiz/winners/generate
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{"kind": "grand"}
HTTP 409

POST {{base_url}}/admin/quiz/winners/generate
Authorization: {{auth_sheets_quizreset}}
Content-Type: application/json
{"kind": "mega"}
HTTP 409

POST {{base_url}}/admin/quiz/winners/generate
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{"kind": "mega_student"}
HTTP 409

POST {{base_url}}/admin/quiz/winners/regenerate
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{"kind": "daily"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "The quiz settings have not been loaded yet. Refresh them first."

POST {{base_url}}/admin/quiz/winners/regenerate
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{"kind": "grand"}
HTTP 409

POST {{base_url}}/admin/quiz/winners/regenerate
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{"kind": "mega_student"}
HTTP 409

# 5. Publish: the body (422), the target (422 Unknown target.), then the settings (409)
POST {{base_url}}/admin/quiz/publish
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
`not json`
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

POST {{base_url}}/admin/quiz/publish
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Unknown target."

POST {{base_url}}/admin/quiz/publish
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{"what": "everything"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Unknown target."

POST {{base_url}}/admin/quiz/publish
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{"what": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Unknown target."

POST {{base_url}}/admin/quiz/publish
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{"what": "scoreboard"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "The quiz settings have not been loaded yet. Refresh them first."

POST {{base_url}}/admin/quiz/publish
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{"what": "winners"}
HTTP 409

POST {{base_url}}/admin/quiz/publish
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{"what": "mega"}
HTTP 409

POST {{base_url}}/admin/quiz/publish
Authorization: {{auth_sheets_quiz}}
Content-Type: application/json
{"what": "mega_student"}
HTTP 409
