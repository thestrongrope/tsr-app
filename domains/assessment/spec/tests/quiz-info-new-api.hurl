# GET /quiz/info contract: the Grand/Mega status the app's home banner reads. New API only (PHP serves the quiz as api/quiz_info.php, with another body and error shape).
# Variables: base_url and auth_sheets_<alias> (tools/contract-sheets.sh; it runs this file by itself, after the parallel files, because a request here tries the quiz admin lock). Fixtures: db/synthetic/sheets-fixtures.sql.
# No Google credentials and no settings document on this stack, so the quiz is not configured; the status rules, the 60-second refresh, the sheet failures and the member fields are proven with the sheet faked in db/tests/TestSheetsQuizInfoTests.cs
# and domains/assessment/api/domain/QuizInfoBody.Tests.cs. This file proves what only HTTP shows: the route is public, a bad bearer is refused, the body is the whole object, the caching header.

# 1. Signed out: 200, not cached, the offline body as it is (no {success, data} wrapper)
GET {{base_url}}/quiz/info
HTTP 200
Cache-Control: no-store
[Asserts]
jsonpath "$.status" == "offline"
jsonpath "$.message" == "No quiz is currently configured"
jsonpath "$.success" not exists
jsonpath "$.data" not exists

# 2. Signed in (a member with no grant): the same body, still not cached
GET {{base_url}}/quiz/info
Authorization: {{auth_sheets_plain}}
HTTP 200
Cache-Control: no-store
[Asserts]
jsonpath "$.status" == "offline"

# 3. A quiz admin: the same
GET {{base_url}}/quiz/info
Authorization: {{auth_sheets_quiz}}
HTTP 200
[Asserts]
jsonpath "$.status" == "offline"

# 4. A bearer that is not a token: 401 with PHP's wording, never a member made
GET {{base_url}}/quiz/info
Authorization: Bearer not-a-real-token
HTTP 401
[Asserts]
jsonpath "$.detail" == "Authentication failed"

# 5. A query token is not read: the route answers as signed out (PHP's ?token= is not ported)
GET {{base_url}}/quiz/info?token=923001
HTTP 200
[Asserts]
jsonpath "$.status" == "offline"
