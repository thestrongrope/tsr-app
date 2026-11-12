# GET /reports/mcq-summary/{class_id}?gender&from&to contract: one class's students as the web page's table. Runs against any implementation.
# Variables: base_url and auth_r2_<alias>. REPORTS2 fixtures (see report-mcq-summary.hurl), the range 2019-03-01 to 2019-03-31. Class 98101 has 7 quizzes in the range (topics "R2 Topic A" twice with a case difference, B, C, one quiz with no topic,
# one deactivated, one with no questions) and seven live students with distinct scores 6 5 4 3 2 1 0 (a removed one, one with status I but not removed, one enrolled twice, one re-enrolled after leaving).
# PHP quirk copied: the per-student figure of "R2 Topic A" depends on which spelling MariaDB (and here PostgreSQL) keeps for a group of case-differing topics, so it is NOT asserted; the maximum is.
# PHP quirk copied: {class_id} is cast as (int): 0 or a word narrows nothing, so the answer is the FIRST class of the whole report INSIDE the caller's reach (98107 for r2_coord, 98101 for r2_one; never 98103, which is first in class order).

# 1. Sign-in, permission, the date checks come after the permission
GET {{base_url}}/reports/mcq-summary/98101?from=2019-03-01&to=2019-03-31
HTTP 401

GET {{base_url}}/reports/mcq-summary/98101?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_nobody}}
HTTP 403

GET {{base_url}}/reports/mcq-summary/98101?from=2019-03-02&to=2019-03-01
Authorization: {{auth_r2_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be dates as YYYY-MM-DD, from not after to"

# 2. The class: the quiz count, the maximum marks (A 6, B 2, C 1; D has no questions so no line), the students best first
GET {{base_url}}/reports/mcq-summary/98101?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.mcqs" == 7
jsonpath "$.maxMarks" == 9
jsonpath "$.students" count == 7
jsonpath "$.students[0].name" == "R2 Member 921021"
jsonpath "$.students[0].attempted" == 5
jsonpath "$.students[0].pending" == 2
jsonpath "$.students[0].correct" == 6
jsonpath "$.students[0].percent" == 67
jsonpath "$.students[0].topics" count == 3
jsonpath "$.students[0].topics[0].topic" == "R2 Topic A"
jsonpath "$.students[0].topics[0].max" == 6
jsonpath "$.students[0].topics[1].topic" == "R2 Topic B"
jsonpath "$.students[0].topics[1].max" == 2
jsonpath "$.students[0].topics[1].correct" == 1
jsonpath "$.students[0].topics[2].topic" == "R2 Topic C"
jsonpath "$.students[0].topics[2].max" == 1
jsonpath "$.students[0].topics[2].correct" == null
jsonpath "$.students[1].name" == "R2 Member 921034"
jsonpath "$.students[1].attempted" == 4
jsonpath "$.students[1].correct" == 5
jsonpath "$.students[1].percent" == 56
jsonpath "$.students[1].topics[1].correct" == 1
jsonpath "$.students[2].name" == "R2 Member 921032"
jsonpath "$.students[2].attempted" == 2
jsonpath "$.students[2].pending" == 5
jsonpath "$.students[2].correct" == 4
jsonpath "$.students[2].percent" == 44
jsonpath "$.students[3].name" == "R2 Member 921031"
jsonpath "$.students[3].attempted" == 2
jsonpath "$.students[3].correct" == 3
jsonpath "$.students[3].percent" == 33
jsonpath "$.students[4].name" == "R2 Member 921023"
jsonpath "$.students[4].correct" == 2
jsonpath "$.students[4].percent" == 22
jsonpath "$.students[4].topics[1].correct" == 2
jsonpath "$.students[5].name" == "R2 Member 921033"
jsonpath "$.students[5].correct" == 1
jsonpath "$.students[5].percent" == 11
jsonpath "$.students[5].topics[2].correct" == 1
jsonpath "$.students[5].topics[1].correct" == null
jsonpath "$.students[6].name" == "R2 Member 921028"
jsonpath "$.students[6].attempted" == 0
jsonpath "$.students[6].pending" == 7
jsonpath "$.students[6].correct" == 0
jsonpath "$.students[6].percent" == null
jsonpath "$.students[6].topics[0].correct" == null

# 3. A class with a quiz but only a removed student, a class with no quiz in the range, one of the other gender, one outside reach, the closed class, unknown, negative: the empty class, never 404
GET {{base_url}}/reports/mcq-summary/98107?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.mcqs" == 1
jsonpath "$.maxMarks" == 2
jsonpath "$.students" count == 0

GET {{base_url}}/reports/mcq-summary/98102?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.mcqs" == 0
jsonpath "$.maxMarks" == 0
jsonpath "$.students" count == 0

GET {{base_url}}/reports/mcq-summary/98104?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.mcqs" == 0
jsonpath "$.students" count == 0

GET {{base_url}}/reports/mcq-summary/98104?from=2019-03-01&to=2019-03-31&gender=2
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.mcqs" == 1
jsonpath "$.maxMarks" == 2
jsonpath "$.students" count == 2
jsonpath "$.students[0].name" == "R2 Member 921025"
jsonpath "$.students[0].percent" == 100
jsonpath "$.students[1].name" == "R2 Member 921029"
jsonpath "$.students[1].percent" == null

GET {{base_url}}/reports/mcq-summary/98103?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.mcqs" == 0
jsonpath "$.students" count == 0

GET {{base_url}}/reports/mcq-summary/98101?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_one}}
HTTP 200
[Asserts]
jsonpath "$.mcqs" == 7

GET {{base_url}}/reports/mcq-summary/98107?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_one}}
HTTP 200
[Asserts]
jsonpath "$.mcqs" == 0

GET {{base_url}}/reports/mcq-summary/98105?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.mcqs" == 0

GET {{base_url}}/reports/mcq-summary/99999999?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.mcqs" == 0

GET {{base_url}}/reports/mcq-summary/-1?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.mcqs" == 0

GET {{base_url}}/reports/mcq-summary/99999999999999999999?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.mcqs" == 0

# 4. The (int) cast: "5abc" is class 5 (nothing), "0" and "abc" narrow nothing: the first class of the report inside reach
GET {{base_url}}/reports/mcq-summary/5abc?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.mcqs" == 0

GET {{base_url}}/reports/mcq-summary/0?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.mcqs" == 1
jsonpath "$.maxMarks" == 2

GET {{base_url}}/reports/mcq-summary/abc?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.mcqs" == 1
jsonpath "$.maxMarks" == 2

GET {{base_url}}/reports/mcq-summary/0?from=2019-03-01&to=2019-03-31
Authorization: {{auth_r2_one}}
HTTP 200
[Asserts]
jsonpath "$.mcqs" == 7
jsonpath "$.students[0].name" == "R2 Member 921021"
