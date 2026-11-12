# GET /me/guides/{slug} contract: one level's English guide by the slug of its guide link. Runs against any implementation (tools/classes-contract.sh).
# Variables: base_url and auth_<alias>. Fixtures (classes-fixtures.sql): the guide of level 3 (miqdad) has text, level 5 (bilal) is blank,
# level 4 (ammar) has no guide row; 900311 studies in the open class 9301 (level 3), 900301 teaches it, 900312 studies in 9302 (level 5),
# 900313 is in no class, 900316 was removed from 9301, 900315 is a super admin in no class. Level 2 (abuzar) is left alone: guide-update.hurl
# rewrites it. Neither side sets a public web base, so share_url is null (the db tests cover the link). Synthetic members only. Read only.

# 1. Without sign-in: 401 with a detail
GET {{base_url}}/me/guides/miqdad
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A member who neither studies nor teaches is refused with PHP's text
GET {{base_url}}/me/guides/miqdad
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Guides are for students and teachers"

GET {{base_url}}/me/guides/miqdad
Authorization: {{auth_removed}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Guides are for students and teachers"

GET {{base_url}}/me/guides/miqdad
Authorization: {{auth_admin}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Guides are for students and teachers"

# 3. The refusal comes before the lookup: an unknown slug tells a non-reader nothing
GET {{base_url}}/me/guides/no-such-guide
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Guides are for students and teachers"

# 4. A student gets the guide untouched, the level's name and no link to share
GET {{base_url}}/me/guides/miqdad
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.guide" == "<p>Cls Miqdad guide</p>"
jsonpath "$.level_name" == "MIQDAD"
jsonpath "$.share_url" == null
jsonpath "$.levelName" not exists
jsonpath "$.level_id" not exists

# 5. The class's teacher reads it too
GET {{base_url}}/me/guides/miqdad
Authorization: {{auth_teacher_g}}
HTTP 200
[Asserts]
jsonpath "$.guide" == "<p>Cls Miqdad guide</p>"
jsonpath "$.level_name" == "MIQDAD"

# 6. Any student or teacher reads any level's guide: a student of a BILAL class reads MIQDAD's
GET {{base_url}}/me/guides/miqdad
Authorization: {{auth_student_l}}
HTTP 200
[Asserts]
jsonpath "$.guide" == "<p>Cls Miqdad guide</p>"

# 7. A slug that names no level: 404 with PHP's text. The match is exact: another case, a level id, the level without a guide page
GET {{base_url}}/me/guides/no-such-guide
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Guide not found"

GET {{base_url}}/me/guides/MIQDAD
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Guide not found"

GET {{base_url}}/me/guides/Miqdad
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Guide not found"

GET {{base_url}}/me/guides/3
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Guide not found"

GET {{base_url}}/me/guides/salman
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Guide not found"

GET {{base_url}}/me/guides/miqdad.php
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Guide not found"

GET {{base_url}}/me/guides/miqdad-2
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Guide not found"

# 8. A level with no guide row, and a level whose guide is blank: 404, even for a student of that level
GET {{base_url}}/me/guides/ammar
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Guide not found"

GET {{base_url}}/me/guides/bilal
Authorization: {{auth_student_l}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Guide not found"
