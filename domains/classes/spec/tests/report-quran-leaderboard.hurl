# GET /reports/quran-leaderboard?gender&from&to&level&minimum contract: the top 100 rows of the recitation ranking. Runs against any implementation.
# Variables: base_url and auth_r2_<alias>. REPORTS2 fixtures (db/synthetic/reports2-fixtures.sql): every mark is dated March 2019, nobody else's is, so the global ranks are ours alone. Totals over 2019-03-01 to 2019-03-31 (a mark of 9999 on 1 April
# and one of 5000 on 28 February must change nothing): 921024 900 (enrolment removed, status I), 921025 700 (ladies), 921027 600 (closed class), 921021 500, 921026 400 (class 98103), 921022 300 (two classes: listed twice) and 921023 300 (a tie),
# 921030 250 (removed_at set but status A: listed, as PHP), 921029 200 (a gents member in the ladies class 98104), 921028 0.
# Permission is quran-leaderboard:read (its own gender lock), NOT reports:read: r2_super (all), r2_gadmin (gents), r2_ladmin (ladies) and r2_named (the named grant only, no reports:read: no class limit) pass; r2_coord and r2_one (reports:read
# only) and r2_nobody get 403; r2_grant (a coordinator holding the grant) is limited to its assigned class 98101 (finding 3: as PHP, the class limit is read from reports:read).
# PHP quirks copied: ranks are global (computed over every gender, level and class BEFORE the filters); the ordering of tied rows is undefined, so they are matched by token; a minimum is a whole number from 0 up (anything else is 1).

# 1. Sign-in, permission
GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31
HTTP 401

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_nobody}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 403

GET {{base_url}}/reports/quran-leaderboard?from=bad
Authorization: {{auth_r2_one}}
HTTP 403

# 2. The super administrator, gents: ranks 4 5 (6 6 6) 8 9; closed class and removed members counted in the ranks only
GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.from" == "2019-03-01"
jsonpath "$.to" == "2019-03-31"
jsonpath "$.total" == 7
jsonpath "$.levels" count >= 3
jsonpath "$.levels[0]" == "SALMAN"
jsonpath "$.levels[1]" == "ABUZAR"
jsonpath "$.levels[2]" == "MIQDAD"
jsonpath "$.students" count == 7
jsonpath "$.students[0].rank" == 4
jsonpath "$.students[0].name" == "R2 Member 921021"
jsonpath "$.students[0].token" == 921021
jsonpath "$.students[0].class" == "R2-G-101"
jsonpath "$.students[0].recitation" == 500
jsonpath "$.students[1].rank" == 5
jsonpath "$.students[1].token" == 921026
jsonpath "$.students[1].class" == "R2-G-103"
jsonpath "$.students[1].recitation" == 400
jsonpath "$.students[?(@.token==921023)].rank" == 6
jsonpath "$.students[?(@.token==921023)].class" == "R2-G-101"
jsonpath "$.students[?(@.token==921022)].rank" count == 2
jsonpath "$.students[?(@.token==921022)].rank" nth 0 == 6
jsonpath "$.students[?(@.token==921022)].rank" nth 1 == 6
jsonpath "$.students[?(@.token==921022)].class" count == 2
jsonpath "$.students[?(@.token==921022)].recitation" nth 0 == 300
jsonpath "$.students[5].rank" == 8
jsonpath "$.students[5].token" == 921030
jsonpath "$.students[6].rank" == 9
jsonpath "$.students[6].token" == 921029
jsonpath "$.students[6].class" == "R2-L-104"
jsonpath "$.students[6].recitation" == 200

# 3. The gender lock wins over ?gender; the ladies administrator gets the ladies; the super administrator chooses
GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&gender=2
Authorization: {{auth_r2_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.total" == 7

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&gender=1
Authorization: {{auth_r2_ladmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.total" == 1
jsonpath "$.students" count == 1
jsonpath "$.students[0].rank" == 2
jsonpath "$.students[0].token" == 921025
jsonpath "$.students[0].class" == "R2-L-104"

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&gender=2
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.students" count == 1

# 4. Finding 3: the named grant without reports:read sees every class; the coordinator holding the grant only the assigned class
GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_named}}
HTTP 200
[Asserts]
jsonpath "$.total" == 7
jsonpath "$.students" count == 7

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&minimum=0
Authorization: {{auth_r2_grant}}
HTTP 200
[Asserts]
jsonpath "$.students" count == 4
jsonpath "$.students[0].token" == 921021
jsonpath "$.students[0].rank" == 4
jsonpath "$.students[?(@.token==921030)].rank" == 8
jsonpath "$.students[?(@.token==921028)].rank" == 10
jsonpath "$.students[?(@.token==921026)]" not exists

# 5. The level narrows the rows, not the ranks; trimmed, exact; unknown is 422
GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&level=ABUZAR
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 1
jsonpath "$.students[0].token" == 921022
jsonpath "$.students[0].rank" == 6
jsonpath "$.students[0].class" == "R2-G-102"

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&level=%20MIQDAD%20&minimum=300
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 3
jsonpath "$.students[0].token" == 921021

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&level=NOSUCH
Authorization: {{auth_r2_super}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Unknown level"

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&level=miqdad
Authorization: {{auth_r2_super}}
HTTP 422

# 6. The minimum: whole numbers from 0 up are kept; blank, negative, fractional, text and too large mean 1
GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&minimum=0
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 8
jsonpath "$.students[7].token" == 921028
jsonpath "$.students[7].rank" == 10
jsonpath "$.students[7].recitation" == 0

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&minimum=300
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 5

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&minimum=%20300%20
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 5

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&minimum=301
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 2

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&minimum=%2B5
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 7

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&minimum=007
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 7

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&minimum=-1
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 7

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&minimum=2.5
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 7

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&minimum=abc
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 7

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-31&minimum=99999999999999999999
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 7

# 7. The dates: the day itself counts (from and to are inclusive), a window with no mark, from after to, a real day, five years (1830 days) at most, from alone (to is today)
GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01&to=2019-03-01
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 1
jsonpath "$.students[0].rank" == 1
jsonpath "$.students[0].token" == 921026

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-31&to=2019-03-31
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.total" == 0
jsonpath "$.students" count == 0

GET {{base_url}}/reports/quran-leaderboard?to=2019-03-31
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.from" == "2018-03-31"
jsonpath "$.students[0].rank" == 1
jsonpath "$.students[0].token" == 921029

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-31&to=2019-03-01
Authorization: {{auth_r2_super}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be dates as YYYY-MM-DD, from not after to"

GET {{base_url}}/reports/quran-leaderboard?from=2019-02-30&to=2019-03-31
Authorization: {{auth_r2_super}}
HTTP 422

GET {{base_url}}/reports/quran-leaderboard?from=2014-03-01&to=2019-03-31
Authorization: {{auth_r2_super}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The range can cover at most five years"

GET {{base_url}}/reports/quran-leaderboard?from=2019-03-01
Authorization: {{auth_r2_super}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The range can cover at most five years"

# 8. With no dates at all the answer is the last year: its figures change with the day, so only its shape is asserted
GET {{base_url}}/reports/quran-leaderboard
Authorization: {{auth_r2_super}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.from" isString
jsonpath "$.to" isString
jsonpath "$.levels" isCollection
jsonpath "$.total" isInteger
jsonpath "$.students" isCollection
