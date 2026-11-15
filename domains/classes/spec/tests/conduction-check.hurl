# GET /classes/{class_id}/conduction/check?date= contract: does the class already have a session on that day, and does the day's week already hold as many sessions as the class has schedule slots. Runs against any implementation.
# Variables: base_url and auth_<alias>. CONDUCTION fixtures: class 9474 (teacher 900801, one slot on Monday, sessions on Monday 2025-10-13 and Monday 2099-01-05); class 9471 (three slots, one of them deleted; sessions on three Saturdays).

# 1. Without sign-in: 401. Unknown class: 404. A student, another class's teacher, the ladies' admin: 403
GET {{base_url}}/classes/9474/conduction/check
[QueryStringParams]
date: 2025-10-13
HTTP 401

GET {{base_url}}/classes/999999/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: 2025-10-13
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_student}}
[QueryStringParams]
date: 2025-10-13
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to manage this class"

GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_teacher2}}
[QueryStringParams]
date: 2025-10-13
HTTP 403

GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_en_ladmin}}
[QueryStringParams]
date: 2025-10-13
HTTP 403

# 2. The date: missing, blank or unreadable is 422
GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_teacher}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "date is required and must be a valid date"

GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date:   
HTTP 422

GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: nonsense
HTTP 422

GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: 2025-13-01
HTTP 422

GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: 2025-02-32
HTTP 422

# 3. The day of a session: already conducted; one slot a week, so the week is full
GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: 2025-10-13
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.alreadyConducted" == true
jsonpath "$.sameWeek" == true

# 4. Another day of the same week (Monday to Sunday): not conducted, week full. Sunday belongs to the week before it
GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: 2025-10-16
HTTP 200
[Asserts]
jsonpath "$.alreadyConducted" == false
jsonpath "$.sameWeek" == true

GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: 2025-10-19
HTTP 200
[Asserts]
jsonpath "$.alreadyConducted" == false
jsonpath "$.sameWeek" == true

GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: 2025-10-20
HTTP 200
[Asserts]
jsonpath "$.alreadyConducted" == false
jsonpath "$.sameWeek" == false

GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: 2025-10-12
HTTP 200
[Asserts]
jsonpath "$.alreadyConducted" == false
jsonpath "$.sameWeek" == false

# 5. Other spellings of the same day, as PHP's strtotime reads them
GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: 13-10-2025
HTTP 200
[Asserts]
jsonpath "$.alreadyConducted" == true

GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: 10/13/2025
HTTP 200
[Asserts]
jsonpath "$.alreadyConducted" == true

GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: 20251013
HTTP 200
[Asserts]
jsonpath "$.alreadyConducted" == true

GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: 13 October 2025
HTTP 200
[Asserts]
jsonpath "$.alreadyConducted" == true

GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: 2025-10-13 10:30
HTTP 200
[Asserts]
jsonpath "$.alreadyConducted" == true

GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: 2025-10-13T23:30:00-05:00
HTTP 200
[Asserts]
jsonpath "$.alreadyConducted" == false
jsonpath "$.sameWeek" == true

GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: 2025-02-30
HTTP 200
[Asserts]
jsonpath "$.alreadyConducted" == false

# 6. A class with three slots (one deleted, which still counts): one session in the week is not a full week. Any session counts, held or not
GET {{base_url}}/classes/9471/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: 2025-09-20
HTTP 200
[Asserts]
jsonpath "$.alreadyConducted" == true
jsonpath "$.sameWeek" == false

GET {{base_url}}/classes/9471/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: 2025-09-13
HTTP 200
[Asserts]
jsonpath "$.alreadyConducted" == true

# 7. A class with no session and no slot: nothing conducted, and the week needs one session
GET {{base_url}}/classes/9476/conduction/check
Authorization: {{auth_cd_teacher}}
[QueryStringParams]
date: 2025-10-13
HTTP 200
[Asserts]
jsonpath "$.alreadyConducted" == false
jsonpath "$.sameWeek" == false

# 8. A super admin may check
GET {{base_url}}/classes/9474/conduction/check
Authorization: {{auth_admin}}
[QueryStringParams]
date: 2025-10-13
HTTP 200
