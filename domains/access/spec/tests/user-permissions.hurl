# GET /user/permissions: the older page list by role id (the app router reads it)
# One file, run unchanged against the new API and PHP (tools/access-contract.sh dev|parity). Each fixture member
# signs in at that side's Auth emulator, then the whole answer is asserted: every permission in order and every
# scope, not only the status. Fixtures: one member per role, one with named grants, and the guest; none has any
# class relationship (the new API has no classes yet). Only synthetic .invalid emails (fixtures.vars, db/synthetic/seed.sql).
# The expected lists were captured from PHP (tsr-account develop) on the parity stack, then proven on the new API;
# where the two ever differ, PHP wins (docs/specs/initial-build/php-parity-feedback.md).


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

GET {{base_url}}/user/permissions
Authorization: Bearer {{member_token}}
HTTP 200
[Asserts]
jsonpath "$.version" == 3
jsonpath "$.issued_at" matches "^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\d\\.\\d{6}\\+00:00$"
jsonpath "$.*" count == 11
jsonpath "$.role_id" == 0
jsonpath "$.role_name" == "USER"
jsonpath "$.permissions" count == 0
jsonpath "$.applicable_roles" count == 0
jsonpath "$.enrolled" == false
jsonpath "$.class_count" == 0
jsonpath "$.teacher_count" == 0
jsonpath "$.mcq_admin" == false
jsonpath "$.is_teacher" == false

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

GET {{base_url}}/user/permissions
Authorization: Bearer {{superadmin_token}}
HTTP 200
[Asserts]
jsonpath "$.version" == 3
jsonpath "$.issued_at" matches "^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\d\\.\\d{6}\\+00:00$"
jsonpath "$.*" count == 11
jsonpath "$.role_id" == 1
jsonpath "$.role_name" == "SUPER_ADMIN"
jsonpath "$.permissions" count == 8
jsonpath "$.permissions[0]" == "admin_dashboard"
jsonpath "$.permissions[1]" == "class_management"
jsonpath "$.permissions[2]" == "finance_portal"
jsonpath "$.permissions[3]" == "page.admin.notifications"
jsonpath "$.permissions[4]" == "page.admin.syllabus"
jsonpath "$.permissions[5]" == "reports_center"
jsonpath "$.permissions[6]" == "system_settings"
jsonpath "$.permissions[7]" == "user_management"
jsonpath "$.applicable_roles" count == 1
jsonpath "$.applicable_roles[0].role_id" == 1
jsonpath "$.applicable_roles[0].role_name" == "SUPER_ADMIN"
jsonpath "$.applicable_roles[0].source" == "database_role"
jsonpath "$.applicable_roles[0].priority" == 1
jsonpath "$.enrolled" == false
jsonpath "$.class_count" == 0
jsonpath "$.teacher_count" == 0
jsonpath "$.mcq_admin" == false
jsonpath "$.is_teacher" == false

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

GET {{base_url}}/user/permissions
Authorization: Bearer {{gentsadmin_token}}
HTTP 200
[Asserts]
jsonpath "$.version" == 3
jsonpath "$.issued_at" matches "^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\d\\.\\d{6}\\+00:00$"
jsonpath "$.*" count == 11
jsonpath "$.role_id" == 3
jsonpath "$.role_name" == "GENTS_ADMIN"
jsonpath "$.permissions" count == 5
jsonpath "$.permissions[0]" == "gents_classes"
jsonpath "$.permissions[1]" == "gents_dashboard"
jsonpath "$.permissions[2]" == "gents_reports"
jsonpath "$.permissions[3]" == "gents_students"
jsonpath "$.permissions[4]" == "gents_teachers"
jsonpath "$.applicable_roles" count == 1
jsonpath "$.applicable_roles[0].role_id" == 3
jsonpath "$.applicable_roles[0].role_name" == "GENTS_ADMIN"
jsonpath "$.applicable_roles[0].source" == "database_role"
jsonpath "$.applicable_roles[0].priority" == 1
jsonpath "$.enrolled" == false
jsonpath "$.class_count" == 0
jsonpath "$.teacher_count" == 0
jsonpath "$.mcq_admin" == false
jsonpath "$.is_teacher" == false

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

GET {{base_url}}/user/permissions
Authorization: Bearer {{ladiesadmin_token}}
HTTP 200
[Asserts]
jsonpath "$.version" == 3
jsonpath "$.issued_at" matches "^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\d\\.\\d{6}\\+00:00$"
jsonpath "$.*" count == 11
jsonpath "$.role_id" == 4
jsonpath "$.role_name" == "LADIES_ADMIN"
jsonpath "$.permissions" count == 5
jsonpath "$.permissions[0]" == "ladies_classes"
jsonpath "$.permissions[1]" == "ladies_dashboard"
jsonpath "$.permissions[2]" == "ladies_reports"
jsonpath "$.permissions[3]" == "ladies_students"
jsonpath "$.permissions[4]" == "ladies_teachers"
jsonpath "$.applicable_roles" count == 1
jsonpath "$.applicable_roles[0].role_id" == 4
jsonpath "$.applicable_roles[0].role_name" == "LADIES_ADMIN"
jsonpath "$.applicable_roles[0].source" == "database_role"
jsonpath "$.applicable_roles[0].priority" == 1
jsonpath "$.enrolled" == false
jsonpath "$.class_count" == 0
jsonpath "$.teacher_count" == 0
jsonpath "$.mcq_admin" == false
jsonpath "$.is_teacher" == false

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

