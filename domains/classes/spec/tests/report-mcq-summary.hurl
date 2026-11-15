# GET /reports/mcq-summary contract: a line per class that published MCQs in the period (default the last 30 days; days YYYY-MM-DD, midnight of from to midnight of to, at most 366 days). Runs against any implementation.
# Variables: base_url and auth_r2_<alias>. REPORTS2 fixtures (db/synthetic/reports2-fixtures.sql): March 2019. r2_coord reaches the gents classes 98101 (MIQDAD, 7 quizzes in the range, 7 live students), 98102, 98106, 98107 (ABUZAR,
# one quiz, only a removed student) and the ladies class 98104 (one quiz, two students) and NOT 98103 (SALMAN, first in class order) or the closed 98105; r2_one reaches 98101 only. PHP walks every class of the gender with three queries
# each, so the administrators' lists (which cover the whole parity database) are in report-mcq-summary-new-api.hurl.

# 1. Sign-in (401), reports:read (403: a plain member and a holder of only the leaderboard grant), the order of checks
GET {{base_url}}/reports/mcq-summary?from=2019-03-01&to=2019-03-31
HTTP 401

GET {{base_url}}/reports/mcq-summary?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_nobody}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/reports/mcq-summary?from=bad
Authorization: {{auth_r2_named}}
HTTP 403

# 2. The coordinator: the classes in reach with a quiz in the range, ABUZAR before MIQDAD (level order); 98103 and 98105 never
GET {{base_url}}/reports/mcq-summary?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.from" == "2019-03-01"
jsonpath "$.to" == "2019-03-31"
jsonpath "$.levels" count == 2
jsonpath "$.levels[0]" == "ABUZAR"
jsonpath "$.levels[1]" == "MIQDAD"
jsonpath "$.classes" count == 2
jsonpath "$.classes[0].classId" == 98107
jsonpath "$.classes[0].class" == "R2-G-107"
jsonpath "$.classes[0].level" == "ABUZAR"
jsonpath "$.classes[0].teacher" == "R2 Member 921011"
jsonpath "$.classes[0].mcqs" == 1
jsonpath "$.classes[0].students" == 0
jsonpath "$.classes[1].classId" == 98101
jsonpath "$.classes[1].mcqs" == 7
jsonpath "$.classes[1].students" == 7

# 3. One coordinator limited to one class; a coordinator whose classes are all gents is locked to gents whatever gender is asked; one with both genders chooses
GET {{base_url}}/reports/mcq-summary?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_one}}
HTTP 200
[Asserts]
jsonpath "$.classes" count == 1
jsonpath "$.classes[0].classId" == 98101

GET {{base_url}}/reports/mcq-summary?from=2019-03-01&to=2019-03-31&gender=2
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.classes" count == 1
jsonpath "$.classes[0].classId" == 98104
jsonpath "$.classes[0].mcqs" == 1
jsonpath "$.classes[0].students" == 2

GET {{base_url}}/reports/mcq-summary?from=2019-03-01&to=2019-03-31&gender=2
Authorization: {{auth_r2_one}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.classes" count == 1
jsonpath "$.classes[0].classId" == 98101

# 4. The range: midnight of to counts (the 00:00 quiz of 31 March), 23:59 of that day does not; midnight of from counts, the day before does not
GET {{base_url}}/reports/mcq-summary?from=2019-03-01&to=2019-03-30
Authorization: {{auth_r2_one}}
HTTP 200
[Asserts]
jsonpath "$.classes[0].mcqs" == 6

GET {{base_url}}/reports/mcq-summary?from=2019-03-02&to=2019-03-31
Authorization: {{auth_r2_one}}
HTTP 200
[Asserts]
jsonpath "$.classes[0].mcqs" == 6

GET {{base_url}}/reports/mcq-summary?from=2019-02-28&to=2019-03-01
Authorization: {{auth_r2_one}}
HTTP 200
[Asserts]
jsonpath "$.classes[0].mcqs" == 2

GET {{base_url}}/reports/mcq-summary?from=2019-04-01&to=2019-04-30
Authorization: {{auth_r2_one}}
HTTP 200
[Asserts]
jsonpath "$.classes" count == 0
jsonpath "$.levels" count == 0

# 5. Dates: only to (from is 30 days before), from not after to, real days, 366 days at most, a trailing newline (PHP's regex `$` lets one through; copied, and echoed in `to`)
GET {{base_url}}/reports/mcq-summary?to=2019-03-31
Authorization: {{auth_r2_one}}
HTTP 200
[Asserts]
jsonpath "$.from" == "2019-03-01"
jsonpath "$.classes[0].mcqs" == 7

GET {{base_url}}/reports/mcq-summary?from=2019-03-02&to=2019-03-01
Authorization: {{auth_r2_one}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be dates as YYYY-MM-DD, from not after to"

GET {{base_url}}/reports/mcq-summary?from=2019-02-30&to=2019-03-31
Authorization: {{auth_r2_one}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be dates as YYYY-MM-DD, from not after to"

GET {{base_url}}/reports/mcq-summary?from=2019-03-01&to=2019-03-31%0A
Authorization: {{auth_r2_one}}
HTTP 200
[Asserts]
jsonpath "$.to" == "2019-03-31\n"

GET {{base_url}}/reports/mcq-summary?from=2019-03-01
Authorization: {{auth_r2_one}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The range can cover at most a year"

GET {{base_url}}/reports/mcq-summary?from=2019-03-01&to=2020-03-01
Authorization: {{auth_r2_one}}
HTTP 200

GET {{base_url}}/reports/mcq-summary?from=2019-03-01&to=2020-03-02
Authorization: {{auth_r2_one}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The range can cover at most a year"

# 6. A gender other than "2" is gents
GET {{base_url}}/reports/mcq-summary?from=2019-03-01&to=2019-03-31&gender=abc
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
