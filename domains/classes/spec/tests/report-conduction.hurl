# GET /reports/conduction contract: the conduction of one week for every class the caller reaches, and the figures over the weeks around it. Runs against any implementation.
# Variables: base_url and auth_<alias>. B5A REPORT fixtures (classes-b5a-fixtures.sql; reset by tools/classes-contract.sh), dates fixed in November 2025, so the files ask for year=2025&week=45 (9 to 15 Nov; the
# summary window is 26 Oct to 6 Dec). rp_coord is assigned the gents classes 9581 (MIQDAD, RP-G-581: two held days in week 45) and 9582 (ABUZAR, RP-G-582) and nothing else, so its answer is compared in full.
# The other callers are asserted only on the classes of these fixtures (the rest of the database differs between the two sides).

# 1. Without sign-in: 401
GET {{base_url}}/reports/conduction?year=2025&week=45
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A member without reports:read: 403
GET {{base_url}}/reports/conduction?year=2025&week=45
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. The coordinator: exactly its two classes; the week, its neighbours and the window
GET {{base_url}}/reports/conduction?year=2025&week=45
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.year" == 2025
jsonpath "$.week" == 45
jsonpath "$.previous.year" == 2025
jsonpath "$.previous.week" == 44
jsonpath "$.next.year" == 2025
jsonpath "$.next.week" == 46
jsonpath "$.weekOf" == "09-Nov to 15-Nov"
jsonpath "$.summaryStart" == "Sun, 26-Oct-25"
jsonpath "$.summaryEnd" == "Sat, 06-Dec-25"
jsonpath "$.levels" count == 2
jsonpath "$.levels[0]" == "ABUZAR"
jsonpath "$.levels[1]" == "MIQDAD"
jsonpath "$.classes" count == 2
jsonpath "$.classes[0].class" == "RP-G-582"
jsonpath "$.classes[0].level" == "ABUZAR"
jsonpath "$.classes[0].gender" == "Gents"
jsonpath "$.classes[0].teacher" == "Rp Member 901413"
jsonpath "$.classes[0].expected" == 6
jsonpath "$.classes[0].conducted" == 1
jsonpath "$.classes[0].notFilled" == 5
jsonpath "$.classes[0].notConducted" == 0
jsonpath "$.classes[0].students" == 1
jsonpath "$.classes[0].attendance" == 1
jsonpath "$.classes[0].percentNotFilled" == 83
jsonpath "$.classes[0].percentConduction" == 100
jsonpath "$.classes[0].percentAttendance" == 100
jsonpath "$.classes[1].class" == "RP-G-581"
jsonpath "$.classes[1].teacher" == "Rp Member 901411"
jsonpath "$.classes[1].expected" == 8
jsonpath "$.classes[1].conducted" == 4
jsonpath "$.classes[1].notFilled" == 2
jsonpath "$.classes[1].notConducted" == 2
jsonpath "$.classes[1].students" == 3
jsonpath "$.classes[1].attendance" == 6
jsonpath "$.classes[1].percentNotFilled" == 25
jsonpath "$.classes[1].percentConduction" == 67
jsonpath "$.classes[1].percentAttendance" == 50
jsonpath "$.lastWeek" count == 3
jsonpath "$.lastWeek[?(@.classId==9582)].status" == "Yes"
jsonpath "$.lastWeek[?(@.classId==9582)].conductedOn" == "2025-11-11"
jsonpath "$.lastWeek[?(@.classId==9582)].duration" == 50
jsonpath "$.lastWeek[?(@.classId==9582)].attendance" == 1
jsonpath "$.lastWeek[?(@.classId==9582)].registered" == 1
jsonpath "$.lastWeek[?(@.classId==9582)].extra" == 0
jsonpath "$.lastWeek[?(@.classId==9582)].reason" == null
jsonpath "$.lastWeek[?(@.classId==9581 && @.conductedOn=='2025-11-10')].duration" == 45
jsonpath "$.lastWeek[?(@.classId==9581 && @.conductedOn=='2025-11-10')].attendance" == 2
jsonpath "$.lastWeek[?(@.classId==9581 && @.conductedOn=='2025-11-10')].registered" == 2
jsonpath "$.lastWeek[?(@.classId==9581 && @.conductedOn=='2025-11-10')].extra" == 1
jsonpath "$.lastWeek[?(@.classId==9581 && @.conductedOn=='2025-11-13')].status" == "Yes"

