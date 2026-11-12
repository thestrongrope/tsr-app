# GET /reports/quran-leaderboard/download?format=xlsx|pdf&gender&from&to&level&minimum contract: every ranked student (no top-100 cut) as a file. Runs against any implementation
# (the xlsx cells are compared with PHP by tools/export-parity.sh, cases in tools/export-parity.cases; numbers stay numbers).
# Variables: base_url and auth_r2_<alias>. REPORTS2 fixtures (see report-quran-leaderboard.hurl). The format is checked BEFORE the sign-in (422 first); the permission is quran-leaderboard:read, so r2_coord (reports:read only) is refused.

# 1. A bad format is 422 first, then sign-in (401), permission (403), dates (422), level (422)
GET {{base_url}}/reports/quran-leaderboard/download?from=2019-03-01&to=2019-03-31
HTTP 422
[Asserts]
jsonpath "$.detail" == "format must be xlsx or pdf"

GET {{base_url}}/reports/quran-leaderboard/download?format=csv&from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_super}}
HTTP 422

GET {{base_url}}/reports/quran-leaderboard/download?format=xlsx&from=2019-03-01&to=2019-03-31
HTTP 401

GET {{base_url}}/reports/quran-leaderboard/download?format=xlsx&from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/reports/quran-leaderboard/download?format=pdf&from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_nobody}}
HTTP 403

GET {{base_url}}/reports/quran-leaderboard/download?format=xlsx&from=2019-03-31&to=2019-03-01
Authorization: {{auth_r2_super}}
HTTP 422

GET {{base_url}}/reports/quran-leaderboard/download?format=xlsx&from=2014-03-01&to=2019-03-31
Authorization: {{auth_r2_super}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The range can cover at most five years"

GET {{base_url}}/reports/quran-leaderboard/download?format=xlsx&from=2019-03-01&to=2019-03-31&level=NOSUCH
Authorization: {{auth_r2_super}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Unknown level"

# 2. xlsx and pdf; the file name carries the gender (the lock wins) and both days
GET {{base_url}}/reports/quran-leaderboard/download?format=xlsx&from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_super}}
HTTP 200
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="Quran-leaderboard-Gents-2019-03-01-to-2019-03-31.xlsx"
[Asserts]
bytes startsWith hex,504b;

GET {{base_url}}/reports/quran-leaderboard/download?format=pdf&from=2019-03-01&to=2019-03-31&gender=1
Authorization: {{auth_r2_ladmin}}
HTTP 200
Content-Type: application/pdf
Content-Disposition: attachment; filename="Quran-leaderboard-Ladies-2019-03-01-to-2019-03-31.pdf"
[Asserts]
bytes startsWith hex,25504446;

GET {{base_url}}/reports/quran-leaderboard/download?format=xlsx&from=2019-03-01&to=2019-03-31&gender=2
Authorization: {{auth_r2_gadmin}}
HTTP 200
Content-Disposition: attachment; filename="Quran-leaderboard-Gents-2019-03-01-to-2019-03-31.xlsx"

# 3. The named grant and the coordinator with the grant (limited to its class) get files; a window with nobody is a file with headers only
GET {{base_url}}/reports/quran-leaderboard/download?format=xlsx&from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_named}}
HTTP 200

GET {{base_url}}/reports/quran-leaderboard/download?format=xlsx&from=2019-03-01&to=2019-03-31&minimum=0
Authorization: {{auth_r2_grant}}
HTTP 200

GET {{base_url}}/reports/quran-leaderboard/download?format=xlsx&from=2019-03-31&to=2019-03-31
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
bytes startsWith hex,504b;
