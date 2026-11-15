# GET /admin/quiz contract: the quiz competition overview, with no settings loaded and no cycle data. Runs against any implementation.
# Variables: base_url and auth_sheets_<alias> (tools/contract-sheets.sh). Fixtures: db/synthetic/sheets-fixtures.sql (no role holds quiz:admin or quiz:reset: the quiz members hold named grants).
# Reads only, takes no lock. The other admin-quiz files never load settings (no Google), so the overview stays the empty one.

# 1. Without sign-in: 401
GET {{base_url}}/admin/quiz
HTTP 401
[Asserts]
jsonpath "$.detail" == "Not authenticated"

# 2. Who may not: no grant, a super admin (holds standard-mcqs:update, not quiz:admin), a gender admin, quiz:reset alone, standard-mcqs alone, a revoked quiz:admin
GET {{base_url}}/admin/quiz
Authorization: {{auth_sheets_plain}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

GET {{base_url}}/admin/quiz
Authorization: {{auth_sheets_super}}
HTTP 403

GET {{base_url}}/admin/quiz
Authorization: {{auth_sheets_gents}}
HTTP 403

GET {{base_url}}/admin/quiz
Authorization: {{auth_sheets_reset}}
HTTP 403

GET {{base_url}}/admin/quiz
Authorization: {{auth_sheets_mcq}}
HTTP 403

GET {{base_url}}/admin/quiz
Authorization: {{auth_sheets_revoked}}
HTTP 403

# 3. The overview with an empty state: nothing loaded, nothing downloaded, nothing drawn; can_reset follows quiz:reset
GET {{base_url}}/admin/quiz
Authorization: {{auth_sheets_quiz}}
HTTP 200
[Asserts]
jsonpath "$.settings.loaded" == false
jsonpath "$.settings.kind" == "grand"
jsonpath "$.settings.series" == null
jsonpath "$.settings.title" == null
jsonpath "$.settings.mode" == null
jsonpath "$.settings.registration" == null
jsonpath "$.settings.stop" == null
jsonpath "$.settings.mega_minimum" == null
jsonpath "$.settings.episodes" count == 0
jsonpath "$.settings.winner_counts" count == 1
jsonpath "$.settings.winner_counts[0]" == 0
jsonpath "$.settings.winner_labels" count == 1
jsonpath "$.settings.winner_labels[0]" == ""
jsonpath "$.settings.colors.heading" == null
jsonpath "$.settings.colors.heading_text" == null
jsonpath "$.quiz_day" == 0
jsonpath "$.download" == null
jsonpath "$.eligibility" count == 0
jsonpath "$.gates.generate.allowed" == false
jsonpath "$.gates.generate.reason" == "Download the scoreboard first."
jsonpath "$.gates.mega.offered" == false
jsonpath "$.gates.mega.allowed" == false
jsonpath "$.gates.mega.reason" == "The overall Mega winner needs winners for every episode first."
jsonpath "$.gates.mega_student.allowed" == false
jsonpath "$.gates.mega_student.reason" == "Download the scoreboard first."
jsonpath "$.winners.episodes" count == 0
jsonpath "$.winners.mega" == null
jsonpath "$.winners.mega_student" == null
jsonpath "$.activity.scoreboard_published" == null
jsonpath "$.activity.winners_generated" == null
jsonpath "$.activity.winners_reset" == null
jsonpath "$.activity.winners_published" == null
jsonpath "$.activity.mega_generated" == null
jsonpath "$.activity.mega_reset" == null
jsonpath "$.activity.mega_published" == null
jsonpath "$.activity.mega_student_generated" == null
jsonpath "$.activity.mega_student_reset" == null
jsonpath "$.activity.mega_student_published" == null
jsonpath "$.can_reset" == false
# Nothing that names a sheet or lists members
jsonpath "$.sheet_ids" not exists
jsonpath "$.winners_replaced" not exists

GET {{base_url}}/admin/quiz
Authorization: {{auth_sheets_quizreset}}
HTTP 200
[Asserts]
jsonpath "$.can_reset" == true
jsonpath "$.settings.loaded" == false
