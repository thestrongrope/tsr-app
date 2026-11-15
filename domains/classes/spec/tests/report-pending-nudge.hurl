# POST /reports/pending/nudge {teacher, from?, to?, send?} contract: the DRY RUN (send absent or not exactly true) and the refusals. Runs against any implementation. PHP SENDS a real push on send:true, so every send is in
# report-pending-nudge-new-api.hurl (new API only, where a send is recorded and queued, never delivered); nothing here sends.
# Variables: base_url and auth_r2_<alias>. REPORTS2 fixtures (see report-mcq-summary.hurl), the months fixed to 03-2019. Pending is the standard MCQs copied but not conducted (no class has a schedule in the months, so no form is missing):
# teacher 921011 has one in 98101 and one in 98102; 921012 one in 98103 (outside r2_coord's reach); 921013 (a LADIES member) one in 98104; 98106's teacher (921099) has no member row and nothing pending.
# The order of checks, as PHP: sign-in, reports:read for the gender (403), teacher a JSON integer above 0, months, then the teacher must be in the caller's own pending report. A teacher outside the reach, of the other gender or with nothing
# pending all get the same 422.

# 1. Sign-in, permission, the permission before the body
POST {{base_url}}/reports/pending/nudge
{"teacher": 921011, "from": "03-2019", "to": "03-2019"}
HTTP 401

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_nobody}}
{"teacher": 921011, "from": "03-2019", "to": "03-2019"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_named}}
{"teacher": "bad"}
HTTP 403

# 2. The body: the teacher must be a JSON integer above 0
POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "teacher must be a member token"

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 0}
HTTP 422
[Asserts]
jsonpath "$.detail" == "teacher must be a member token"

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": -5}
HTTP 422

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": "921011"}
HTTP 422

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921011.0}
HTTP 422

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921011.5}
HTTP 422

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": [921011]}
HTTP 422

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": null}
HTTP 422

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": true}
HTTP 422

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 99999999999999999999}
HTTP 422
[Asserts]
jsonpath "$.detail" == "teacher must be a member token"

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 9223372036854775807, "from": "03-2019", "to": "03-2019"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Nothing is pending for this teacher"

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
[1, 2]
HTTP 422
[Asserts]
jsonpath "$.detail" == "teacher must be a member token"

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
```
not json
```
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

# 3. The months: MM-YYYY, from not after to, a month 01 to 12
POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921011, "from": "04-2019", "to": "03-2019"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be months as MM-YYYY, from not after to"

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921011, "from": "13-2019", "to": "03-2019"}
HTTP 422

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921011, "from": "00-2019", "to": "03-2019"}
HTTP 422

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921011, "from": 3, "to": "03-2019"}
HTTP 422

# 4. A dry run: the figures recomputed from the caller's own reach, the fixed message, nothing sent, nothing recorded
POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921011, "from": "03-2019", "to": "03-2019"}
HTTP 200
[Asserts]
jsonpath "$.teacherToken" == 921011
jsonpath "$.teacher" == "R2 Member 921011"
jsonpath "$.title" == "Pending C Form Reminder"
jsonpath "$.body" == "Salaamun Alaikum\n\nClass Number: R2-G-102\nPending MCQ(s): 1\n\nClass Number: R2-G-101\nPending MCQ(s): 1\n\nTSR CC Team"
jsonpath "$.alreadyReminded" == false
jsonpath "$.lastReminded" == null
jsonpath "$.sent" == false
jsonpath "$.deviceCount" == 0

# send is a dry run unless it is exactly false or absent here (the true cases are in the new-API file); an explicit false
POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921011, "from": "03-2019", "to": "03-2019", "send": false}
HTTP 200
[Asserts]
jsonpath "$.sent" == false

# 5. The coordinator limited to 98101 gets a message about that class only (the scope of the report is the caller's)
POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_one}}
{"teacher": 921011, "from": "03-2019", "to": "03-2019"}
HTTP 200
[Asserts]
jsonpath "$.body" == "Salaamun Alaikum\n\nClass Number: R2-G-101\nPending MCQ(s): 1\n\nTSR CC Team"

# 6. Outside the reach, the other gender, nothing pending, not a teacher: the same 422 for all, so nothing says whether the teacher exists
POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921012, "from": "03-2019", "to": "03-2019"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Nothing is pending for this teacher"

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_one}}
{"teacher": 921013, "from": "03-2019", "to": "03-2019"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Nothing is pending for this teacher"

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921013, "from": "03-2019", "to": "03-2019"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Nothing is pending for this teacher"

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921099, "from": "03-2019", "to": "03-2019"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Nothing is pending for this teacher"

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_coord}}
{"teacher": 921021, "from": "03-2019", "to": "03-2019"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Nothing is pending for this teacher"

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_gadmin}}
{"teacher": 921013, "from": "03-2019", "to": "03-2019"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Nothing is pending for this teacher"

# 7. The administrators reach more: the gents administrator reaches 921012; the gender asked for decides for the coordinator of both genders and the super administrator
POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_gadmin}}
{"teacher": 921012, "from": "03-2019", "to": "03-2019"}
HTTP 200
[Asserts]
jsonpath "$.teacher" == "R2 Member 921012"
jsonpath "$.body" == "Salaamun Alaikum\n\nClass Number: R2-G-103\nPending MCQ(s): 1\n\nTSR CC Team"

POST {{base_url}}/reports/pending/nudge?gender=2
Authorization: {{auth_r2_coord}}
{"teacher": 921013, "from": "03-2019", "to": "03-2019"}
HTTP 200
[Asserts]
jsonpath "$.teacher" == "R2 Member 921013"
jsonpath "$.body" == "Salaamun Alaikum\n\nClass Number: R2-L-104\nPending MCQ(s): 1\n\nTSR CC Team"
jsonpath "$.deviceCount" == 0

POST {{base_url}}/reports/pending/nudge?gender=2
Authorization: {{auth_r2_super}}
{"teacher": 921013, "from": "03-2019", "to": "03-2019"}
HTTP 200

POST {{base_url}}/reports/pending/nudge
Authorization: {{auth_r2_super}}
{"teacher": 921013, "from": "03-2019", "to": "03-2019"}
HTTP 422
