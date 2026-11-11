# GET /reports/this-week/class/{class_id} contract: what one class taught in each of the last 8 weeks, newest first, and the chart of its level. Runs against any implementation.
# Variables: base_url and auth_<alias>. B5B fixtures (see report-this-week.hurl; sessions are dated relative to the load time). 9591 (MIQDAD): W0 has two held sessions, W1 and W0 without arabic. 9592 (ABUZAR): not held in W1 and W0.
# 9593 (SALMAN): no form in W2 to W0.

# 1. Without sign-in: 401; without reports:read: 403
GET {{base_url}}/reports/this-week/class/9591
HTTP 401

GET {{base_url}}/reports/this-week/class/9591
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. The coordinator: eight weeks, the newest first; topics are joined with "; ", a subject taught with no topic reads "Conducted"; the level has a chart
GET {{base_url}}/reports/this-week/class/9591
Authorization: {{auth_rb_coord}}
HTTP 200
[Asserts]
jsonpath "$.classId" == 9591
jsonpath "$.code" == "RB-G-591"
jsonpath "$.level" == "MIQDAD"
jsonpath "$.weeks" count == 8
jsonpath "$.weeks[0].from" matches /^\d{4}-\d{2}-\d{2}$/
jsonpath "$.weeks[0].status" == "taught"
jsonpath "$.weeks[0].subjects.aqaed" == "B5b Tawhid; B5b Tawhid Two"
jsonpath "$.weeks[0].subjects.ahkam" == "B5b Wudu; Conducted"
jsonpath "$.weeks[0].subjects.akhlaq" == "Conducted; B5b Honesty"
jsonpath "$.weeks[0].subjects.arabic" not exists
jsonpath "$.weeks[1].subjects.aqaed" == "Conducted"
jsonpath "$.weeks[1].subjects.arabic" not exists
jsonpath "$.weeks[2].subjects.arabic" == "Conducted"
jsonpath "$.weeks[2].subjects.other" not exists
jsonpath "$.weeks[7].status" == "taught"
jsonpath "$.chart" exists
jsonpath "$.chart.arabic" exists

# 3. Not held, no form, and a level with no chart
GET {{base_url}}/reports/this-week/class/9592
Authorization: {{auth_rb_coord}}
HTTP 200
[Asserts]
jsonpath "$.level" == "ABUZAR"
jsonpath "$.weeks[0].status" == "no class"
jsonpath "$.weeks[1].status" == "no class"
jsonpath "$.weeks[0].subjects.arabic" not exists
jsonpath "$.weeks[2].status" == "taught"
jsonpath "$.chart" == null

GET {{base_url}}/reports/this-week/class/9593
Authorization: {{auth_rb_coord}}
HTTP 200
[Asserts]
jsonpath "$.weeks[0].status" == "no form"
jsonpath "$.weeks[2].status" == "no form"
jsonpath "$.weeks[3].status" == "taught"
jsonpath "$.chart" == null

# 4. Out of reach, closed, missing, not a number: the same 404
GET {{base_url}}/reports/this-week/class/9595
Authorization: {{auth_rb_coord}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/reports/this-week/class/9596
Authorization: {{auth_admin}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/reports/this-week/class/999999999
Authorization: {{auth_admin}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/reports/this-week/class/abc
Authorization: {{auth_admin}}
HTTP 404

# 5. Reach is by the class's own gender: the ladies administrator sees the ladies class, the gents administrator does not
GET {{base_url}}/reports/this-week/class/9595
Authorization: {{auth_en_ladmin}}
HTTP 200
[Asserts]
jsonpath "$.classId" == 9595
jsonpath "$.weeks[0].status" == "taught"

GET {{base_url}}/reports/this-week/class/9595
Authorization: {{auth_en_gadmin}}
HTTP 404

GET {{base_url}}/reports/this-week/class/9591
Authorization: {{auth_en_ladmin}}
HTTP 404
