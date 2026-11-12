# POST /admin/class-access/preview {gender, conditions} contract: the active classes a rule would reach, and the hash a save must echo. Writes nothing. Runs against any implementation.
# Variables: base_url and auth_grants_<token> (tools/contract-grants.sh). Fixtures: db/synthetic/grants-fixtures.sql (read its header): gents classes 98501 (GRville, level 2, tag gr-tag-a), 98502 (GRville, level 3, gr-tag-a),
# 98503 (GRother, level 2), ladies 98505 (GRville, level 2, gr-tag-b), 98506 (GRlady, level 4); 98504 (GRville, level 2) is CLOSED and never reached. Only the classes with ids 98501 to 98506 are looked at: other lanes' classes share the database.
# Order as PHP: sign-in, class-access:manage, gender a whole number (422), conditions a list (422), then the model: gender 1 or 2 or left out (422), each condition valid (422), the rule's gender manageable (403), each city, country and tag offered (422).

# 1. Without sign-in: 401
POST {{base_url}}/admin/class-access/preview
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}]}
HTTP 401

# 2. Who may not use the screen: 403
POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925006}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}]}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925008}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}]}
HTTP 403

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925010}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}]}
HTTP 403

# 3. The body: gender a whole number, conditions a list of objects
POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": "1", "conditions": [{"field": "city", "value": "GRville"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "gender must be a number"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1.5, "conditions": [{"field": "city", "value": "GRville"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "gender must be a number"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": [1], "conditions": [{"field": "city", "value": "GRville"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "gender must be a number"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1}
HTTP 422
[Asserts]
jsonpath "$.detail" == "conditions must be a list"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": "city"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "conditions must be a list"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": {"field": "city", "value": "GRville"}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "conditions must be a list"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": ["city"]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Each condition needs a field"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": 7, "value": "GRville"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Each condition needs a field"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "negate": "no", "value": "GRville"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "negate must be true or false"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Each condition needs a value"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": 1.5}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Each condition needs a value"

# 4. The rule: gender 1 or 2 or left out; at least one condition; known fields only (case-sensitive); includes only; levels are whole ids that exist; values text of 1 to 300 characters; at most 50 per field
POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 0, "conditions": [{"field": "city", "value": "GRville"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The gender must be 1 or 2, or left out for either"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 3, "conditions": [{"field": "city", "value": "GRville"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The gender must be 1 or 2, or left out for either"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": []}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose at least one condition"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "State", "value": "x"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Unknown condition field"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "City", "value": "GRville"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Unknown condition field"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "negate": true, "value": "GRville"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Only conditions that include classes can be added"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "level", "value": "2"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A level is a level id"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "level", "value": 0}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A level is a level id"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "level", "value": -2}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A level is a level id"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "level", "value": 99999999}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Unknown level"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "   "}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A condition needs a value"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A condition value must be 300 characters or fewer"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "c1"}, {"field": "city", "value": "c2"}, {"field": "city", "value": "c3"}, {"field": "city", "value": "c4"}, {"field": "city", "value": "c5"}, {"field": "city", "value": "c6"}, {"field": "city", "value": "c7"}, {"field": "city", "value": "c8"}, {"field": "city", "value": "c9"}, {"field": "city", "value": "c10"}, {"field": "city", "value": "c11"}, {"field": "city", "value": "c12"}, {"field": "city", "value": "c13"}, {"field": "city", "value": "c14"}, {"field": "city", "value": "c15"}, {"field": "city", "value": "c16"}, {"field": "city", "value": "c17"}, {"field": "city", "value": "c18"}, {"field": "city", "value": "c19"}, {"field": "city", "value": "c20"}, {"field": "city", "value": "c21"}, {"field": "city", "value": "c22"}, {"field": "city", "value": "c23"}, {"field": "city", "value": "c24"}, {"field": "city", "value": "c25"}, {"field": "city", "value": "c26"}, {"field": "city", "value": "c27"}, {"field": "city", "value": "c28"}, {"field": "city", "value": "c29"}, {"field": "city", "value": "c30"}, {"field": "city", "value": "c31"}, {"field": "city", "value": "c32"}, {"field": "city", "value": "c33"}, {"field": "city", "value": "c34"}, {"field": "city", "value": "c35"}, {"field": "city", "value": "c36"}, {"field": "city", "value": "c37"}, {"field": "city", "value": "c38"}, {"field": "city", "value": "c39"}, {"field": "city", "value": "c40"}, {"field": "city", "value": "c41"}, {"field": "city", "value": "c42"}, {"field": "city", "value": "c43"}, {"field": "city", "value": "c44"}, {"field": "city", "value": "c45"}, {"field": "city", "value": "c46"}, {"field": "city", "value": "c47"}, {"field": "city", "value": "c48"}, {"field": "city", "value": "c49"}, {"field": "city", "value": "c50"}, {"field": "city", "value": "c51"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Too many values for one condition (at most 50)"

