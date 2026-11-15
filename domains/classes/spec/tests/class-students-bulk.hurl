# POST /classes/{class_id}/students/bulk contract: enrol a pasted list of "name" or "name, mobile" lines. Runs against any implementation.
# Variables: base_url and auth_<alias>. BULK fixtures (db/synthetic/classes-bulk-fixtures.sql, reset by tools/classes-contract.sh; the members a run creates are deleted first): gents class 9451 (teacher 900711,
# 900721 "Bulk Existing" enrolled), ladies class 9452 (teacher 900712), gents class 9453, free members 900722 "Gents Freeman" (gents), 900723 "Ladies Freewoman" (ladies), 900724 "Nogender Person", 900725 "Short Number"
# (a seven digit mobile), 900726 "Format Member" (a mobile with a plus, spaces and a dash); gents admins bk_adm_a to bk_adm_d and bk_adm_f, ladies admin bk_ladm_e. Each admin makes at most 4 bulk adds a run:
# the limit is 10 a minute per member, counted after the permission check, 422s included, so no file asserts a 429.

# 1. Without sign-in: 401
POST {{base_url}}/classes/9451/students/bulk
{"lines": ["Nobody"]}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Unknown or closed class: 404 before the permission check
POST {{base_url}}/classes/999999/students/bulk
Authorization: {{auth_bk_adm_f}}
{"lines": ["Nobody"]}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

POST {{base_url}}/classes/9417/students/bulk
Authorization: {{auth_bk_adm_f}}
{"lines": ["Nobody"]}
HTTP 404

# 3. A student, the class's own teacher, an admin of the other gender (either way round): 403, nothing written
POST {{base_url}}/classes/9451/students/bulk
Authorization: {{auth_bk_student}}
{"lines": ["Nobody"]}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to change this class's students"

POST {{base_url}}/classes/9451/students/bulk
Authorization: {{auth_bk_teacher}}
{"lines": ["Nobody"]}
HTTP 403

POST {{base_url}}/classes/9451/students/bulk
Authorization: {{auth_bk_ladm_e}}
{"lines": ["Nobody"]}
HTTP 403

POST {{base_url}}/classes/9452/students/bulk
Authorization: {{auth_bk_adm_f}}
{"lines": ["Nobody"]}
HTTP 403

