# DELETE /admin/syllabus/{syllabus_id} contract: soft-delete a syllabus item (super admin). Runs against any implementation.
# Variables: base_url and auth_<alias>. B4a fixtures: item 9507 (level 2, active), 9508 (already deleted), the syllabus admin 900901 (role 1).

# 1. Without sign-in: 401
DELETE {{base_url}}/admin/syllabus/9507
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. Only the super admin
DELETE {{base_url}}/admin/syllabus/9507
Authorization: {{auth_en_student}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "Only super admins can access this resource"

# 3. A missing or already deleted item is 404 (the text differs from the edit's)
DELETE {{base_url}}/admin/syllabus/999999
Authorization: {{auth_b4_syl}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Syllabus not found"

DELETE {{base_url}}/admin/syllabus/9508
Authorization: {{auth_b4_syl}}
HTTP 404

# 4. The delete answers 200 {success: true}; the item leaves the level's list; a second delete is 404
GET {{base_url}}/syllabus/level/2
Authorization: {{auth_b4_syl}}
HTTP 200
[Asserts]
jsonpath "$.items[?(@.id==9507)].subject_name" == "B4 Syllabus Delete"

DELETE {{base_url}}/admin/syllabus/9507
Authorization: {{auth_b4_syl}}
HTTP 200
[Asserts]
jsonpath "$.success" == true

GET {{base_url}}/syllabus/level/2
Authorization: {{auth_b4_syl}}
HTTP 200
[Asserts]
jsonpath "$.items[?(@.id==9507)]" not exists

DELETE {{base_url}}/admin/syllabus/9507
Authorization: {{auth_b4_syl}}
HTTP 404
