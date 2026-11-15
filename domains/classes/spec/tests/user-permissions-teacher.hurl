# GET /user/permissions for a teacher who holds no MCQ flag (access reads classes through IClassScopes). Runs against any implementation.
# Fixture: 900301 teaches 9301 and holds no mcq_admin flag. Only class_teacher applies; class_admin belongs to the flag (PHP permissions.php).

GET {{base_url}}/user/permissions
Authorization: {{auth_teacher_g}}
HTTP 200
[Asserts]
jsonpath "$.mcq_admin" == false
jsonpath "$.is_teacher" == true
jsonpath "$.applicable_roles" count == 1
jsonpath "$.applicable_roles[0].role_name" == "CLASS_TEACHER"
