# POST /reports/pending/nudge, the cases only the new API runs: every REAL SEND (PHP sends a real push in this route, so the parity side never runs one) and the deviations from PHP. On the new API a send is RECORDED and QUEUED, never delivered
# (the push queue has no drain yet): a notification, the teacher's inbox row, one queued push per device and one outbox event. The rows are counted by db/tests/TestReports2Tests.cs; here only the answers.
# Variables: base_url and auth_r2_<alias>. REPORTS2 fixtures (see report-mcq-summary.hurl; the fixtures reset the nudge rows before each run). This file sends only to 921012 (one device) and 921013 (no device), which the dry-run file
# (report-pending-nudge.hurl, run in parallel) never asserts "already reminded" for; 921011 is only ever dry-run here.

# 1. A send: 200, sent true, the devices queued for, the time of the record; the same teacher again is 429; a dry run then says so
POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_gadmin}}
{"teacher": 921012, "from": "03-2019", "to": "03-2019", "send": true}
HTTP 200
[Asserts]
jsonpath "$.teacherToken" == 921012
jsonpath "$.teacher" == "R2 Member 921012"
jsonpath "$.title" == "Pending C Form Reminder"
jsonpath "$.body" == "Salaamun Alaikum\n\nClass Number: R2-G-103\nPending MCQ(s): 1\n\nTSR CC Team"
jsonpath "$.alreadyReminded" == false
jsonpath "$.lastReminded" matches /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$/
jsonpath "$.sent" == true
jsonpath "$.deviceCount" == 1

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_gadmin}}
{"teacher": 921012, "from": "03-2019", "to": "03-2019", "send": true}
HTTP 429
[Asserts]
jsonpath "$.detail" == "This teacher was already reminded in the last 24 hours"

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_super}}
{"teacher": 921012, "from": "03-2019", "to": "03-2019", "send": true}
HTTP 429

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_gadmin}}
{"teacher": 921012, "from": "03-2019", "to": "03-2019"}
HTTP 200
[Asserts]
jsonpath "$.alreadyReminded" == true
jsonpath "$.lastReminded" matches /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$/
jsonpath "$.sent" == false
jsonpath "$.deviceCount" == 0

# 2. A teacher with no device is recorded with 0 devices (a ladies teacher: the gender asked for decides)
POST {{base_url}}/reports/pending/nudge?gender=2
Authorization: {{auth_r2_ladmin}}
{"teacher": 921013, "from": "03-2019", "to": "03-2019", "send": true}
HTTP 200
[Asserts]
jsonpath "$.sent" == true
jsonpath "$.deviceCount" == 0

POST {{base_url}}/reports/pending/nudge?gender=2
Authorization: {{auth_r2_ladmin}}
{"teacher": 921013, "from": "03-2019", "to": "03-2019", "send": true}
HTTP 429

# 3. Refusals never write: a send for a teacher outside the caller's reach or of the other gender is the same 422 as a dry run, a missing teacher is 422, an unsigned send is 401, a send without reports:read is 403
POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_one}}
{"teacher": 921012, "from": "03-2019", "to": "03-2019", "send": true}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Nothing is pending for this teacher"

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921013, "from": "03-2019", "to": "03-2019", "send": true}
HTTP 422

POST {{base_url}}/reports/pending/nudge
{"teacher": 921012, "send": true}
HTTP 401

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_nobody}}
{"teacher": 921012, "send": true}
HTTP 403

# the teacher the refusals aimed at was never recorded as reminded
POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921011, "from": "03-2019", "to": "03-2019", "send": "true"}
HTTP 200
[Asserts]
jsonpath "$.alreadyReminded" == false
jsonpath "$.sent" == false

# 4. send is true only as the JSON value true: the text "true", 1 and null are dry runs
POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921011, "from": "03-2019", "to": "03-2019", "send": 1}
HTTP 200
[Asserts]
jsonpath "$.sent" == false

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921011, "from": "03-2019", "to": "03-2019", "send": null}
HTTP 200
[Asserts]
jsonpath "$.sent" == false

# 5. Deviation from PHP (design point 6): the months may span at most 12 (PHP's nudge has no limit; its pending report has). Twelve months pass, thirteen do not; with no "to" the range runs to this month
POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921011, "from": "03-2019", "to": "02-2020"}
HTTP 200

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921011, "from": "03-2019", "to": "03-2020"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The range can cover at most 12 months"

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921011, "from": "03-2019"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The range can cover at most 12 months"

# 6. NUL bytes and absurd values are never a 500 (PHP prints an HTML warning for an array month)
POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921011, "from": "03-2019\u0000", "to": "03-2019"}
HTTP 422

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921011, "from": ["03-2019"], "to": "03-2019"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be months as MM-YYYY, from not after to"

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921011, "from": {"a": 1}, "to": "03-2019"}
HTTP 422

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 1e400}
HTTP 422