GET {{base_url}}/user/permissions
Authorization: Bearer {{coordinator_token}}
HTTP 200
[Asserts]
jsonpath "$.version" == 3
jsonpath "$.issued_at" matches "^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\d\\.\\d{6}\\+00:00$"
jsonpath "$.*" count == 11
jsonpath "$.role_id" == 5
jsonpath "$.role_name" == "CLASS_ADMIN"
jsonpath "$.permissions" count == 4
jsonpath "$.permissions[0]" == "class_management"
jsonpath "$.permissions[1]" == "class_reports"
jsonpath "$.permissions[2]" == "mcq_management"
jsonpath "$.permissions[3]" == "student_management"
jsonpath "$.applicable_roles" count == 1
jsonpath "$.applicable_roles[0].role_id" == 5
jsonpath "$.applicable_roles[0].role_name" == "CLASS_ADMIN"
jsonpath "$.applicable_roles[0].source" == "database_role"
jsonpath "$.applicable_roles[0].priority" == 1
jsonpath "$.enrolled" == false
jsonpath "$.class_count" == 0
jsonpath "$.teacher_count" == 0
jsonpath "$.mcq_admin" == false
jsonpath "$.is_teacher" == false

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

GET {{base_url}}/user/permissions
Authorization: Bearer {{finance_token}}
HTTP 200
[Asserts]
jsonpath "$.version" == 3
jsonpath "$.issued_at" matches "^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\d\\.\\d{6}\\+00:00$"
jsonpath "$.*" count == 11
jsonpath "$.role_id" == 7
jsonpath "$.role_name" == "FINANCE"
jsonpath "$.permissions" count == 3
jsonpath "$.permissions[0]" == "donor_management"
jsonpath "$.permissions[1]" == "finance_dashboard"
jsonpath "$.permissions[2]" == "financial_reports"
jsonpath "$.applicable_roles" count == 1
jsonpath "$.applicable_roles[0].role_id" == 7
jsonpath "$.applicable_roles[0].role_name" == "FINANCE"
jsonpath "$.applicable_roles[0].source" == "database_role"
jsonpath "$.applicable_roles[0].priority" == 1
jsonpath "$.enrolled" == false
jsonpath "$.class_count" == 0
jsonpath "$.teacher_count" == 0
jsonpath "$.mcq_admin" == false
jsonpath "$.is_teacher" == false

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

GET {{base_url}}/user/permissions
Authorization: Bearer {{teacherrole_token}}
HTTP 200
[Asserts]
jsonpath "$.version" == 3
jsonpath "$.issued_at" matches "^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\d\\.\\d{6}\\+00:00$"
jsonpath "$.*" count == 11
jsonpath "$.role_id" == 6
jsonpath "$.role_name" == "CLASS_TEACHER"
jsonpath "$.permissions" count == 8
jsonpath "$.permissions[0]" == "class_management"
jsonpath "$.permissions[1]" == "class_reports"
jsonpath "$.permissions[2]" == "grade_management"
jsonpath "$.permissions[3]" == "lesson_management"
jsonpath "$.permissions[4]" == "mcq_management"
jsonpath "$.permissions[5]" == "my_classes"
jsonpath "$.permissions[6]" == "student_management"
jsonpath "$.permissions[7]" == "teacher_dashboard"
jsonpath "$.applicable_roles" count == 1
jsonpath "$.applicable_roles[0].role_id" == 6
jsonpath "$.applicable_roles[0].role_name" == "CLASS_TEACHER"
jsonpath "$.applicable_roles[0].source" == "database_role"
jsonpath "$.applicable_roles[0].priority" == 1
jsonpath "$.enrolled" == false
jsonpath "$.class_count" == 0
jsonpath "$.teacher_count" == 0
jsonpath "$.mcq_admin" == false
jsonpath "$.is_teacher" == false

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

GET {{base_url}}/user/permissions
Authorization: Bearer {{granted_token}}
HTTP 200
[Asserts]
jsonpath "$.version" == 3
jsonpath "$.issued_at" matches "^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\d\\.\\d{6}\\+00:00$"
jsonpath "$.*" count == 11
jsonpath "$.role_id" == 0
jsonpath "$.role_name" == "USER"
jsonpath "$.permissions" count == 0
jsonpath "$.applicable_roles" count == 0
jsonpath "$.enrolled" == false
jsonpath "$.class_count" == 0
jsonpath "$.teacher_count" == 0
jsonpath "$.mcq_admin" == false
jsonpath "$.is_teacher" == false

# No sign-in
GET {{base_url}}/user/permissions
HTTP 401
[Asserts]
jsonpath "$.detail" == "Not authenticated"
