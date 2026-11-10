# POST /geo/postal contract: {country, code} -> {found, city, state}. Signed in, no permission, rate limited.
# Runs against any implementation. Variables: base_url, auth_header, auth_value. Rows: db/synthetic/geo-fixtures.sql.
# See geo-countries.hurl for the rate limit budget (this file makes 18 counted calls).

# 1. Without sign-in: 401
POST {{base_url}}/geo/postal
Content-Type: application/json
{"country": "CH", "code": "8001"}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A known code: found, with the stored city and state (raw, accents kept)
POST {{base_url}}/geo/postal
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "CH", "code": "8001"}
HTTP 200
[Asserts]
jsonpath "$.found" == true
jsonpath "$.city" == "Zürich"
jsonpath "$.state" == "Zürich"

# 3. The length is measured BEFORE the trim: " ch" is 3 characters, so it is refused even though it is "ch" trimmed
POST {{base_url}}/geo/postal
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": " ch", "code": "  8001 "}
HTTP 422
[Asserts]
jsonpath "$.detail" == "country is required and must be at most 2 characters"

# 4. Case and surrounding spaces do not matter (code: 7 characters, within its 20)
POST {{base_url}}/geo/postal
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "ch", "code": "  8001 "}
HTTP 200
[Asserts]
jsonpath "$.found" == true
jsonpath "$.city" == "Zürich"

# 5. A full code with a space that is not stored falls back to the part before the space (UK outward code)
POST {{base_url}}/geo/postal
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "GB", "code": "sw1a 2aa"}
HTTP 200
[Asserts]
jsonpath "$.found" == true
jsonpath "$.city" == "Westminster"
jsonpath "$.state" == "England"

# 6. When the full code is stored it wins over the outward part
POST {{base_url}}/geo/postal
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "GB", "code": "EC1A 1BB"}
HTTP 200
[Asserts]
jsonpath "$.city" == "City of London"

# 7. ... and a different full code with the same outward part gets the outward row
POST {{base_url}}/geo/postal
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "GB", "code": "EC1A 9ZZ"}
HTTP 200
[Asserts]
jsonpath "$.city" == "Clerkenwell"

# 8. A code stored with a space is found by its whole form, in any case
POST {{base_url}}/geo/postal
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "IE", "code": "d02 xy45"}
HTTP 200
[Asserts]
jsonpath "$.city" == "Dublin"
jsonpath "$.state" == "Leinster"

# 9. A NULL state is null; a NULL city is null
POST {{base_url}}/geo/postal
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "AL", "code": "1001"}
HTTP 200
[Asserts]
jsonpath "$.found" == true
jsonpath "$.city" == "Tirana"
jsonpath "$.state" == null

POST {{base_url}}/geo/postal
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "AL", "code": "1002"}
HTTP 200
[Asserts]
jsonpath "$.city" == null
jsonpath "$.state" == "Tirana County"

# 10. Empty strings stay empty strings (only a NULL is null)
POST {{base_url}}/geo/postal
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "AL", "code": "1003"}
HTTP 200
[Asserts]
jsonpath "$.found" == true
jsonpath "$.city" == ""
jsonpath "$.state" == ""

# 11. A code of exactly "0" is never looked up, even though a row with that code exists
POST {{base_url}}/geo/postal
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "CH", "code": "0"}
HTTP 200
[Asserts]
jsonpath "$.found" == false
jsonpath "$.city" == null
jsonpath "$.state" == null

# 12. An unknown country is "not found", not an error
POST {{base_url}}/geo/postal
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "ZZ", "code": "8001"}
HTTP 200
[Asserts]
jsonpath "$.found" == false
jsonpath "$.city" == null
jsonpath "$.state" == null

# 13. Validation: country is checked first, then code; each is a 422 with the field in the detail
POST {{base_url}}/geo/postal
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "CHE", "code": "8001"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "country is required and must be at most 2 characters"

POST {{base_url}}/geo/postal
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "CH", "code": "   "}
HTTP 422
[Asserts]
jsonpath "$.detail" == "code is required and must be at most 20 characters"

POST {{base_url}}/geo/postal
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "CH", "code": 8001}
HTTP 422
[Asserts]
jsonpath "$.detail" == "code is required and must be at most 20 characters"

# 14. A body that is not a JSON object is "Invalid JSON body"
POST {{base_url}}/geo/postal
Content-Type: application/json
{{auth_header}}: {{auth_value}}
"just a string"
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

# NUL inside the code: nothing stored holds one, so not found (200), never an error
POST {{base_url}}/geo/postal
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "CH", "code": "80\u00001"}
HTTP 200
[Asserts]
jsonpath "$.found" == false

# A lone surrogate in a nested value fails the whole body, as PHP's json_decode does
POST {{base_url}}/geo/postal
Content-Type: application/json
{{auth_header}}: {{auth_value}}
```
{"country": "CH", "code": "8001", "extra": {"x": ["\ud800"]}}
```
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"