# 4. The level narrows the classes and the week rows, not the list of levels
GET {{base_url}}/reports/conduction?year=2025&week=45&level=ABUZAR
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.levels" count == 2
jsonpath "$.classes" count == 1
jsonpath "$.classes[0].class" == "RP-G-582"
jsonpath "$.lastWeek" count == 1

GET {{base_url}}/reports/conduction?year=2025&week=45&level=%20nothing%20
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.classes" count == 0
jsonpath "$.lastWeek" count == 0

# 5. A week with a not-held day (3 Nov, week 44): the reason; a week with nothing filled (week 43) is "Not Filled"
GET {{base_url}}/reports/conduction?year=2025&week=44
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.weekOf" == "02-Nov to 08-Nov"
jsonpath "$.lastWeek[?(@.classId==9581)].status" == "No"
jsonpath "$.lastWeek[?(@.classId==9581)].reason" == "Rp rain"
jsonpath "$.lastWeek[?(@.classId==9581)].conductedOn" == "2025-11-03"
jsonpath "$.lastWeek[?(@.classId==9582)].status" == "Not Filled"
jsonpath "$.lastWeek[?(@.classId==9582)].conductedOn" == null

# 6. The ladies administrator asks for gents and gets ladies; the gents administrator asks for ladies and gets gents
GET {{base_url}}/reports/conduction?year=2025&week=45&gender=1
Authorization: {{auth_en_ladmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.lastWeek[?(@.classId==9583)].status" == "Yes"
jsonpath "$.lastWeek[?(@.classId==9581)]" not exists
jsonpath "$.lastWeek[?(@.classId==9582)]" not exists

GET {{base_url}}/reports/conduction?year=2025&week=45&gender=2
Authorization: {{auth_en_gadmin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.lastWeek[?(@.classId==9581)]" count == 2
jsonpath "$.lastWeek[?(@.classId==9583)]" not exists

# 7. The coordinator asking for ladies is held to its own gender
GET {{base_url}}/reports/conduction?year=2025&week=45&gender=2
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.classes" count == 2

# 8. The super administrator: the gender asked for (only the text 2 is ladies); never the closed class, the other city's class is there, never the demo class
GET {{base_url}}/reports/conduction?year=2025&week=45
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.lastWeek[?(@.classId==9581)]" count == 2
jsonpath "$.lastWeek[?(@.classId==9584)].status" == "Yes"
jsonpath "$.lastWeek[?(@.classId==9583)]" not exists
jsonpath "$.lastWeek[?(@.classId==9585)]" not exists
jsonpath "$.lastWeek[?(@.classId==9586)]" not exists
jsonpath "$.classes[?(@.class=='AYD1')]" not exists

GET {{base_url}}/reports/conduction?year=2025&week=45&gender=2
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 2
jsonpath "$.lastWeek[?(@.classId==9583)].status" == "Yes"
jsonpath "$.lastWeek[?(@.classId==9581)]" not exists

GET {{base_url}}/reports/conduction?year=2025&week=45&gender=3
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1

# 9. No year and week: the last completed week; the answer has the same shape
GET {{base_url}}/reports/conduction
Authorization: {{auth_rp_coord}}
HTTP 200
[Asserts]
jsonpath "$.gender" == 1
jsonpath "$.year" >= 2025
jsonpath "$.classes" count == 2
jsonpath "$.summaryStart" matches /^[A-Z][a-z]{2}, \d\d-[A-Z][a-z]{2}-\d\d$/

# 10. Year and week out of range: 422
GET {{base_url}}/reports/conduction?year=1999&week=3
Authorization: {{auth_rp_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid year or week"

GET {{base_url}}/reports/conduction?year=2025&week=54
Authorization: {{auth_rp_coord}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid year or week"

GET {{base_url}}/reports/conduction?year=abc
Authorization: {{auth_rp_coord}}
HTTP 422

GET {{base_url}}/reports/conduction?week=-1
Authorization: {{auth_rp_coord}}
HTTP 422
