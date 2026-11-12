# GET /me/permissions: what each kind of member may do, the scopes behind it, the two navigation facts and the revision
# One file, run unchanged against the new API and PHP (tools/access-contract.sh dev|parity). Each fixture member
# signs in at that side's Auth emulator, then the whole answer is asserted: every permission in order and every
# scope, not only the status. Fixtures: one member per role, one with named grants, and the guest; none has any
# class relationship. Only synthetic .invalid emails (fixtures.vars, db/synthetic/seed.sql).
# The expected lists were captured from PHP on the parity stack, then proven on the new API;
# where the two ever differ, PHP wins (docs/specs/initial-build/php-parity-feedback.md).
# Version 5 (PHP of 12 Nov 2026): `navigation`, `revision`, the revision as the ETag, 304 for If-None-Match. The revision's
# value is not pinned here: only its shape, that it comes back as the tag, that two members with the same answer share it
# (role 0 and role 6) and that a different answer has another. Not asserted: 503 (needs unreadable storage; database test).
# The header X-Permissions-Revision is the member's revision on every response of a request whose sign-in passed (here: this
# route's 200 and 304, and the 200 and 404 of GET /me/permissions/{permission}); a request refused at sign-in has none.


# Member, role 0: the member set only
POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{member_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{member_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
member_token: jsonpath "$.idToken"

GET {{base_url}}/me/permissions
Authorization: Bearer {{member_token}}
HTTP 200
[Captures]
member_etag: header "ETag"
member_revision: jsonpath "$.revision"
[Asserts]
jsonpath "$.version" == 5
jsonpath "$.issued_at" matches "^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\d\\.\\d{6}\\+00:00$"
jsonpath "$.*" count == 6
jsonpath "$.permissions" count == 21
jsonpath "$.permissions[0]" == "account:delete:self"
jsonpath "$.permissions[1]" == "attendance:read:self"
jsonpath "$.permissions[2]" == "children-performance:read:self"
jsonpath "$.permissions[3]" == "children:link:self"
jsonpath "$.permissions[4]" == "children:read:self"
jsonpath "$.permissions[5]" == "class-requests:create:self"
jsonpath "$.permissions[6]" == "classes:join:self"
jsonpath "$.permissions[7]" == "classes:read:enrolled"
jsonpath "$.permissions[8]" == "content:read:all"
jsonpath "$.permissions[9]" == "devices:manage:self"
jsonpath "$.permissions[10]" == "feedback:create:self"
jsonpath "$.permissions[11]" == "notifications:read:self"
jsonpath "$.permissions[12]" == "parents:manage:self"
jsonpath "$.permissions[13]" == "performance:read:self"
jsonpath "$.permissions[14]" == "profile:read:self"
jsonpath "$.permissions[15]" == "profile:update:self"
jsonpath "$.permissions[16]" == "quiz-competition:take:all"
jsonpath "$.permissions[17]" == "quiz-scores:read:self"
jsonpath "$.permissions[18]" == "quizzes:take:enrolled"
jsonpath "$.permissions[19]" == "sessions:read:enrolled"
jsonpath "$.permissions[20]" == "syllabus:read:all"
jsonpath "$.scopes.gender" == null
jsonpath "$.scopes.*" count == 6
jsonpath "$.scopes.assigned" count == 0
jsonpath "$.scopes.assigned_genders" count == 0
jsonpath "$.scopes.own" count == 0
jsonpath "$.scopes.taught" count == 0
jsonpath "$.scopes.enrolled" count == 0
jsonpath "$.navigation.*" count == 2
jsonpath "$.navigation.classes" == false
jsonpath "$.navigation.manage" == false
jsonpath "$.revision" matches "^[0-9a-f]{16}$"
header "ETag" matches "^\"[0-9a-f]{16}\"$"
header "Cache-Control" == "private, no-cache"
header "Vary" contains "Authorization"

# The revision is the ETag: asking again with it is 304 with no body and the same three headers
GET {{base_url}}/me/permissions
Authorization: Bearer {{member_token}}
If-None-Match: {{member_etag}}
HTTP 304
[Asserts]
header "ETag" == "{{member_etag}}"
header "Cache-Control" == "private, no-cache"
header "Vary" contains "Authorization"
header "X-Permissions-Revision" == "{{member_revision}}"
bytes count == 0

# A weak tag matches (weak comparison)
GET {{base_url}}/me/permissions
Authorization: Bearer {{member_token}}
If-None-Match: W/{{member_etag}}
HTTP 304
[Asserts]
bytes count == 0

# A list that holds the tag matches
GET {{base_url}}/me/permissions
Authorization: Bearer {{member_token}}
If-None-Match: "stale", {{member_etag}}
HTTP 304
[Asserts]
bytes count == 0

# The star matches any answer
GET {{base_url}}/me/permissions
Authorization: Bearer {{member_token}}
If-None-Match: *
HTTP 304
[Asserts]
bytes count == 0

# Another tag gets the full answer, with the same revision as before (nothing changed in between)
GET {{base_url}}/me/permissions
Authorization: Bearer {{member_token}}
If-None-Match: "0000000000000000"
HTTP 200
[Asserts]
header "ETag" == "{{member_etag}}"
header "X-Permissions-Revision" == "{{member_revision}}"
jsonpath "$.revision" == "{{member_revision}}"
jsonpath "$.permissions" count == 21

# The revision without its quotes is not the tag
GET {{base_url}}/me/permissions
Authorization: Bearer {{member_token}}
If-None-Match: {{member_revision}}
HTTP 200
[Asserts]
jsonpath "$.revision" == "{{member_revision}}"

# Any other signed-in route carries the same revision in the header, whatever it answers
GET {{base_url}}/me/permissions/feedback:create
Authorization: Bearer {{member_token}}
HTTP 200
[Asserts]
header "X-Permissions-Revision" == "{{member_revision}}"

GET {{base_url}}/me/permissions/nope:read
Authorization: Bearer {{member_token}}
HTTP 404
[Asserts]
header "X-Permissions-Revision" == "{{member_revision}}"

# Super admin, role 1
POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{superadmin_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{superadmin_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
superadmin_token: jsonpath "$.idToken"

GET {{base_url}}/me/permissions
Authorization: Bearer {{superadmin_token}}
HTTP 200
[Asserts]
jsonpath "$.version" == 5
jsonpath "$.issued_at" matches "^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\d\\.\\d{6}\\+00:00$"
jsonpath "$.*" count == 6
jsonpath "$.permissions" count == 59
jsonpath "$.permissions[0]" == "account:delete:self"
jsonpath "$.permissions[1]" == "api-docs:read:all"
jsonpath "$.permissions[2]" == "attendance:read:self"
jsonpath "$.permissions[3]" == "audit-log:read:all"
jsonpath "$.permissions[4]" == "children-performance:read:self"
jsonpath "$.permissions[5]" == "children:link:self"
jsonpath "$.permissions[6]" == "children:read:self"
jsonpath "$.permissions[7]" == "class-access:manage:all"
jsonpath "$.permissions[8]" == "class-requests:create:self"
jsonpath "$.permissions[9]" == "class-students:read:all"
jsonpath "$.permissions[10]" == "class-students:update:all"
jsonpath "$.permissions[11]" == "classes:create:all"
jsonpath "$.permissions[12]" == "classes:join:self"
jsonpath "$.permissions[13]" == "classes:read:all"
jsonpath "$.permissions[14]" == "classes:read:enrolled"
jsonpath "$.permissions[15]" == "classes:update:all"
jsonpath "$.permissions[16]" == "content:read:all"
jsonpath "$.permissions[17]" == "deactivated-classes:manage:all"
jsonpath "$.permissions[18]" == "deletion-requests:manage:all"
jsonpath "$.permissions[19]" == "devices:manage:self"
jsonpath "$.permissions[20]" == "donors:read:all"
jsonpath "$.permissions[21]" == "feedback:create:self"
jsonpath "$.permissions[22]" == "feedback:review:all"
jsonpath "$.permissions[23]" == "guides:manage:all"
jsonpath "$.permissions[24]" == "mcqs:copy:all"
jsonpath "$.permissions[25]" == "mcqs:manage:all"
jsonpath "$.permissions[26]" == "members:enrol-by-token:all"
jsonpath "$.permissions[27]" == "notifications:broadcast:all"
jsonpath "$.permissions[28]" == "notifications:read:self"
jsonpath "$.permissions[29]" == "notifications:send:all"
jsonpath "$.permissions[30]" == "parents:add-direct:all"
jsonpath "$.permissions[31]" == "parents:add:all"
jsonpath "$.permissions[32]" == "parents:manage:all"
jsonpath "$.permissions[33]" == "parents:manage:self"
jsonpath "$.permissions[34]" == "performance:read:self"
jsonpath "$.permissions[35]" == "permissions:manage:all"
jsonpath "$.permissions[36]" == "profile:read:self"
jsonpath "$.permissions[37]" == "profile:update:self"
jsonpath "$.permissions[38]" == "quiz-competition:take:all"
jsonpath "$.permissions[39]" == "quiz-scores:read:self"
jsonpath "$.permissions[40]" == "quizzes:take:enrolled"
jsonpath "$.permissions[41]" == "quran-leaderboard:read:all"
jsonpath "$.permissions[42]" == "registrations:approve:all"
jsonpath "$.permissions[43]" == "registrations:read:all"
jsonpath "$.permissions[44]" == "registrations:reject:all"
jsonpath "$.permissions[45]" == "reports:read:all"
jsonpath "$.permissions[46]" == "sessions:create:all"
jsonpath "$.permissions[47]" == "sessions:read:enrolled"
jsonpath "$.permissions[48]" == "sessions:update:all"
jsonpath "$.permissions[49]" == "spot-quizzes:manage:all"
jsonpath "$.permissions[50]" == "standard-mcqs:update:all"
jsonpath "$.permissions[51]" == "students:enrol:all"
jsonpath "$.permissions[52]" == "students:transfer:all"
jsonpath "$.permissions[53]" == "summary-report:read:all"
jsonpath "$.permissions[54]" == "syllabus:read:all"
jsonpath "$.permissions[55]" == "syllabus:update:all"
jsonpath "$.permissions[56]" == "teachers:lookup:all"
jsonpath "$.permissions[57]" == "teachers:read:all"
jsonpath "$.permissions[58]" == "whatsapp:manage:all"
jsonpath "$.scopes.gender" == null
jsonpath "$.scopes.*" count == 6
jsonpath "$.scopes.assigned" count == 0
jsonpath "$.scopes.assigned_genders" count == 0
jsonpath "$.scopes.own" count == 0
jsonpath "$.scopes.taught" count == 0
jsonpath "$.scopes.enrolled" count == 0
jsonpath "$.navigation.*" count == 2
jsonpath "$.navigation.classes" == true
jsonpath "$.navigation.manage" == true
jsonpath "$.revision" matches "^[0-9a-f]{16}$"
header "ETag" matches "^\"[0-9a-f]{16}\"$"
header "Cache-Control" == "private, no-cache"
header "Vary" contains "Authorization"
jsonpath "$.revision" != "{{member_revision}}"

# Gents admin, role 3: the gender scope is 1
POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{gentsadmin_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{gentsadmin_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
gentsadmin_token: jsonpath "$.idToken"

GET {{base_url}}/me/permissions
Authorization: Bearer {{gentsadmin_token}}
HTTP 200
[Asserts]
jsonpath "$.version" == 5
jsonpath "$.issued_at" matches "^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\d\\.\\d{6}\\+00:00$"
jsonpath "$.*" count == 6
jsonpath "$.permissions" count == 39
jsonpath "$.permissions[0]" == "account:delete:self"
jsonpath "$.permissions[1]" == "attendance:read:self"
jsonpath "$.permissions[2]" == "children-performance:read:self"
jsonpath "$.permissions[3]" == "children:link:self"
jsonpath "$.permissions[4]" == "children:read:self"
jsonpath "$.permissions[5]" == "class-access:manage:gender"
jsonpath "$.permissions[6]" == "class-requests:create:self"
jsonpath "$.permissions[7]" == "classes:create:gender"
jsonpath "$.permissions[8]" == "classes:join:self"
jsonpath "$.permissions[9]" == "classes:read:enrolled"
jsonpath "$.permissions[10]" == "classes:read:gender"
jsonpath "$.permissions[11]" == "classes:update:gender"
jsonpath "$.permissions[12]" == "content:read:all"
jsonpath "$.permissions[13]" == "devices:manage:self"
jsonpath "$.permissions[14]" == "feedback:create:self"
jsonpath "$.permissions[15]" == "mcqs:copy:gender"
jsonpath "$.permissions[16]" == "notifications:read:self"
jsonpath "$.permissions[17]" == "notifications:send:gender"
jsonpath "$.permissions[18]" == "parents:add-direct:gender"
jsonpath "$.permissions[19]" == "parents:add:gender"
jsonpath "$.permissions[20]" == "parents:manage:gender"
jsonpath "$.permissions[21]" == "parents:manage:self"
jsonpath "$.permissions[22]" == "performance:read:self"
jsonpath "$.permissions[23]" == "profile:read:self"
jsonpath "$.permissions[24]" == "profile:update:self"
jsonpath "$.permissions[25]" == "quiz-competition:take:all"
jsonpath "$.permissions[26]" == "quiz-scores:read:self"
jsonpath "$.permissions[27]" == "quizzes:take:enrolled"
jsonpath "$.permissions[28]" == "quran-leaderboard:read:gender"
jsonpath "$.permissions[29]" == "registrations:approve:gender"
jsonpath "$.permissions[30]" == "registrations:read:gender"
jsonpath "$.permissions[31]" == "reports:read:gender"
jsonpath "$.permissions[32]" == "sessions:create:gender"
jsonpath "$.permissions[33]" == "sessions:read:enrolled"
jsonpath "$.permissions[34]" == "sessions:update:gender"
jsonpath "$.permissions[35]" == "students:enrol:gender"
jsonpath "$.permissions[36]" == "syllabus:read:all"
jsonpath "$.permissions[37]" == "teachers:lookup:gender"
jsonpath "$.permissions[38]" == "teachers:read:gender"
jsonpath "$.scopes.gender" == 1
jsonpath "$.scopes.*" count == 6
jsonpath "$.scopes.assigned" count == 0
jsonpath "$.scopes.assigned_genders" count == 0
jsonpath "$.scopes.own" count == 0
jsonpath "$.scopes.taught" count == 0
jsonpath "$.scopes.enrolled" count == 0
jsonpath "$.navigation.*" count == 2
jsonpath "$.navigation.classes" == true
jsonpath "$.navigation.manage" == true
jsonpath "$.revision" matches "^[0-9a-f]{16}$"
header "ETag" matches "^\"[0-9a-f]{16}\"$"
header "Cache-Control" == "private, no-cache"
header "Vary" contains "Authorization"

# Ladies admin, role 4: the gender scope is 2
POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{ladiesadmin_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{ladiesadmin_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
ladiesadmin_token: jsonpath "$.idToken"

GET {{base_url}}/me/permissions
Authorization: Bearer {{ladiesadmin_token}}
HTTP 200
[Asserts]
jsonpath "$.version" == 5
jsonpath "$.issued_at" matches "^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\d\\.\\d{6}\\+00:00$"
jsonpath "$.*" count == 6
jsonpath "$.permissions" count == 39
jsonpath "$.permissions[0]" == "account:delete:self"
jsonpath "$.permissions[1]" == "attendance:read:self"
jsonpath "$.permissions[2]" == "children-performance:read:self"
jsonpath "$.permissions[3]" == "children:link:self"
jsonpath "$.permissions[4]" == "children:read:self"
jsonpath "$.permissions[5]" == "class-access:manage:gender"
jsonpath "$.permissions[6]" == "class-requests:create:self"
jsonpath "$.permissions[7]" == "classes:create:gender"
jsonpath "$.permissions[8]" == "classes:join:self"
jsonpath "$.permissions[9]" == "classes:read:enrolled"
jsonpath "$.permissions[10]" == "classes:read:gender"
jsonpath "$.permissions[11]" == "classes:update:gender"
jsonpath "$.permissions[12]" == "content:read:all"
jsonpath "$.permissions[13]" == "devices:manage:self"
jsonpath "$.permissions[14]" == "feedback:create:self"
jsonpath "$.permissions[15]" == "mcqs:copy:gender"
jsonpath "$.permissions[16]" == "notifications:read:self"
jsonpath "$.permissions[17]" == "notifications:send:gender"
jsonpath "$.permissions[18]" == "parents:add-direct:gender"
jsonpath "$.permissions[19]" == "parents:add:gender"
jsonpath "$.permissions[20]" == "parents:manage:gender"
jsonpath "$.permissions[21]" == "parents:manage:self"
jsonpath "$.permissions[22]" == "performance:read:self"
jsonpath "$.permissions[23]" == "profile:read:self"
jsonpath "$.permissions[24]" == "profile:update:self"
jsonpath "$.permissions[25]" == "quiz-competition:take:all"
jsonpath "$.permissions[26]" == "quiz-scores:read:self"
jsonpath "$.permissions[27]" == "quizzes:take:enrolled"
jsonpath "$.permissions[28]" == "quran-leaderboard:read:gender"
jsonpath "$.permissions[29]" == "registrations:approve:gender"
jsonpath "$.permissions[30]" == "registrations:read:gender"
jsonpath "$.permissions[31]" == "reports:read:gender"
jsonpath "$.permissions[32]" == "sessions:create:gender"
jsonpath "$.permissions[33]" == "sessions:read:enrolled"
jsonpath "$.permissions[34]" == "sessions:update:gender"
jsonpath "$.permissions[35]" == "students:enrol:gender"
jsonpath "$.permissions[36]" == "syllabus:read:all"
jsonpath "$.permissions[37]" == "teachers:lookup:gender"
jsonpath "$.permissions[38]" == "teachers:read:gender"
jsonpath "$.scopes.gender" == 2
jsonpath "$.scopes.*" count == 6
jsonpath "$.scopes.assigned" count == 0
jsonpath "$.scopes.assigned_genders" count == 0
jsonpath "$.scopes.own" count == 0
jsonpath "$.scopes.taught" count == 0
jsonpath "$.scopes.enrolled" count == 0
jsonpath "$.navigation.*" count == 2
jsonpath "$.navigation.classes" == true
jsonpath "$.navigation.manage" == true
jsonpath "$.revision" matches "^[0-9a-f]{16}$"
header "ETag" matches "^\"[0-9a-f]{16}\"$"
header "Cache-Control" == "private, no-cache"
header "Vary" contains "Authorization"

# Class coordinator, role 5: assigned scope, but no rule yet so no class
POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{coordinator_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{coordinator_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
coordinator_token: jsonpath "$.idToken"

GET {{base_url}}/me/permissions
Authorization: Bearer {{coordinator_token}}
HTTP 200
[Asserts]
jsonpath "$.version" == 5
jsonpath "$.issued_at" matches "^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\d\\.\\d{6}\\+00:00$"
jsonpath "$.*" count == 6
jsonpath "$.permissions" count == 34
jsonpath "$.permissions[0]" == "account:delete:self"
jsonpath "$.permissions[1]" == "attendance:read:self"
jsonpath "$.permissions[2]" == "children-performance:read:self"
jsonpath "$.permissions[3]" == "children:link:self"
jsonpath "$.permissions[4]" == "children:read:self"
jsonpath "$.permissions[5]" == "class-requests:create:self"
jsonpath "$.permissions[6]" == "classes:join:self"
jsonpath "$.permissions[7]" == "classes:read:assigned"
jsonpath "$.permissions[8]" == "classes:read:enrolled"
jsonpath "$.permissions[9]" == "classes:update:assigned"
jsonpath "$.permissions[10]" == "content:read:all"
jsonpath "$.permissions[11]" == "devices:manage:self"
jsonpath "$.permissions[12]" == "feedback:create:self"
jsonpath "$.permissions[13]" == "mcqs:copy:assigned"
jsonpath "$.permissions[14]" == "notifications:read:self"
jsonpath "$.permissions[15]" == "notifications:send:assigned"
jsonpath "$.permissions[16]" == "parents:add-direct:assigned"
jsonpath "$.permissions[17]" == "parents:add:assigned"
jsonpath "$.permissions[18]" == "parents:manage:self"
jsonpath "$.permissions[19]" == "performance:read:self"
jsonpath "$.permissions[20]" == "profile:read:self"
jsonpath "$.permissions[21]" == "profile:update:self"
jsonpath "$.permissions[22]" == "quiz-competition:take:all"
jsonpath "$.permissions[23]" == "quiz-scores:read:self"
jsonpath "$.permissions[24]" == "quizzes:take:enrolled"
jsonpath "$.permissions[25]" == "registrations:approve:assigned"
jsonpath "$.permissions[26]" == "registrations:read:assigned"
jsonpath "$.permissions[27]" == "reports:read:assigned"
jsonpath "$.permissions[28]" == "sessions:create:assigned"
jsonpath "$.permissions[29]" == "sessions:read:enrolled"
jsonpath "$.permissions[30]" == "sessions:update:assigned"
jsonpath "$.permissions[31]" == "students:enrol:assigned"
jsonpath "$.permissions[32]" == "syllabus:read:all"
jsonpath "$.permissions[33]" == "teachers:lookup:assigned"
jsonpath "$.scopes.gender" == null
jsonpath "$.scopes.*" count == 6
jsonpath "$.scopes.assigned" count == 0
jsonpath "$.scopes.assigned_genders" count == 0
jsonpath "$.scopes.own" count == 0
jsonpath "$.scopes.taught" count == 0
jsonpath "$.scopes.enrolled" count == 0
jsonpath "$.navigation.*" count == 2
jsonpath "$.navigation.classes" == false
jsonpath "$.navigation.manage" == true
jsonpath "$.revision" matches "^[0-9a-f]{16}$"
header "ETag" matches "^\"[0-9a-f]{16}\"$"
header "Cache-Control" == "private, no-cache"
header "Vary" contains "Authorization"

# Finance, role 7
POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{finance_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{finance_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
finance_token: jsonpath "$.idToken"

GET {{base_url}}/me/permissions
Authorization: Bearer {{finance_token}}
HTTP 200
[Asserts]
jsonpath "$.version" == 5
jsonpath "$.issued_at" matches "^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\d\\.\\d{6}\\+00:00$"
jsonpath "$.*" count == 6
jsonpath "$.permissions" count == 22
jsonpath "$.permissions[0]" == "account:delete:self"
jsonpath "$.permissions[1]" == "attendance:read:self"
jsonpath "$.permissions[2]" == "children-performance:read:self"
jsonpath "$.permissions[3]" == "children:link:self"
jsonpath "$.permissions[4]" == "children:read:self"
jsonpath "$.permissions[5]" == "class-requests:create:self"
jsonpath "$.permissions[6]" == "classes:join:self"
jsonpath "$.permissions[7]" == "classes:read:enrolled"
jsonpath "$.permissions[8]" == "content:read:all"
jsonpath "$.permissions[9]" == "devices:manage:self"
jsonpath "$.permissions[10]" == "donors:read:all"
jsonpath "$.permissions[11]" == "feedback:create:self"
jsonpath "$.permissions[12]" == "notifications:read:self"
jsonpath "$.permissions[13]" == "parents:manage:self"
jsonpath "$.permissions[14]" == "performance:read:self"
jsonpath "$.permissions[15]" == "profile:read:self"
jsonpath "$.permissions[16]" == "profile:update:self"
jsonpath "$.permissions[17]" == "quiz-competition:take:all"
jsonpath "$.permissions[18]" == "quiz-scores:read:self"
jsonpath "$.permissions[19]" == "quizzes:take:enrolled"
jsonpath "$.permissions[20]" == "sessions:read:enrolled"
jsonpath "$.permissions[21]" == "syllabus:read:all"
jsonpath "$.scopes.gender" == null
jsonpath "$.scopes.*" count == 6
jsonpath "$.scopes.assigned" count == 0
jsonpath "$.scopes.assigned_genders" count == 0
jsonpath "$.scopes.own" count == 0
jsonpath "$.scopes.taught" count == 0
jsonpath "$.scopes.enrolled" count == 0
jsonpath "$.navigation.*" count == 2
jsonpath "$.navigation.classes" == false
jsonpath "$.navigation.manage" == true
jsonpath "$.revision" matches "^[0-9a-f]{16}$"
header "ETag" matches "^\"[0-9a-f]{16}\"$"
header "Cache-Control" == "private, no-cache"
header "Vary" contains "Authorization"

# Role 6 (class teacher): PHP holds nothing for it; teaching is never the role id
POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{teacherrole_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{teacherrole_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
teacherrole_token: jsonpath "$.idToken"

GET {{base_url}}/me/permissions
Authorization: Bearer {{teacherrole_token}}
HTTP 200
[Asserts]
jsonpath "$.version" == 5
jsonpath "$.issued_at" matches "^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\d\\.\\d{6}\\+00:00$"
jsonpath "$.*" count == 6
jsonpath "$.permissions" count == 21
jsonpath "$.permissions[0]" == "account:delete:self"
jsonpath "$.permissions[1]" == "attendance:read:self"
jsonpath "$.permissions[2]" == "children-performance:read:self"
jsonpath "$.permissions[3]" == "children:link:self"
jsonpath "$.permissions[4]" == "children:read:self"
jsonpath "$.permissions[5]" == "class-requests:create:self"
jsonpath "$.permissions[6]" == "classes:join:self"
jsonpath "$.permissions[7]" == "classes:read:enrolled"
jsonpath "$.permissions[8]" == "content:read:all"
jsonpath "$.permissions[9]" == "devices:manage:self"
jsonpath "$.permissions[10]" == "feedback:create:self"
jsonpath "$.permissions[11]" == "notifications:read:self"
jsonpath "$.permissions[12]" == "parents:manage:self"
jsonpath "$.permissions[13]" == "performance:read:self"
jsonpath "$.permissions[14]" == "profile:read:self"
jsonpath "$.permissions[15]" == "profile:update:self"
jsonpath "$.permissions[16]" == "quiz-competition:take:all"
jsonpath "$.permissions[17]" == "quiz-scores:read:self"
jsonpath "$.permissions[18]" == "quizzes:take:enrolled"
jsonpath "$.permissions[19]" == "sessions:read:enrolled"
jsonpath "$.permissions[20]" == "syllabus:read:all"
jsonpath "$.scopes.gender" == null
jsonpath "$.scopes.*" count == 6
jsonpath "$.scopes.assigned" count == 0
jsonpath "$.scopes.assigned_genders" count == 0
jsonpath "$.scopes.own" count == 0
jsonpath "$.scopes.taught" count == 0
jsonpath "$.scopes.enrolled" count == 0
jsonpath "$.navigation.*" count == 2
jsonpath "$.navigation.classes" == false
jsonpath "$.navigation.manage" == false
jsonpath "$.revision" matches "^[0-9a-f]{16}$"
header "ETag" matches "^\"[0-9a-f]{16}\"$"
header "Cache-Control" == "private, no-cache"
header "Vary" contains "Authorization"
jsonpath "$.revision" == "{{member_revision}}"

# Role 0 with named grants: two live, one revoked (summary-report:read:all is not held)
POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{granted_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{granted_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
granted_token: jsonpath "$.idToken"

GET {{base_url}}/me/permissions
Authorization: Bearer {{granted_token}}
HTTP 200
[Asserts]
jsonpath "$.version" == 5
jsonpath "$.issued_at" matches "^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\d\\.\\d{6}\\+00:00$"
jsonpath "$.*" count == 6
jsonpath "$.permissions" count == 23
jsonpath "$.permissions[0]" == "account:delete:self"
jsonpath "$.permissions[1]" == "api-docs:read:all"
jsonpath "$.permissions[2]" == "attendance:read:self"
jsonpath "$.permissions[3]" == "children-performance:read:self"
jsonpath "$.permissions[4]" == "children:link:self"
jsonpath "$.permissions[5]" == "children:read:self"
jsonpath "$.permissions[6]" == "class-requests:create:self"
jsonpath "$.permissions[7]" == "classes:join:self"
jsonpath "$.permissions[8]" == "classes:read:enrolled"
jsonpath "$.permissions[9]" == "content:read:all"
jsonpath "$.permissions[10]" == "devices:manage:self"
jsonpath "$.permissions[11]" == "feedback:create:self"
jsonpath "$.permissions[12]" == "notifications:read:self"
jsonpath "$.permissions[13]" == "parents:manage:self"
jsonpath "$.permissions[14]" == "performance:read:self"
jsonpath "$.permissions[15]" == "profile:read:self"
jsonpath "$.permissions[16]" == "profile:update:self"
jsonpath "$.permissions[17]" == "quiz-competition:take:all"
jsonpath "$.permissions[18]" == "quiz-scores:read:self"
jsonpath "$.permissions[19]" == "quizzes:take:enrolled"
jsonpath "$.permissions[20]" == "sessions:read:enrolled"
jsonpath "$.permissions[21]" == "standard-mcqs:update:all"
jsonpath "$.permissions[22]" == "syllabus:read:all"
jsonpath "$.scopes.gender" == null
jsonpath "$.scopes.*" count == 6
jsonpath "$.scopes.assigned" count == 0
jsonpath "$.scopes.assigned_genders" count == 0
jsonpath "$.scopes.own" count == 0
jsonpath "$.scopes.taught" count == 0
jsonpath "$.scopes.enrolled" count == 0
jsonpath "$.navigation.*" count == 2
jsonpath "$.navigation.classes" == false
jsonpath "$.navigation.manage" == true
jsonpath "$.revision" matches "^[0-9a-f]{16}$"
header "ETag" matches "^\"[0-9a-f]{16}\"$"
header "Cache-Control" == "private, no-cache"
header "Vary" contains "Authorization"

# The guest (token 0) never reaches the engine: sign-in refuses it first
POST {{emulator_url}}/projects/{{project_id}}/accounts
Authorization: Bearer owner
Content-Type: application/json
{"email": "{{guest_email}}", "password": "{{emulator_password}}", "emailVerified": true}
HTTP *

POST {{emulator_url}}/accounts:signInWithPassword?key=local
Content-Type: application/json
{"email": "{{guest_email}}", "password": "{{emulator_password}}", "returnSecureToken": true}
HTTP 200
[Captures]
guest_token: jsonpath "$.idToken"
GET {{base_url}}/me/permissions
Authorization: Bearer {{guest_token}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Registration incomplete"
header "X-Permissions-Revision" not exists

# No sign-in
GET {{base_url}}/me/permissions
HTTP 401
[Asserts]
jsonpath "$.detail" == "Not authenticated"
header "X-Permissions-Revision" not exists
