# GET /geo/countries contract: signed in, no permission, rate limited.
# Runs against any implementation. Variables: base_url, auth_header, auth_value (a token is never written into this file).
# The rows are db/synthetic/geo-fixtures.sql, loaded identically into the dev stack and the PHP parity stack.
# One member may make 60 geo calls a minute (and a refused one still counts): the three geo files together use about 30,
# so run them again after a minute rather than twice in a row. The 429 itself is a unit test, not Hurl.
# Run all platform contracts on one side: tools/platform-contract.sh dev|parity

# 1. Without sign-in: 401 with a detail (this call is refused before the rate limit, so it is not counted)
GET {{base_url}}/geo/countries
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A signed-in member gets every country, sorted by name ignoring case AND accents
GET {{base_url}}/geo/countries
{{auth_header}}: {{auth_value}}
HTTP 200
[Asserts]
header "Content-Type" startsWith "application/json"
jsonpath "$.countries" count == 8
jsonpath "$.countries[0].name" == "Afghanistan"
# "Åland Islands" sorts between Afghanistan and Albania, as if it were "Aland"
jsonpath "$.countries[1].code" == "AX"
jsonpath "$.countries[1].name" == "Åland Islands"
jsonpath "$.countries[2].name" == "Albania"
jsonpath "$.countries[3].name" == "Colombia"
# "Côte d'Ivoire" sorts among the C names, not after Z
jsonpath "$.countries[4].name" == "Côte d'Ivoire"
jsonpath "$.countries[5].name" == "Cuba"
jsonpath "$.countries[6].name" == "Switzerland"
jsonpath "$.countries[7].name" == "United Kingdom"
# each entry is exactly code, name, hasPostalCodes (a real boolean)
jsonpath "$.countries[0].code" == "AF"
jsonpath "$.countries[0].hasPostalCodes" == false
jsonpath "$.countries[1].hasPostalCodes" == true
jsonpath "$.countries[6].hasPostalCodes" == true
jsonpath "$.countries[0].*" count == 3
