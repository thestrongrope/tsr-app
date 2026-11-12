# POST /admin/class-access/members/{token}/rules {gender, conditions, reason, version, previewHash} contract: an operator gives a member a class access rule. Runs against any implementation.
# Variables: base_url and auth_grants_<token> (tools/contract-grants.sh). Fixtures: db/synthetic/grants-fixtures.sql (read its header). This file changes members 925041 (the main subject) and 925048 (the note and
# the spelling) only; the guards use 925043 (ladies), 925044 (no gender), 925007 (finance), 925003 / 925001 (the operators themselves) and write nothing.
# PHP's order: sign-in, class-access:manage, body shape (gender, conditions, reason, version, previewHash: 422), then the model: reason, gender range, conditions (422), the member (404), the operator guards
# (own access 422, rule gender 403, member gender 403), offered values (422); then under the member lock: version (409 member_changed), Finance (422), the same access held (409 already_has_access), reaches no class (422),
# the classes changed since the preview (409 preview_changed with the classes now reached).

# 1. Without sign-in: 401. Who may not use the screen: 403
POST {{base_url}}/admin/class-access/members/925041/rules
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 401

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925006}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925008}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 403

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925010}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 403

# 2. The body shape, in order: gender, conditions, reason, version, previewHash
POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": "1", "conditions": "x", "reason": 5, "version": 5, "previewHash": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "gender must be a number"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": "x", "reason": 5, "version": 5, "previewHash": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "conditions must be a list"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": 5, "version": 5, "previewHash": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "reason must be text"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": 5, "previewHash": 5}
HTTP 422
[Asserts]
jsonpath "$.detail" == "version is required"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "", "previewHash": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "version is required"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "previewHash is required"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": ""}
HTTP 422
[Asserts]
jsonpath "$.detail" == "previewHash is required"

