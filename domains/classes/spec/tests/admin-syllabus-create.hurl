# POST /admin/syllabus contract: add a syllabus item to a level (super admin). Runs against any implementation.
# Variables: base_url and auth_<alias>. B4a fixtures (reset by tools/classes-contract.sh; items a run creates are deleted): the syllabus admin 900901 (role 1). Level 1 and 2 hold the seed item on the new API only, so the checks here read by id.

# 1. Without sign-in: 401
POST {{base_url}}/admin/syllabus
{"level_id": 1, "subject_name": "B4 New", "url": "https://example.invalid/b4/new"}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Only the super admin
POST {{base_url}}/admin/syllabus
Authorization: {{auth_en_student}}
{"level_id": 1, "subject_name": "B4 New", "url": "https://example.invalid/b4/new"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can access this resource"

# 3. The checks, in PHP's order
POST {{base_url}}/admin/syllabus
Authorization: {{auth_b4_syl}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "level_id is required"

POST {{base_url}}/admin/syllabus
Authorization: {{auth_b4_syl}}
{"level_id": "abc", "subject_name": "x", "url": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "level_id is required"

POST {{base_url}}/admin/syllabus
Authorization: {{auth_b4_syl}}
{"level_id": 1, "subject_name": "   ", "url": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "subject_name is required"

POST {{base_url}}/admin/syllabus
Authorization: {{auth_b4_syl}}
{"level_id": 1, "subject_name": 5, "url": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "subject_name is required"

POST {{base_url}}/admin/syllabus
Authorization: {{auth_b4_syl}}
{"level_id": 1, "subject_name": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "url is required"

POST {{base_url}}/admin/syllabus
Authorization: {{auth_b4_syl}}
{"level_id": 1, "subject_name": "x", "url": "x", "link_type": "doc"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "link_type must be 'pdf' or 'external'"

POST {{base_url}}/admin/syllabus
Authorization: {{auth_b4_syl}}
{"level_id": 1, "subject_name": "x", "url": "x", "sort_order": "high"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "sort_order must be an integer"

POST {{base_url}}/admin/syllabus
Authorization: {{auth_b4_syl}}
{"level_id": 1, "subject_name": "x", "url": "x", "description": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "description must be a string"

# 4. An unknown level is 400, after every other check
POST {{base_url}}/admin/syllabus
Authorization: {{auth_b4_syl}}
{"level_id": 99, "subject_name": "x", "url": "x"}
HTTP 400
[Asserts]
jsonpath "$.detail" == "Invalid level_id"

# 5. A numeric string level and a fractional sort order are accepted; values are stored untrimmed; the link type defaults to pdf
POST {{base_url}}/admin/syllabus
Authorization: {{auth_b4_syl}}
{"level_id": "1", "subject_name": " B4 New ", "url": " https://example.invalid/b4/new ", "sort_order": 2.9}
HTTP 201
[Captures]
new_id: jsonpath "$.id"
[Asserts]
jsonpath "$.level_id" == 1
jsonpath "$.subject_name" == " B4 New "
jsonpath "$.url" == " https://example.invalid/b4/new "
jsonpath "$.link_type" == "pdf"
jsonpath "$.sort_order" == 2
jsonpath "$.description" == null
jsonpath "$.is_active" == true
jsonpath "$.modified_at" == null
jsonpath "$.created_at" matches /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/

# 6. An external link with a description, then both show on the level's public list
POST {{base_url}}/admin/syllabus
Authorization: {{auth_b4_syl}}
{"level_id": 1, "subject_name": "B4 Second", "url": "https://example.invalid/b4/second", "link_type": "external", "description": "B4 described", "sort_order": 1}
HTTP 201
[Captures]
second_id: jsonpath "$.id"
[Asserts]
jsonpath "$.link_type" == "external"
jsonpath "$.description" == "B4 described"

GET {{base_url}}/syllabus/level/1
Authorization: {{auth_b4_syl}}
HTTP 200
[Asserts]
jsonpath "$.items[?(@.id=={{new_id}})].sort_order" == 2
jsonpath "$.items[?(@.id=={{second_id}})].subject_name" == "B4 Second"