# 5. A gender admin: the rule's gender must be one they manage (a rule of either gender needs both), after the conditions are valid
POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925003}}
{"gender": 2, "conditions": [{"field": "city", "value": "GRville"}]}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This member belongs to the other gender"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925003}}
{"conditions": [{"field": "city", "value": "GRville"}]}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This member belongs to the other gender"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925003}}
{"gender": null, "conditions": [{"field": "city", "value": "GRville"}]}
HTTP 403

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925004}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}]}
HTTP 403

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925003}}
{"gender": 2, "conditions": [{"field": "State", "value": "x"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Unknown condition field"

# 6. A city, country or tag the operator is not offered: 422. A value only the other gender's classes have, one that exists nowhere, and one only a closed class has
POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRlady"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose a city from the list"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "Nowhereville"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose a city from the list"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRclosed"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose a city from the list"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "country", "value": "Grclosedland"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose a country from the list"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "tag", "value": "gr-tag-b"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose a tag from the list"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925004}}
{"gender": 2, "conditions": [{"field": "city", "value": "GRother"}]}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose a city from the list"

# 7. A super admin: gents in GRville are the two active classes (the closed 98504 is not reached); the answer holds classes, classCount and previewHash
POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}]}
HTTP 200
[Asserts]
jsonpath "$.*" count == 3
jsonpath "$.classCount" == 2
jsonpath "$.classes" count == 2
jsonpath "$.classes[0].id" == 98501
jsonpath "$.classes[0].code" == "GR-G-501"
jsonpath "$.classes[0].name" == "Gr Class One"
jsonpath "$.classes[0].*" count == 3
jsonpath "$.classes[1].id" == 98502
jsonpath "$.classes[?(@.id==98504)]" not exists
jsonpath "$.previewHash" matches "^[0-9a-f]{16}$"
[Captures]
gents_ville_hash: jsonpath "$.previewHash"

# 8. The same set by other conditions has the same hash; a level on top narrows (fields are ANDed); two values of one field are ORed; the offered spelling is used for a typed one
POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "tag", "value": "GR-TAG-A"}]}
HTTP 200
[Asserts]
jsonpath "$.classCount" == 2
jsonpath "$.previewHash" == "{{gents_ville_hash}}"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "grville"}, {"field": "city", "value": "GRVILLE"}]}
HTTP 200
[Asserts]
jsonpath "$.classCount" == 2
jsonpath "$.previewHash" == "{{gents_ville_hash}}"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}, {"field": "level", "value": 2}]}
HTTP 200
[Asserts]
jsonpath "$.classCount" == 1
jsonpath "$.classes[0].id" == 98501

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "level", "value": 2}, {"field": "city", "value": "GRville"}]}
HTTP 200
[Asserts]
jsonpath "$.classCount" == 1

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}, {"field": "city", "value": "GRother"}]}
HTTP 200
[Asserts]
jsonpath "$.classCount" == 3
jsonpath "$.classes[2].id" == 98503

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "country", "value": "grland"}]}
HTTP 200
[Asserts]
jsonpath "$.classCount" == 3

# 9. The gender of the rule narrows the classes: ladies, and either gender (which reaches both)
POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925004}}
{"gender": 2, "conditions": [{"field": "city", "value": "GRville"}]}
HTTP 200
[Asserts]
jsonpath "$.classCount" == 1
jsonpath "$.classes[0].id" == 98505

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"conditions": [{"field": "city", "value": "GRville"}]}
HTTP 200
[Asserts]
jsonpath "$.classCount" == 3
jsonpath "$.classes[2].id" == 98505

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": null, "conditions": [{"field": "city", "value": "GRville"}]}
HTTP 200
[Asserts]
jsonpath "$.classCount" == 3

# 10. A rule that reaches no class is a preview of nothing (200, count 0), not an error: a level only a ladies class has, gents
POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}, {"field": "level", "value": 4}]}
HTTP 200
[Asserts]
jsonpath "$.classCount" == 0
jsonpath "$.classes" count == 0
jsonpath "$.previewHash" matches "^[0-9a-f]{16}$"

# 11. A level is NOT limited to the operator's cities (finding 11): a gents admin previews level 2 and reaches gents classes of level 2 in every city
POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "level", "value": 2}]}
HTTP 200
[Asserts]
jsonpath "$.classes[?(@.id==98501)]" exists
jsonpath "$.classes[?(@.id==98503)]" exists
jsonpath "$.classes[?(@.id==98504)]" not exists
jsonpath "$.classes[?(@.id==98505)]" not exists
