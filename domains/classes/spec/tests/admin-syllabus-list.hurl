# GET /admin/syllabus contract: every level with its items, for the super admin. Runs against any implementation.
# Variables: base_url and auth_<alias>. B4a fixtures: level 4 holds 9501 (sort 2, description ''), 9502 (no sort order), 9503 (inactive), 9504 (deleted), 9506 (sort 1); the syllabus admin 900901 (role 1).

# 1. Without sign-in: 401
GET {{base_url}}/admin/syllabus
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Only the super admin: a student and the gents admin are refused
GET {{base_url}}/admin/syllabus
Authorization: {{auth_en_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can access this resource"

GET {{base_url}}/admin/syllabus
Authorization: {{auth_en_gadmin}}
HTTP 403

# 3. Every level appears, empty ones too; level 1's active items in order (an item without a sort order first), the hidden and the deleted left out
GET {{base_url}}/admin/syllabus
Authorization: {{auth_b4_syl}}
HTTP 200
[Asserts]
jsonpath "$[?(@.level_id==4)].level_name" == "AMMAR"
jsonpath "$[?(@.level_id==4)].level_code" == "AY"
jsonpath "$[?(@.level_id==5)].level_name" == "BILAL"
jsonpath "$[?(@.level_id==4)].items[0].id" == 9502
jsonpath "$[?(@.level_id==4)].items[1].id" == 9506
jsonpath "$[?(@.level_id==4)].items[2].id" == 9501
jsonpath "$[?(@.level_id==4)].items[3]" not exists
jsonpath "$[?(@.level_id==4)].items[0].sort_order" == 0
jsonpath "$[?(@.level_id==4)].items[0].description" == "B4 text"
jsonpath "$[?(@.level_id==4)].items[0].link_type" == "external"
jsonpath "$[?(@.level_id==4)].items[0].is_active" == true
jsonpath "$[?(@.level_id==4)].items[0].created_at" == "2025-06-01T09:00:00"
jsonpath "$[?(@.level_id==4)].items[0].modified_at" == null
jsonpath "$[?(@.level_id==4)].items[2].description" == null
jsonpath "$[?(@.level_id==4)].items[2].url" == "https://example.invalid/b4/two.pdf"
jsonpath "$[?(@.level_id==4)].items[2].level_id" == 4

# 4. Inactive items included on request (any of true, 1, yes, on, in any case); the deleted one never
GET {{base_url}}/admin/syllabus?include_inactive=TRUE
Authorization: {{auth_b4_syl}}
HTTP 200
[Asserts]
jsonpath "$[?(@.level_id==4)].items[3].id" == 9503
jsonpath "$[?(@.level_id==4)].items[3].is_active" == false
jsonpath "$[?(@.level_id==4)].items[4]" not exists

GET {{base_url}}/admin/syllabus?include_inactive=%20on%20
Authorization: {{auth_b4_syl}}
HTTP 200
[Asserts]
jsonpath "$[?(@.level_id==4)].items[3].id" == 9503

# 5. The false spellings and an empty value mean false
GET {{base_url}}/admin/syllabus?include_inactive=no
Authorization: {{auth_b4_syl}}
HTTP 200
[Asserts]
jsonpath "$[?(@.level_id==4)].items[3]" not exists

GET {{base_url}}/admin/syllabus?include_inactive=
Authorization: {{auth_b4_syl}}
HTTP 200
[Asserts]
jsonpath "$[?(@.level_id==4)].items[3]" not exists

# 6. Anything else is 422
GET {{base_url}}/admin/syllabus?include_inactive=maybe
Authorization: {{auth_b4_syl}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid include_inactive"

# 7. The member-facing level list orders the same way (an item without a sort order first)
GET {{base_url}}/syllabus/level/4
Authorization: {{auth_b4_syl}}
HTTP 200
[Asserts]
jsonpath "$.items[0].id" == 9502
jsonpath "$.items[1].id" == 9506
jsonpath "$.items[2].id" == 9501
jsonpath "$.items[3]" not exists
