# GET /reports/weekly contract: every class the caller reaches with, for each Sunday-to-Saturday week of the months, held (how many times), not held or not filled. Runs against any implementation.
# Variables: base_url and auth_<alias>. B5A fixtures (see report-conduction.hurl), month 11-2025 (weeks from 26 Oct to 6 Dec). 9581: 3 Nov not held, 10 and 13 Nov held (two in week 3), 17 and 24 Nov held; 9582: 11 Nov held.

# 1. Without sign-in: 401; without reports:read: 403
GET {{base_url}}/reports/weekly?from=11-2025&to=11-2025
HTTP 401

GET {{base_url}}/reports/weekly?from=11-2025&to=11-2025
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 2. The coordinator: its two classes, the six weeks, the cell of each week
GET {{base_url}}/reports/weekly?from=11-2025&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.from" == "11-2025"
jsonpath "$.to" == "11-2025"
jsonpath "$.levels" count == 2
jsonpath "$.levels[0]" == "ABUZAR"
jsonpath "$.levels[1]" == "MIQDAD"
jsonpath "$.weeks" count == 6
jsonpath "$.weeks[0].month" == "Nov-2025"
jsonpath "$.weeks[0].label" == "Wk 1"
jsonpath "$.weeks[0].from" == "2025-10-26"
jsonpath "$.weeks[0].to" == "2025-11-01"
jsonpath "$.weeks[5].label" == "Wk 6"
jsonpath "$.weeks[5].from" == "2025-11-30"
jsonpath "$.weeks[5].to" == "2025-12-06"
jsonpath "$.classes" count == 2
jsonpath "$.classes[0].classId" == 9582
jsonpath "$.classes[0].level" == "ABUZAR"
jsonpath "$.classes[0].class" == "RP-G-582"
jsonpath "$.classes[0].teacher" == "Rp Member 901413"
jsonpath "$.classes[0].weeks" count == 6
jsonpath "$.classes[0].weeks[0].status" == "notFilled"
jsonpath "$.classes[0].weeks[0].sessions" == 0
jsonpath "$.classes[0].weeks[2].status" == "held"
jsonpath "$.classes[0].weeks[2].sessions" == 1
jsonpath "$.classes[1].classId" == 9581
jsonpath "$.classes[1].class" == "RP-G-581"
jsonpath "$.classes[1].teacher" == "Rp Member 901411"
jsonpath "$.classes[1].weeks[0].status" == "notFilled"
jsonpath "$.classes[1].weeks[1].status" == "notHeld"
jsonpath "$.classes[1].weeks[1].sessions" == 0
jsonpath "$.classes[1].weeks[2].status" == "held"
jsonpath "$.classes[1].weeks[2].sessions" == 2
jsonpath "$.classes[1].weeks[3].status" == "held"
jsonpath "$.classes[1].weeks[3].sessions" == 1
jsonpath "$.classes[1].weeks[4].status" == "held"
jsonpath "$.classes[1].weeks[5].status" == "notFilled"

# 3. "to" defaults to "from"; the level narrows the classes, not the levels
GET {{base_url}}/reports/weekly?from=11-2025&level=MIQDAD
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.to" == "11-2025"
jsonpath "$.levels" count == 2
jsonpath "$.classes" count == 1
jsonpath "$.classes[0].classId" == 9581

# 4. Two months: the weeks of both, the second month's weeks labelled by their first day
GET {{base_url}}/reports/weekly?from=10-2025&to=11-2025&gender=2
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.weeks" count == 10
jsonpath "$.weeks[0].month" == "Oct-2025"
jsonpath "$.weeks[0].from" == "2025-09-28"
jsonpath "$.weeks[4].month" == "Oct-2025"
jsonpath "$.weeks[5].month" == "Nov-2025"
jsonpath "$.weeks[5].label" == "Wk 1"
jsonpath "$.weeks[9].to" == "2025-12-06"
jsonpath "$.classes[1].weeks" count == 10

# 5. Gender: the ladies administrator is held to ladies, the gents administrator to gents
GET {{base_url}}/reports/weekly?from=11-2025&to=11-2025&gender=1
Authorization: {{auth_en_ladmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.classes[?(@.classId==9583)].weeks[2].status" == "held"
jsonpath "$.classes[?(@.classId==9581)]" not exists

GET {{base_url}}/reports/weekly?from=11-2025&to=11-2025&gender=2
Authorization: {{auth_en_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.classes[?(@.classId==9581)].class" == "RP-G-581"
jsonpath "$.classes[?(@.classId==9583)]" not exists

# 6. The super administrator: gents by default, ladies for the text 2; the other city's class is listed, never the closed class or the demo class
GET {{base_url}}/reports/weekly?from=11-2025&to=11-2025
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.classes[?(@.classId==9581)].class" == "RP-G-581"
jsonpath "$.classes[?(@.classId==9584)].class" == "RP-G-584"
jsonpath "$.classes[?(@.classId==9585)]" not exists
jsonpath "$.classes[?(@.classId==9586)]" not exists
jsonpath "$.classes[?(@.class=='AYD1')]" not exists

GET {{base_url}}/reports/weekly?from=11-2025&to=11-2025&gender=2
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.classes[?(@.classId==9583)].class" == "RP-L-583"

# 7. No months: this month (the answer names it); the shape is the same
GET {{base_url}}/reports/weekly
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.from" matches /^(0[1-9]|1[0-2])-20\d\d$/
jsonpath "$.to" matches /^(0[1-9]|1[0-2])-20\d\d$/
jsonpath "$.classes" count == 2

# 8. Months wrong: 422 (from after to, not a month, a trailing month, 13 months)
GET {{base_url}}/reports/weekly?from=12-2025&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "from and to must be months as MM-YYYY, from not after to"

GET {{base_url}}/reports/weekly?from=2025-11
Authorization: {{auth_rp_coord}}
HTTP 422

GET {{base_url}}/reports/weekly?from=13-2025&to=13-2025
Authorization: {{auth_rp_coord}}
HTTP 422

GET {{base_url}}/reports/weekly?from=11-2024&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The range can cover at most 12 months"

GET {{base_url}}/reports/weekly?from=12-2024&to=11-2025
Authorization: {{auth_rp_coord}}
HTTP 200
