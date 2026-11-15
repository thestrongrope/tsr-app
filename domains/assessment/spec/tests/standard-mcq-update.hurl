# POST /standard-mcqs/update contract: refusals, the body rules, and the answers when the source sheet cannot be read. Runs against any implementation.
# Variables: base_url and auth_sheets_<alias> (tools/contract-sheets.sh). Fixtures: db/synthetic/sheets-fixtures.sql.
# Neither side has Google credentials, so no pair can be read: every well-formed pair is "failed" and NOTHING is written (PHP: "The sheet could not be read"). What a readable sheet does is proved by db/tests/TestSheetsTests.cs.
# This file is the only one that reaches the standard MCQ update lock (5001); Hurl runs files in parallel.

# 1. Without sign-in: 401; no permission: 403 (before the body is read)
POST {{base_url}}/standard-mcqs/update
Content-Type: application/json
{"languages": [1], "levels": [1]}
HTTP 401
[Asserts]
jsonpath "$.detail" == "Not authenticated"

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_plain}}
Content-Type: application/json
`not json`
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_revoked}}
Content-Type: application/json
{"languages": [1], "levels": [1]}
HTTP 403

# 2. The body: invalid JSON, an empty one, a missing or empty list (languages is checked before levels)
POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
`not json`
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
"a string"
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose at least one in languages"

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": [], "levels": [1]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose at least one in languages"

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": "1", "levels": [1]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose at least one in languages"

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": [1]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose at least one in levels"

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": [1], "levels": []}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose at least one in levels"

# 3. Ids must be whole numbers from 1: a decimal, a text, a boolean, zero, a negative, a number too big for an integer, null and a list inside the list
POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": [1.0], "levels": [1]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "languages must be a list of ids"

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": ["1"], "levels": [1]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "languages must be a list of ids"

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": [true], "levels": [1]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "languages must be a list of ids"

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": [0], "levels": [1]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "languages must be a list of ids"

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": [-1], "levels": [1]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "languages must be a list of ids"

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": [99999999999999999999], "levels": [1]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "languages must be a list of ids"

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": [null], "levels": [1]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "languages must be a list of ids"

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": [[1]], "levels": [1]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "languages must be a list of ids"

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": [1], "levels": ["x"]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "levels must be a list of ids"

# 4. A well-formed pair: the sheet cannot be read (no credentials), nothing is written
POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": [1], "levels": [1]}
HTTP 200
[Asserts]
jsonpath "$.results" count == 1
jsonpath "$.results[0].language_id" == 1
jsonpath "$.results[0].level_id" == 1
jsonpath "$.results[0].language" == "English"
jsonpath "$.results[0].level" == "Abuzar"
jsonpath "$.results[0].status" == "failed"
jsonpath "$.results[0].reason" == "The sheet could not be read"
jsonpath "$.results[0].quizzes" not exists

# 5. A super admin may update; the same id twice is one pair; an object holding the ids is accepted as a list (PHP's arrays)
POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_super}}
Content-Type: application/json
{"languages": [1, 1], "levels": [1]}
HTTP 200
[Asserts]
jsonpath "$.results" count == 1

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": {"a": 2}, "levels": [3]}
HTTP 200
[Asserts]
jsonpath "$.results" count == 1
jsonpath "$.results[0].language" == "Urdu"
jsonpath "$.results[0].level" == "Ammar"

# 6. An unknown id is a failed row with an empty name; every other pair is told another sheet could not be read; the order is language by level
POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": [9], "levels": [1]}
HTTP 200
[Asserts]
jsonpath "$.results" count == 1
jsonpath "$.results[0].language_id" == 9
jsonpath "$.results[0].language" == ""
jsonpath "$.results[0].level" == "Abuzar"
jsonpath "$.results[0].status" == "failed"
jsonpath "$.results[0].reason" == "Unknown language or level"

POST {{base_url}}/standard-mcqs/update
Authorization: {{auth_sheets_mcq}}
Content-Type: application/json
{"languages": [1, 2], "levels": [1, 9]}
HTTP 200
[Asserts]
jsonpath "$.results" count == 4
jsonpath "$.results[0].language" == "English"
jsonpath "$.results[0].level" == "Abuzar"
jsonpath "$.results[0].reason" == "The sheet could not be read"
jsonpath "$.results[1].language" == "English"
jsonpath "$.results[1].level" == ""
jsonpath "$.results[1].reason" == "Unknown language or level"
jsonpath "$.results[2].language" == "Urdu"
jsonpath "$.results[2].level" == "Abuzar"
jsonpath "$.results[2].reason" == "The sheet could not be read"
jsonpath "$.results[3].language" == "Urdu"
jsonpath "$.results[3].level" == ""
jsonpath "$.results[3].reason" == "Unknown language or level"
