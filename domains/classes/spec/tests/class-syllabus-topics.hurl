# GET /classes/{class_id}/syllabus-topics contract: the topic catalogue of the class's level. Runs against any implementation.
# Variables: base_url and auth_<alias>. Fixtures: class 9301 is MIQDAD (the one level with a catalogue), 9302 is BILAL (none).

# 1. Without sign-in: 401
GET {{base_url}}/classes/9301/syllabus-topics
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. No numeric gender: 400. Unknown class: 404. Not in the class: 403
GET {{base_url}}/classes/9301/syllabus-topics
Authorization: {{auth_nogender}}
HTTP 400
[Asserts]
jsonpath "$.detail" == "User gender not set; update profile first"

GET {{base_url}}/classes/999999/syllabus-topics
Authorization: {{auth_student_g}}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Class not found"

GET {{base_url}}/classes/9301/syllabus-topics
Authorization: {{auth_outsider}}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. A student of a MIQDAD class: the three subjects, with their topics and lessons
GET {{base_url}}/classes/9301/syllabus-topics
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
jsonpath "$.*" count == 3
jsonpath "$.arabic.*" count == 2
jsonpath "$.aqaed.*" count == 7
jsonpath "$.ahkam.*" count == 9
jsonpath "$.arabic['Understanding the Holy Quran - Intermediate'][0]" == "Lesson 1"
jsonpath "$.arabic['Understanding the Holy Quran - Intermediate']" count == 18

# 4. A level without a catalogue: an empty object, not a list
GET {{base_url}}/classes/9302/syllabus-topics
Authorization: {{auth_student_l}}
HTTP 200
[Asserts]
body == "{}"