# 3. The model's own checks of the input, before the member is looked up
POST {{base_url}}/admin/class-access/members/99999999/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "   ", "version": "x", "previewHash": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A reason is required"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "version": "x", "previewHash": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The reason must be 300 characters or fewer"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 3, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "The gender must be 1 or 2, or left out for either"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose at least one condition"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "negate": true, "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Only conditions that include classes can be added"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "City", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Unknown condition field"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "level", "value": 99999999}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Unknown level"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "level", "value": "2"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A level is a level id"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "c1"}, {"field": "city", "value": "c2"}, {"field": "city", "value": "c3"}, {"field": "city", "value": "c4"}, {"field": "city", "value": "c5"}, {"field": "city", "value": "c6"}, {"field": "city", "value": "c7"}, {"field": "city", "value": "c8"}, {"field": "city", "value": "c9"}, {"field": "city", "value": "c10"}, {"field": "city", "value": "c11"}, {"field": "city", "value": "c12"}, {"field": "city", "value": "c13"}, {"field": "city", "value": "c14"}, {"field": "city", "value": "c15"}, {"field": "city", "value": "c16"}, {"field": "city", "value": "c17"}, {"field": "city", "value": "c18"}, {"field": "city", "value": "c19"}, {"field": "city", "value": "c20"}, {"field": "city", "value": "c21"}, {"field": "city", "value": "c22"}, {"field": "city", "value": "c23"}, {"field": "city", "value": "c24"}, {"field": "city", "value": "c25"}, {"field": "city", "value": "c26"}, {"field": "city", "value": "c27"}, {"field": "city", "value": "c28"}, {"field": "city", "value": "c29"}, {"field": "city", "value": "c30"}, {"field": "city", "value": "c31"}, {"field": "city", "value": "c32"}, {"field": "city", "value": "c33"}, {"field": "city", "value": "c34"}, {"field": "city", "value": "c35"}, {"field": "city", "value": "c36"}, {"field": "city", "value": "c37"}, {"field": "city", "value": "c38"}, {"field": "city", "value": "c39"}, {"field": "city", "value": "c40"}, {"field": "city", "value": "c41"}, {"field": "city", "value": "c42"}, {"field": "city", "value": "c43"}, {"field": "city", "value": "c44"}, {"field": "city", "value": "c45"}, {"field": "city", "value": "c46"}, {"field": "city", "value": "c47"}, {"field": "city", "value": "c48"}, {"field": "city", "value": "c49"}, {"field": "city", "value": "c50"}, {"field": "city", "value": "c51"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Too many values for one condition (at most 50)"

# 4. The member: a guest, a negative, a text and an unknown token are 404
POST {{base_url}}/admin/class-access/members/0/rules
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Member not found"

POST {{base_url}}/admin/class-access/members/-5/rules
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 404

POST {{base_url}}/admin/class-access/members/abc/rules
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 404

POST {{base_url}}/admin/class-access/members/99999999/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Member not found"

# 5. Your own access: 422 for a gents admin and for a super admin (checked before the genders), nothing written
POST {{base_url}}/admin/class-access/members/925003/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Widen my own reach", "version": "x", "previewHash": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "You cannot change your own access"

POST {{base_url}}/admin/class-access/members/925001/rules
Authorization: {{auth_grants_925001}}
{"conditions": [{"field": "city", "value": "GRville"}], "reason": "Widen my own reach", "version": "x", "previewHash": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "You cannot change your own access"

POST {{base_url}}/admin/class-access/members/925003/rules
Authorization: {{auth_grants_925003}}
{"gender": 2, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Widen my own reach", "version": "x", "previewHash": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "You cannot change your own access"

# 6. The other gender, in every direction: a gents admin and a ladies member, a no-gender member, a ladies rule, a rule of either gender; a ladies admin and a gents member; a super admin and a no-gender member: 403
POST {{base_url}}/admin/class-access/members/925043/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This member belongs to the other gender"

POST {{base_url}}/admin/class-access/members/925043/rules
Authorization: {{auth_grants_925003}}
{"gender": 2, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 403

POST {{base_url}}/admin/class-access/members/925044/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This member belongs to the other gender"

POST {{base_url}}/admin/class-access/members/925044/rules
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This member belongs to the other gender"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 2, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This member belongs to the other gender"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This member belongs to the other gender"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925004}}
{"gender": 2, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "This member belongs to the other gender"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925004}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 403

# 7. A value the operator is not offered: 422, after the guards
POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRlady"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose a city from the list"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "tag", "value": "gr-tag-b"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose a tag from the list"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "country", "value": "Grclosedland"}], "reason": "Why", "version": "x", "previewHash": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "Choose a country from the list"

# 8. Nothing so far wrote a rule
GET {{base_url}}/admin/class-access/members/925041
Authorization: {{auth_grants_925003}}
HTTP 200
[Asserts]
jsonpath "$.rules" count == 0
jsonpath "$.version" matches "^0:[0-9a-f]{16}$"
[Captures]
v0: jsonpath "$.version"

# 9. Under the lock: a stale version is 409 member_changed (before anything about the classes)
POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "0:0000000000000000", "previewHash": "x"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "This member was just changed by someone else. Open them again to see the current access."
jsonpath "$.code" == "member_changed"
jsonpath "$.*" count == 2

# 10. A Finance member cannot be made a class admin; the same access twice is 409; a rule that reaches no class is 422
GET {{base_url}}/admin/class-access/members/925007
Authorization: {{auth_grants_925001}}
HTTP 200
[Captures]
vfin: jsonpath "$.version"

POST {{base_url}}/admin/class-access/members/925007/rules
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "{{vfin}}", "previewHash": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "A Finance member cannot be made a class admin"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}, {"field": "level", "value": 4}], "reason": "Why", "version": "{{v0}}", "previewHash": "x"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "This access reaches no class"

# 11. The classes shown are not the classes now reached: 409 preview_changed, with the classes now reached, their count and the hash to send
POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}], "reason": "Why", "version": "{{v0}}", "previewHash": "0000000000000000"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "The classes changed since the preview"
jsonpath "$.code" == "preview_changed"
jsonpath "$.classCount" == 2
jsonpath "$.classes" count == 2
jsonpath "$.classes[0].id" == 98501
jsonpath "$.classes[1].id" == 98502
jsonpath "$.classes[0].*" count == 3
jsonpath "$.previewHash" matches "^[0-9a-f]{16}$"
jsonpath "$.*" count == 5
[Captures]
ville_hash: jsonpath "$.previewHash"

# 12. The preview the operator sees is the hash the save wants
POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}]}
HTTP 200
[Asserts]
jsonpath "$.previewHash" == "{{ville_hash}}"

