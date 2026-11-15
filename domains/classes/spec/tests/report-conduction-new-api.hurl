# GET /reports/conduction on the new API only: a week that has not happened yet, and weeks the calendar has no day for. PHP answers 200 with warnings and a fatal error in the body (it reads a window that starts after it ends as an array with the wrong keys);
# the new API answers an empty report for the window. Variables: base_url and auth_<alias>. B5A fixtures.

# 1. A week that is in the calendar and has not happened yet (week 50 of 2040; the calendar ends 2040-12-31): 200, nothing in it, the window as the months give it, no next week, the week before it
GET {{base_url}}/reports/conduction?year=2040&week=50
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.year" == 2040
jsonpath "$.week" == 50
jsonpath "$.weekOf" == ""
jsonpath "$.classes" count == 0
jsonpath "$.lastWeek" count == 0
jsonpath "$.levels" count == 0
jsonpath "$.previous.year" == 2040
jsonpath "$.previous.week" == 49
jsonpath "$.next" == null

GET {{base_url}}/reports/conduction/download-all?year=2040&week=50
Authorization: {{auth_rp_coord}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "No data to download"

# 2. A year beyond the calendar (2100): the same empty answer as a week with no day, with PHP's 1970 window
GET {{base_url}}/reports/conduction?year=2100&week=10
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.year" == 2100
jsonpath "$.weekOf" == ""
jsonpath "$.classes" count == 0
jsonpath "$.lastWeek" count == 0
jsonpath "$.previous" == null
jsonpath "$.next" == null

# 3. A week the calendar has no day for (2025 has weeks 0 to 52): an empty answer with PHP's 1970 window (PHP prints deprecation notices in front of the JSON)
GET {{base_url}}/reports/conduction?year=2025&week=53
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.weekOf" == ""
jsonpath "$.previous" == null
jsonpath "$.next" == null
jsonpath "$.classes" count == 0
jsonpath "$.lastWeek" count == 0
jsonpath "$.summaryStart" == "Sun, 28-Dec-69"
jsonpath "$.summaryEnd" == "Sat, 31-Jan-70"

GET {{base_url}}/reports/conduction/download-all?year=2025&week=53
Authorization: {{auth_rp_coord}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "No data to download"

# 4. A level that holds a NUL byte reads no class and is not an error
GET {{base_url}}/reports/conduction?year=2025&week=45&level=A%00B
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.classes" count == 0
