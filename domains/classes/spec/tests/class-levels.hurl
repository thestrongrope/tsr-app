# GET /class-levels contract: 2 cases, one file per slice. Runs against any implementation.
# Variables: base_url, auth_header, auth_value (a token is never written into this file). Synthetic members only.
#   hurl --test --variable base_url=http://localhost:8089 --variables-file build/test/token.vars class-levels.hurl
# (tools/identity-contract.sh test writes build/test/token.vars; PHP parity: build/parity-php/token.vars.)

# 1. Without sign-in: 401 with a detail
GET {{base_url}}/class-levels
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A signed-in member gets the levels: id, code and name, nothing else
GET {{base_url}}/class-levels
{{auth_header}}: {{auth_value}}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$" count >= 1
jsonpath "$[0].id" isInteger
jsonpath "$[0].code" isString
jsonpath "$[0].name" isString
jsonpath "$[0].sort_order" not exists
jsonpath "$[0].sortOrder" not exists

# The synthetic seed holds five levels with sort_order 1 to 5 (db/synthetic/schema-phase-fixtures.sql): order is sort_order, then id
jsonpath "$[0].code" == "BIL"
jsonpath "$[1].code" == "AMM"
jsonpath "$[2].code" == "MIQ"
jsonpath "$[3].code" == "ABU"
jsonpath "$[4].code" == "SAL"
jsonpath "$[4].id" == 5

