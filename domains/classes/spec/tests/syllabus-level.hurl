# GET /syllabus/level/{level_id} contract: one level's active syllabus items. Runs against any implementation.
# Variables: base_url and auth_<alias>. Fixtures: level 3 has two active items (sort order 1 and 2) and one inactive.

# 1. Without sign-in: 401
GET {{base_url}}/syllabus/level/3
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. An unknown level and a non-numeric one: 404
GET {{base_url}}/syllabus/level/99
Authorization: {{auth_outsider}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Level not found"

GET {{base_url}}/syllabus/level/abc
Authorization: {{auth_outsider}}
HTTP 404

# 3. A level's active items in sort order, with the level's name and code
GET {{base_url}}/syllabus/level/3
Authorization: {{auth_outsider}}
HTTP 200
[Asserts]
jsonpath "$.level_id" == 3
jsonpath "$.level_name" == "MIQDAD"
jsonpath "$.level_code" == "MK"
jsonpath "$.items" count == 2
jsonpath "$.items[0].id" == 9302
jsonpath "$.items[0].level_id" == 3
jsonpath "$.items[0].subject_name" == "Cls syllabus a"
jsonpath "$.items[0].description" == "Invented description"
jsonpath "$.items[0].link_type" == "pdf"
jsonpath "$.items[0].url" == "https://example.invalid/syllabus/a.pdf"
jsonpath "$.items[0].sort_order" == 1
jsonpath "$.items[0].is_active" == true
jsonpath "$.items[0].created_at" matches /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/
jsonpath "$.items[0].modified_at" == null
jsonpath "$.items[1].subject_name" == "Cls syllabus b"
jsonpath "$.items[1].description" == null
jsonpath "$.items[1].link_type" == "external"

# 4. A level without items: an empty list
GET {{base_url}}/syllabus/level/5
Authorization: {{auth_outsider}}
HTTP 200
[Asserts]
jsonpath "$.level_name" == "BILAL"
jsonpath "$.items" count == 0
