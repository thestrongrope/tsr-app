# GET /class-levels contract: 2 cases, one file per slice. Runs against any implementation.
# Variables: base_url and auth_<alias> (tools/classes-contract.sh signs the fixture members in). Synthetic members only.
#   hurl --test --variable base_url=http://localhost:8089 --variables-file build/test/classes.vars class-levels.hurl

# 1. Without sign-in: 401 with a detail
GET {{base_url}}/class-levels
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A signed-in member gets the levels: id, code and name, nothing else
GET {{base_url}}/class-levels
Authorization: {{auth_student_g}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$" count >= 1
jsonpath "$[0].id" isInteger
jsonpath "$[0].code" isString
jsonpath "$[0].name" isString
jsonpath "$[0].sort_order" not exists
jsonpath "$[0].sortOrder" not exists

# The five levels are PHP's reference data (db/synthetic/classes-fixtures.sql aligns the seed to them): order is sort_order, then id
jsonpath "$[0].code" == "SM"
jsonpath "$[1].code" == "AG"
jsonpath "$[2].code" == "MK"
jsonpath "$[3].code" == "AY"
jsonpath "$[4].code" == "B"
jsonpath "$[4].id" == 5

