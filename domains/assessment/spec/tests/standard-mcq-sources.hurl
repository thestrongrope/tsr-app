# GET /standard-mcqs/sources contract: the languages and levels the Standard MCQs can be updated for (static lists). Runs against any implementation.
# Variables: base_url and auth_sheets_<alias> (tools/contract-sheets.sh). Fixtures: db/synthetic/sheets-fixtures.sql (read its header). Reads nothing, writes nothing.

# 1. Without sign-in: 401
GET {{base_url}}/standard-mcqs/sources
HTTP 401
[Asserts]
jsonpath "$.detail" == "Not authenticated"

# 2. A member with no role or grant, and one whose only grant was revoked: 403
GET {{base_url}}/standard-mcqs/sources
Authorization: {{auth_sheets_plain}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/standard-mcqs/sources
Authorization: {{auth_sheets_revoked}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. A gender admin and a holder of the quiz permissions only: 403 (neither holds standard-mcqs:update)
GET {{base_url}}/standard-mcqs/sources
Authorization: {{auth_sheets_gents}}
HTTP 403

GET {{base_url}}/standard-mcqs/sources
Authorization: {{auth_sheets_quizreset}}
HTTP 403

# 4. A super admin (the role holds standard-mcqs:update) and a holder of the named grant: the lists, ids from 1
GET {{base_url}}/standard-mcqs/sources
Authorization: {{auth_sheets_super}}
HTTP 200
[Asserts]
jsonpath "$.languages" count == 3
jsonpath "$.languages[0].id" == 1
jsonpath "$.languages[0].name" == "English"
jsonpath "$.languages[1].name" == "Urdu"
jsonpath "$.languages[2].id" == 3
jsonpath "$.languages[2].name" == "Gujarati"
jsonpath "$.levels" count == 3
jsonpath "$.levels[0].name" == "Abuzar"
jsonpath "$.levels[1].id" == 2
jsonpath "$.levels[1].name" == "Miqdad"
jsonpath "$.levels[2].name" == "Ammar"

GET {{base_url}}/standard-mcqs/sources
Authorization: {{auth_sheets_mcq}}
HTTP 200
[Asserts]
jsonpath "$.languages" count == 3
jsonpath "$.levels" count == 3