# 4. The body: lines a list of at most 200 texts of at most 300 characters, one of them not blank (bk_adm_b: 4 calls)
POST {{base_url}}/classes/9451/students/bulk
Authorization: {{auth_bk_adm_b}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "lines must be a list of at most 200 lines"

POST {{base_url}}/classes/9451/students/bulk
Authorization: {{auth_bk_adm_b}}
{"lines": ["Cap 1","Cap 2","Cap 3","Cap 4","Cap 5","Cap 6","Cap 7","Cap 8","Cap 9","Cap 10","Cap 11","Cap 12","Cap 13","Cap 14","Cap 15","Cap 16","Cap 17","Cap 18","Cap 19","Cap 20","Cap 21","Cap 22","Cap 23","Cap 24","Cap 25","Cap 26","Cap 27","Cap 28","Cap 29","Cap 30","Cap 31","Cap 32","Cap 33","Cap 34","Cap 35","Cap 36","Cap 37","Cap 38","Cap 39","Cap 40","Cap 41","Cap 42","Cap 43","Cap 44","Cap 45","Cap 46","Cap 47","Cap 48","Cap 49","Cap 50","Cap 51","Cap 52","Cap 53","Cap 54","Cap 55","Cap 56","Cap 57","Cap 58","Cap 59","Cap 60","Cap 61","Cap 62","Cap 63","Cap 64","Cap 65","Cap 66","Cap 67","Cap 68","Cap 69","Cap 70","Cap 71","Cap 72","Cap 73","Cap 74","Cap 75","Cap 76","Cap 77","Cap 78","Cap 79","Cap 80","Cap 81","Cap 82","Cap 83","Cap 84","Cap 85","Cap 86","Cap 87","Cap 88","Cap 89","Cap 90","Cap 91","Cap 92","Cap 93","Cap 94","Cap 95","Cap 96","Cap 97","Cap 98","Cap 99","Cap 100","Cap 101","Cap 102","Cap 103","Cap 104","Cap 105","Cap 106","Cap 107","Cap 108","Cap 109","Cap 110","Cap 111","Cap 112","Cap 113","Cap 114","Cap 115","Cap 116","Cap 117","Cap 118","Cap 119","Cap 120","Cap 121","Cap 122","Cap 123","Cap 124","Cap 125","Cap 126","Cap 127","Cap 128","Cap 129","Cap 130","Cap 131","Cap 132","Cap 133","Cap 134","Cap 135","Cap 136","Cap 137","Cap 138","Cap 139","Cap 140","Cap 141","Cap 142","Cap 143","Cap 144","Cap 145","Cap 146","Cap 147","Cap 148","Cap 149","Cap 150","Cap 151","Cap 152","Cap 153","Cap 154","Cap 155","Cap 156","Cap 157","Cap 158","Cap 159","Cap 160","Cap 161","Cap 162","Cap 163","Cap 164","Cap 165","Cap 166","Cap 167","Cap 168","Cap 169","Cap 170","Cap 171","Cap 172","Cap 173","Cap 174","Cap 175","Cap 176","Cap 177","Cap 178","Cap 179","Cap 180","Cap 181","Cap 182","Cap 183","Cap 184","Cap 185","Cap 186","Cap 187","Cap 188","Cap 189","Cap 190","Cap 191","Cap 192","Cap 193","Cap 194","Cap 195","Cap 196","Cap 197","Cap 198","Cap 199","Cap 200","Cap 201"]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "lines must be a list of at most 200 lines"

POST {{base_url}}/classes/9451/students/bulk
Authorization: {{auth_bk_adm_b}}
{"lines": ["Fine Name", 5]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "each line must be text of at most 300 characters"

POST {{base_url}}/classes/9451/students/bulk
Authorization: {{auth_bk_adm_b}}
{"lines": ["xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "each line must be text of at most 300 characters"

# 5. More body rules (bk_adm_c: 4 calls)
POST {{base_url}}/classes/9451/students/bulk
Authorization: {{auth_bk_adm_c}}
{"lines": {"a": "Some Name"}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "lines must be a list of at most 200 lines"

POST {{base_url}}/classes/9451/students/bulk
Authorization: {{auth_bk_adm_c}}
{"lines": ["", "   "]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Add at least one student, one per line: a name, then an optional mobile number."

POST {{base_url}}/classes/9451/students/bulk
Authorization: {{auth_bk_adm_c}}
{"lines": ["Some Name"], "resolutions": {"1": "maybe"}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "a resolution must be add, enrol or skip"

POST {{base_url}}/classes/9451/students/bulk
Authorization: {{auth_bk_adm_c}}
{"lines": ["Some Name"], "resolutions": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "a resolution must be add, enrol or skip"

# 6. The first pass changes nothing and reveals only a masked first name: flagged lines wait for an answer (bk_adm_a: 4 calls)
POST {{base_url}}/classes/9451/students/bulk
Authorization: {{auth_bk_adm_a}}
{"lines": ["Fresh One", "", "Bad Mobile, 12", ", +910000070722", "Bulk Existing", "Match Me, +91 0000070722", "Dup Mobile, +910000070721", "Ladies Number, +910000070723", "Short Mobile, 9007250"]}
HTTP 200
[Asserts]
jsonpath "$.status" == "confirm"
jsonpath "$.added" == 0
jsonpath "$.roster" not exists
jsonpath "$.lines" count == 8
jsonpath "$.lines[?(@.line==1)].status" == "ready"
jsonpath "$.lines[?(@.line==3)].status" == "rejected"
jsonpath "$.lines[?(@.line==3)].reason" == "The mobile number is not valid."
jsonpath "$.lines[?(@.line==4)].status" == "rejected"
jsonpath "$.lines[?(@.line==4)].reason" == "The name is missing."
jsonpath "$.lines[?(@.line==5)].status" == "duplicate_name"
jsonpath "$.lines[?(@.line==6)].status" == "mobile_match"
jsonpath "$.lines[?(@.line==6)].member.name" == "Gents F."
jsonpath "$.lines[?(@.line==7)].status" == "rejected"
jsonpath "$.lines[?(@.line==7)].reason" == "That member is already in this class."
jsonpath "$.lines[?(@.line==8)].status" == "ready"
jsonpath "$.lines[?(@.line==9)].status" == "ready"
body not contains "900722"
body not contains "Gents Freeman"
body not contains "0000070722"

# 7. The answers: skip one, enrol the match; the others are added (an answer for a line that was not flagged, here 1 and 2, is ignored). The roster comes back
POST {{base_url}}/classes/9451/students/bulk
Authorization: {{auth_bk_adm_a}}
{"lines": ["Fresh One", "", "Bad Mobile, 12", ", +910000070722", "Bulk Existing", "Match Me, +91 0000070722", "Dup Mobile, +910000070721", "Ladies Number, +910000070723", "Short Mobile, 9007250"], "resolutions": {"5": "skip", "6": "enrol", "1": "skip", "2": "enrol"}}
HTTP 200
[Asserts]
jsonpath "$.status" == "added"
jsonpath "$.added" == 4
jsonpath "$.lines[?(@.line==1)].status" == "added"
jsonpath "$.lines[?(@.line==5)].status" == "rejected"
jsonpath "$.lines[?(@.line==5)].reason" == "Skipped."
jsonpath "$.lines[?(@.line==6)].status" == "enrolled"
jsonpath "$.lines[?(@.line==6)].member.name" == "Gents F."
jsonpath "$.lines[?(@.line==8)].status" == "added"
jsonpath "$.lines[?(@.line==9)].status" == "added"
jsonpath "$.roster.students" count == 5
jsonpath "$.roster.students[?(@.token==900722)].name" == "Gents Freeman"
jsonpath "$.roster.students[*].name" includes "Ladies Number"
jsonpath "$.roster.students[*].name" includes "Short Mobile"

# 8. A name already on the roster is flagged; enrol is not an answer for it; add (any case, any spacing) is
POST {{base_url}}/classes/9451/students/bulk
Authorization: {{auth_bk_adm_a}}
{"lines": ["Ladies Number"], "resolutions": {"1": "enrol"}}
HTTP 200
[Asserts]
jsonpath "$.status" == "confirm"
jsonpath "$.lines[0].status" == "duplicate_name"
jsonpath "$.lines[0].member" not exists

POST {{base_url}}/classes/9451/students/bulk
Authorization: {{auth_bk_adm_a}}
{"lines": ["ladies   NUMBER"], "resolutions": {"1": "add"}}
HTTP 200
[Asserts]
jsonpath "$.status" == "added"
jsonpath "$.added" == 1
jsonpath "$.lines[0].status" == "added"
jsonpath "$.roster.students" count == 6

# 9. A mobile is matched on its last ten digits (spaces, dashes and a country code do not hide it); a member without a gender may be enrolled; extra body fields are ignored (bk_adm_d: 2 calls)
POST {{base_url}}/classes/9453/students/bulk
Authorization: {{auth_bk_adm_d}}
{"lines": ["Unknown Person, +91 0000070724", "Format Test, 0000070726"]}
HTTP 200
[Asserts]
jsonpath "$.status" == "confirm"
jsonpath "$.lines[0].status" == "mobile_match"
jsonpath "$.lines[0].member.name" == "Nogender P."
jsonpath "$.lines[1].status" == "mobile_match"
jsonpath "$.lines[1].member.name" == "Format M."

POST {{base_url}}/classes/9453/students/bulk
Authorization: {{auth_bk_adm_d}}
{"lines": ["Unknown Person, +91 0000070724", "Format Test, 0000070726"], "resolutions": {"1": "enrol", "2": "enrol"}, "email": "mass@example.invalid", "roleid": 3, "gender": "2", "token": 1}
HTTP 200
[Asserts]
jsonpath "$.status" == "added"
jsonpath "$.added" == 2
jsonpath "$.lines[0].status" == "enrolled"
jsonpath "$.lines[1].status" == "enrolled"
jsonpath "$.roster.students" count == 2
jsonpath "$.roster.students[?(@.token==900724)].name" == "Nogender Person"

# 10. Gender segregation: a ladies class never matches a gents member's number (the line becomes a new member), and does match a ladies member and one without a gender (bk_ladm_e: 1 call)
POST {{base_url}}/classes/9452/students/bulk
Authorization: {{auth_bk_ladm_e}}
{"lines": ["Ladies New", "Gents Number, +910000070722", "Ladies Match, +910000070723", "Nogender Alt, +910000070724"], "resolutions": {"3": "enrol", "4": "enrol"}}
HTTP 200
[Asserts]
jsonpath "$.status" == "added"
jsonpath "$.added" == 4
jsonpath "$.lines[1].status" == "added"
jsonpath "$.lines[1].member" not exists
jsonpath "$.lines[2].status" == "enrolled"
jsonpath "$.lines[2].member.name" == "Ladies F."
jsonpath "$.lines[3].status" == "enrolled"
jsonpath "$.roster.students" count == 4
jsonpath "$.roster.students[*].token" not includes 900722
body not contains "Gents Freeman"
