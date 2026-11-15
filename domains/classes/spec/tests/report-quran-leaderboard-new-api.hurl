# Quran leaderboard, cases only the new API runs (PHP answers most of them the same way, but on the shared parity stack the administrators' defaults cover other fixtures; kept here so the parity file stays about PHP's contract).
# Variables: base_url and auth_r2_<alias>. REPORTS2 fixtures (see report-quran-leaderboard.hurl). A NUL byte or an absurd value is never a 500.

# 1. NUL bytes: in the level (PHP trim() strips it: no level), the minimum (not a number: 1), the gender (gents), the dates (422)
GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&level=%00
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 7

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&minimum=%00
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 7

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&gender=%00
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1

GET {{base_url}}/reports/quran-leaderboard?from=%00&to=2019-03-31
Authorization: {{auth_r2_super}}
HTTP 422

GET {{base_url}}/reports/quran-leaderboard/download?format=xlsx&from=2019-03-01&to=2019-03-31&level=%00
Authorization: {{auth_r2_super}}
HTTP 200

# 2. A full-width digit is not a digit; the year 0001 and 9999 are real days
GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&level=%EF%BC%A1
Authorization: {{auth_r2_super}}
HTTP 422

GET {{base_url}}/reports/quran-leaderboard?from=%EF%BC%92019-03-01&to=2019-03-31
Authorization: {{auth_r2_super}}
HTTP 422

GET {{base_url}}/reports/quran-leaderboard?from=0001-01-01&to=0001-01-02
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 0

GET {{base_url}}/reports/quran-leaderboard?from=9999-12-30&to=9999-12-31
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 0

GET {{base_url}}/reports/quran-leaderboard?from=0000-01-01&to=2019-03-31
Authorization: {{auth_r2_super}}
HTTP 422

# 3. Ties are ordered by token, then class id (PHP leaves them to the database)
GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.students[2].token" == 921022
jsonpath "$.students[2].class" == "R2-G-102"
jsonpath "$.students[3].token" == 921022
jsonpath "$.students[3].class" == "R2-G-106"
jsonpath "$.students[4].token" == 921023
