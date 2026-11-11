# PUT /admin/syllabus/{syllabus_id} contract: edit a syllabus item (super admin). Runs against any implementation.
# Variables: base_url and auth_<alias>. B4a fixtures: item 9505 (level 2, "B4 Syllabus Put", pdf, sort 1, active, description "B4 put text"), 9508 (deleted), the syllabus admin 900901 (role 1).

# 1. Without sign-in: 401
PUT {{base_url}}/admin/syllabus/9505
{"subject_name": "x"}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Only the super admin
PUT {{base_url}}/admin/syllabus/9505
Authorization: {{auth_en_student}}
{"subject_name": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can access this resource"

# 3. A missing or deleted item is 404
PUT {{base_url}}/admin/syllabus/999999
Authorization: {{auth_b4_syl}}
{"subject_name": "x"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Syllabus item not found"

PUT {{base_url}}/admin/syllabus/9508
Authorization: {{auth_b4_syl}}
{"subject_name": "x"}
HTTP 404

PUT {{base_url}}/admin/syllabus/abc
Authorization: {{auth_b4_syl}}
{"subject_name": "x"}
HTTP 404

# 4. The checks per field, in order; a null counts as not given
PUT {{base_url}}/admin/syllabus/9505
Authorization: {{auth_b4_syl}}
{"subject_name": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "subject_name must be a string"

PUT {{base_url}}/admin/syllabus/9505
Authorization: {{auth_b4_syl}}
{"description": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "description must be a string"

PUT {{base_url}}/admin/syllabus/9505
Authorization: {{auth_b4_syl}}
{"link_type": "doc"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "link_type must be 'pdf' or 'external'"

PUT {{base_url}}/admin/syllabus/9505
Authorization: {{auth_b4_syl}}
{"url": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "url must be a string"

PUT {{base_url}}/admin/syllabus/9505
Authorization: {{auth_b4_syl}}
{"sort_order": "high"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "sort_order must be an integer"

# 5. Nothing to change is 400 (an empty body, or only nulls; the level cannot be changed)
PUT {{base_url}}/admin/syllabus/9505
Authorization: {{auth_b4_syl}}
{}
HTTP 400
[Asserts]
jsonpath "$.detail" == "No fields to update"

PUT {{base_url}}/admin/syllabus/9505
Authorization: {{auth_b4_syl}}
{"subject_name": null, "level_id": 2}
HTTP 400
[Asserts]
jsonpath "$.detail" == "No fields to update"

# 6. A partial edit: sort 0 and an emptied description are given values; the item stays where it was; modified_at is stamped
PUT {{base_url}}/admin/syllabus/9505
Authorization: {{auth_b4_syl}}
{"sort_order": 0, "description": "", "subject_name": ""}
HTTP 200
[Asserts]
jsonpath "$.id" == 9505
jsonpath "$.level_id" == 2
jsonpath "$.sort_order" == 0
jsonpath "$.description" == null
jsonpath "$.subject_name" == ""
jsonpath "$.url" == "https://example.invalid/b4/put.pdf"
jsonpath "$.is_active" == true
jsonpath "$.modified_at" matches /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/

# 7. Every field, is_active by PHP truthiness: the text "false" is on, "0" is off
PUT {{base_url}}/admin/syllabus/9505
Authorization: {{auth_b4_syl}}
{"subject_name": "B4 Edited", "description": "B4 edited text", "link_type": "external", "url": "https://example.invalid/b4/edited", "sort_order": "7", "is_active": "false"}
HTTP 200
[Asserts]
jsonpath "$.subject_name" == "B4 Edited"
jsonpath "$.description" == "B4 edited text"
jsonpath "$.link_type" == "external"
jsonpath "$.url" == "https://example.invalid/b4/edited"
jsonpath "$.sort_order" == 7
jsonpath "$.is_active" == true

PUT {{base_url}}/admin/syllabus/9505
Authorization: {{auth_b4_syl}}
{"is_active": "0"}
HTTP 200
[Asserts]
jsonpath "$.is_active" == false

PUT {{base_url}}/admin/syllabus/9505
Authorization: {{auth_b4_syl}}
{"is_active": []}
HTTP 200
[Asserts]
jsonpath "$.is_active" == false

PUT {{base_url}}/admin/syllabus/9505
Authorization: {{auth_b4_syl}}
{"is_active": true}
HTTP 200
[Asserts]
jsonpath "$.is_active" == true
