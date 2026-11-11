# POST /admin/syllabus, cases only the new API answers (PHP stores what MariaDB accepts; PostgreSQL text cannot hold a NUL byte and the columns have limits). Runs on the new API only.
# Variables: base_url and auth_<alias>. B4a fixtures: the syllabus admin 900901 (role 1).

# 1. A NUL byte in a text is 422
POST {{base_url}}/admin/syllabus
Authorization: {{auth_b4_syl}}
{"level_id": 1, "subject_name": "a\u0000b", "url": "https://example.invalid/nul"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "subject_name must not contain a NUL byte"

# 2. A subject over its 150 characters is 422
POST {{base_url}}/admin/syllabus
Authorization: {{auth_b4_syl}}
{"level_id": 1, "subject_name": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "url": "https://example.invalid/long"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "subject_name must be at most 150 characters"

# 3. A sort order outside a 32-bit integer is 422
POST {{base_url}}/admin/syllabus
Authorization: {{auth_b4_syl}}
{"level_id": 1, "subject_name": "B4 big", "url": "https://example.invalid/big", "sort_order": 99999999999}
HTTP 422
[Asserts]
jsonpath "$.detail" == "sort_order must be an integer"
