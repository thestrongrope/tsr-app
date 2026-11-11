# GET /classes?q= on the NEW API only (tools/classes-contract.sh skips files named *-new-api.hurl on the PHP side).
# PHP answers 500 to any q: its query uses the named placeholder :q twice with native prepares (a PHP bug, not copied; see docs/specs/initial-build/fill-b1-notes.md).
# Variables: base_url and auth_<alias>. q is a LIKE %q% on code or name, case-insensitive; "0" counts as empty (PHP empty()).

GET {{base_url}}/classes?q=cls-g-0
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].id" == 9301

GET {{base_url}}/classes?q=Gents
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$" count == 1

GET {{base_url}}/classes?q=nomatch
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$" count == 0

GET {{base_url}}/classes?q=0
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$" count == 1

GET {{base_url}}/classes?include=managed&q=CLS-
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$" count == 2
jsonpath "$[0].id" == 9302
jsonpath "$[1].id" == 9301

# A NUL byte inside q matches no class (it must not be a server error).
GET {{base_url}}/classes?include=managed&q=a%00b
Authorization: {{auth_admin}}
HTTP 200
[Asserts]
jsonpath "$" count == 0