# 13. The grant: 200 {saved: true} and the refreshed member view. The reason is trimmed; the role 0 becomes 5 (the version starts with 5)
POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "grville"}], "reason": "  Teaches in GRville  ", "version": "{{v0}}", "previewHash": "{{ville_hash}}"}
HTTP 200
[Asserts]
jsonpath "$.*" count == 5
jsonpath "$.saved" == true
jsonpath "$.member.token" == 925041
jsonpath "$.member.gender" == 1
jsonpath "$.version" matches "^5:[0-9a-f]{16}$"
jsonpath "$.fromRole" == null
jsonpath "$.rules" count == 1
jsonpath "$.rules[0].gender" == 1
jsonpath "$.rules[0].note" == "Gents, GRville"
jsonpath "$.rules[0].conditions" count == 1
jsonpath "$.rules[0].conditions[0].field" == "city"
jsonpath "$.rules[0].conditions[0].negate" == false
jsonpath "$.rules[0].conditions[0].value" == "GRville"
jsonpath "$.rules[0].classCount" == 2
jsonpath "$.rules[0].classes[0].id" == 98501
jsonpath "$.rules[0].classes[1].id" == 98502
[Captures]
v1: jsonpath "$.version"
rule1: jsonpath "$.rules[0].id"

# 14. The same view when read again
GET {{base_url}}/admin/class-access/members/925041
Authorization: {{auth_grants_925003}}
HTTP 200
[Asserts]
jsonpath "$.version" == "{{v1}}"
jsonpath "$.rules" count == 1
jsonpath "$.rules[0].id" == {{rule1}}

# 15. At once: the member is a class admin (role 5) on their very next request (the assigned scope the rule gives is read on the new API only: class-access-grant-new-api.hurl; the parity database still reads the legacy class_access table)

GET {{base_url}}/user/permissions
Authorization: {{auth_grants_925041}}
HTTP 200
[Asserts]
jsonpath "$.role_id" == 5

# 16. The same access again is 409 already_has_access (the same gender and the same set of conditions, in any case); the old version is now stale
POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRVILLE"}], "reason": "Again", "version": "{{v1}}", "previewHash": "{{ville_hash}}"}
HTTP 409
[Asserts]
jsonpath "$.detail" == "This member already has this access"
jsonpath "$.code" == "already_has_access"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRother"}], "reason": "Stale", "version": "{{v0}}", "previewHash": "x"}
HTTP 409
[Asserts]
jsonpath "$.code" == "member_changed"

# 17. A second rule of another gender's reach on the same member is a second rule; the role stays 5 and the version changes. A super admin may give a rule of either gender
POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRother"}]}
HTTP 200
[Captures]
other_hash: jsonpath "$.previewHash"

POST {{base_url}}/admin/class-access/members/925041/rules
Authorization: {{auth_grants_925003}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRother"}], "reason": "Second", "version": "{{v1}}", "previewHash": "{{other_hash}}"}
HTTP 200
[Asserts]
jsonpath "$.rules" count == 2
jsonpath "$.rules[1].note" == "Gents, GRother"
jsonpath "$.rules[1].classCount" == 1
jsonpath "$.version" matches "^5:[0-9a-f]{16}$"
jsonpath "$.version" != "{{v1}}"

# 18. A subset of an access already held is a different access (the key is the whole set): level 2 in GRville on top of GRville
POST {{base_url}}/admin/class-access/members/925048/rules
Authorization: {{auth_grants_925001}}
{"conditions": [{"field": "city", "value": "GRville"}], "reason": "Either gender", "version": "0:0000000000000000", "previewHash": "x"}
HTTP 409
[Asserts]
jsonpath "$.code" == "member_changed"

GET {{base_url}}/admin/class-access/members/925048
Authorization: {{auth_grants_925001}}
HTTP 200
[Captures]
v48: jsonpath "$.version"

POST {{base_url}}/admin/class-access/preview
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}, {"field": "level", "value": 3}, {"field": "level", "value": 2}, {"field": "city", "value": "grville"}]}
HTTP 200
[Asserts]
jsonpath "$.classCount" == 2
[Captures]
note_hash: jsonpath "$.previewHash"

POST {{base_url}}/admin/class-access/members/925048/rules
Authorization: {{auth_grants_925001}}
{"gender": 1, "conditions": [{"field": "city", "value": "GRville"}, {"field": "level", "value": 3}, {"field": "level", "value": 2}, {"field": "city", "value": "grville"}], "reason": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "version": "{{v48}}", "previewHash": "{{note_hash}}"}
HTTP 200
[Asserts]
jsonpath "$.rules[0].note" == "Gents, levels 2-3, GRville"
jsonpath "$.rules[0].conditions" count == 3
jsonpath "$.rules[0].conditions[0].field" == "city"
jsonpath "$.rules[0].conditions[0].value" == "GRville"
jsonpath "$.rules[0].conditions[1].field" == "level"
jsonpath "$.rules[0].conditions[1].value" == 2
jsonpath "$.rules[0].conditions[2].value" == 3
jsonpath "$.rules[0].classCount" == 2
