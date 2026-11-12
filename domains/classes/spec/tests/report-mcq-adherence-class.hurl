# GET /reports/mcq-adherence/{class_id}?gender contract: one class's standard MCQs and whether each was conducted, pending (copied, not conducted) or skipped. Runs against any implementation.
# Variables: base_url and auth_r2_<alias>. REPORTS2 fixtures (see report-mcq-adherence.hurl). The MCQs come in PHP's order: topic, subject, sort order (none first), lesson, name.
# PHP quirk copied: {class_id} is cast as (int): 0 or a word narrows nothing, so the answer is the WORST class of the whole report INSIDE the caller's reach (98107 for r2_coord; never 98103, which has the worst adherence of all).
# A class out of reach, of the other gender, closed, unknown, or with no standard MCQ is the empty class (floats 0.0), never 404.

# 1. Sign-in, permission
GET {{base_url}}/reports/mcq-adherence/98101
HTTP 401

GET {{base_url}}/reports/mcq-adherence/98101
Authorization: {{auth_r2_nobody}}
HTTP 403

# 2. A class with the three statuses: M2 has no sort order and sorts first within its subject; the duplicate copies of M1 collapse (conducted by the published one)
GET {{base_url}}/reports/mcq-adherence/98101
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.expected" == 3
jsonpath "$.conducted" == 1
jsonpath "$.pending" == 1
jsonpath "$.skipped" == 1
jsonpath "$.adherencePercent" == 33.3
jsonpath "$.mcqs" count == 3
jsonpath "$.mcqs[0].topic" == "R2 Topic"
jsonpath "$.mcqs[0].subject" == "R2 Subject A"
jsonpath "$.mcqs[0].lesson" == "R2 lesson 2"
jsonpath "$.mcqs[0].name" == "R2 MCQ two"
jsonpath "$.mcqs[0].status" == "pending"
jsonpath "$.mcqs[1].name" == "R2 MCQ three"
jsonpath "$.mcqs[1].status" == "skipped"
jsonpath "$.mcqs[2].subject" == "R2 Subject B"
jsonpath "$.mcqs[2].name" == "R2 MCQ one"
jsonpath "$.mcqs[2].status" == "conducted"

GET {{base_url}}/reports/mcq-adherence/98106
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.conducted" == 3
jsonpath "$.adherencePercent" == 100.0
body contains "\"adherencePercent\":100.0,"

GET {{base_url}}/reports/mcq-adherence/98104?gender=2
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.adherencePercent" == 66.7
jsonpath "$.mcqs[1].status" == "pending"
jsonpath "$.mcqs[2].status" == "conducted"

GET {{base_url}}/reports/mcq-adherence/98102
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.adherencePercent" == 50.0
body contains "\"adherencePercent\":50.0,"

# 3. The empty class: outside reach (98103), the other gender (98104 asked as gents), closed (98105), unknown, negative, huge
GET {{base_url}}/reports/mcq-adherence/98103
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
body == "{\"expected\":0,\"conducted\":0,\"pending\":0,\"skipped\":0,\"adherencePercent\":0.0,\"mcqs\":[]}"

GET {{base_url}}/reports/mcq-adherence/98104
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.expected" == 0

GET {{base_url}}/reports/mcq-adherence/98105
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.expected" == 0

GET {{base_url}}/reports/mcq-adherence/98101
Authorization: {{auth_r2_one}}
HTTP 200
[Asserts]
jsonpath "$.expected" == 3

GET {{base_url}}/reports/mcq-adherence/98102
Authorization: {{auth_r2_one}}
HTTP 200
[Asserts]
jsonpath "$.expected" == 0

GET {{base_url}}/reports/mcq-adherence/99999999
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.expected" == 0

GET {{base_url}}/reports/mcq-adherence/-1
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.expected" == 0

GET {{base_url}}/reports/mcq-adherence/99999999999999999999
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.expected" == 0

# 4. The (int) cast: "5abc" is class 5 (nothing); "0" and "abc" give the worst class inside reach
GET {{base_url}}/reports/mcq-adherence/5abc
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.expected" == 0

GET {{base_url}}/reports/mcq-adherence/0
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.expected" == 2
jsonpath "$.skipped" == 2
jsonpath "$.mcqs[0].name" == "R2 MCQ five"

GET {{base_url}}/reports/mcq-adherence/abc
Authorization: {{auth_r2_coord}}
HTTP 200
[Asserts]
jsonpath "$.mcqs[0].name" == "R2 MCQ five"

GET {{base_url}}/reports/mcq-adherence/0
Authorization: {{auth_r2_one}}
HTTP 200
[Asserts]
jsonpath "$.expected" == 3
jsonpath "$.mcqs[0].name" == "R2 MCQ two"
