# POST /geo/cities contract: {country, query} -> {cities: [{name, state}]}, a prefix search, biggest first, at most 10.
# Signed in, no permission, rate limited. Runs against any implementation. Variables: base_url, auth_header, auth_value.
# Rows: db/synthetic/geo-fixtures.sql. See geo-countries.hurl for the rate limit budget (this file makes 17 counted calls).

# 1. Without sign-in: 401
POST {{base_url}}/geo/cities
Content-Type: application/json
{"country": "CH", "query": "zur"}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A prefix finds plain and accented names alike, biggest population first
POST {{base_url}}/geo/cities
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "CH", "query": "zur"}
HTTP 200
[Asserts]
header "Content-Type" startsWith "application/json"
jsonpath "$.cities" count == 3
jsonpath "$.cities[0].name" == "Zürich"
jsonpath "$.cities[0].state" == "Zürich"
jsonpath "$.cities[1].name" == "Zurich West"
jsonpath "$.cities[2].name" == "Zürs"
jsonpath "$.cities[2].state" == "Vorarlberg"
jsonpath "$.cities[0].*" count == 2

# 3. An accented query finds the same, in any case; the country is case-insensitive too
POST {{base_url}}/geo/cities
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "ch", "query": " ZÜR"}
HTTP 200
[Asserts]
jsonpath "$.cities" count == 3
jsonpath "$.cities[0].name" == "Zürich"

# 4. "zu" also finds Zug (30,000) between Zürich (400,000) and Zurich West (1,000)
POST {{base_url}}/geo/cities
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "CH", "query": "zu"}
HTTP 200
[Asserts]
jsonpath "$.cities[0].name" == "Zürich"
jsonpath "$.cities[1].name" == "Zug"
jsonpath "$.cities[2].name" == "Zurich West"
jsonpath "$.cities[3].name" == "Zürs"

# 5. Equal populations are ordered by name
POST {{base_url}}/geo/cities
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "CH", "query": "Ze"}
HTTP 200
[Asserts]
jsonpath "$.cities" count == 2
jsonpath "$.cities[0].name" == "Zell"
jsonpath "$.cities[1].name" == "Zeller"

# 6. Accent-insensitive in both directions: "kol" finds Köln and Kolbermoor, "koln" finds Köln only
POST {{base_url}}/geo/cities
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "DE", "query": "kol"}
HTTP 200
[Asserts]
jsonpath "$.cities" count == 2
jsonpath "$.cities[0].name" == "Köln"
jsonpath "$.cities[1].name" == "Kolbermoor"

POST {{base_url}}/geo/cities
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "DE", "query": "koln"}
HTTP 200
[Asserts]
jsonpath "$.cities" count == 1
jsonpath "$.cities[0].name" == "Köln"

# 7. "%", "_" and "|" in the query are literal characters, not wildcards
POST {{base_url}}/geo/cities
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "ZZ", "query": "100%"}
HTTP 200
[Asserts]
jsonpath "$.cities" count == 1
jsonpath "$.cities[0].name" == "100% Pure"

POST {{base_url}}/geo/cities
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "ZZ", "query": "a_b"}
HTTP 200
[Asserts]
jsonpath "$.cities" count == 1
jsonpath "$.cities[0].name" == "a_b"

POST {{base_url}}/geo/cities
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "ZZ", "query": "pipe|"}
HTTP 200
[Asserts]
jsonpath "$.cities" count == 1
jsonpath "$.cities[0].name" == "Pipe|Town"

# 8. HTML entities in stored names are decoded; an empty state is null; a NULL state is null
POST {{base_url}}/geo/cities
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "ZZ", "query": "Ben &"}
HTTP 200
[Asserts]
jsonpath "$.cities[0].name" == "Ben & Jerry's"
jsonpath "$.cities[0].state" == "Delta"

POST {{base_url}}/geo/cities
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "ZZ", "query": "rock"}
HTTP 200
[Asserts]
jsonpath "$.cities[0].name" == "Rock 'n Roll"
jsonpath "$.cities[0].state" == null

POST {{base_url}}/geo/cities
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "ZZ", "query": "ottawa"}
HTTP 200
[Asserts]
jsonpath "$.cities[0].state" == null

# 9. The same name in three states is returned three times, biggest first
POST {{base_url}}/geo/cities
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "US", "query": "spring"}
HTTP 200
[Asserts]
jsonpath "$.cities" count == 3
jsonpath "$.cities[0].state" == "Missouri"
jsonpath "$.cities[1].state" == "Massachusetts"
jsonpath "$.cities[2].state" == "Illinois"

# 10. At most 10 cities, however many match (12 rows start with "Limit")
POST {{base_url}}/geo/cities
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "LM", "query": "limit"}
HTTP 200
[Asserts]
jsonpath "$.cities" count == 10
jsonpath "$.cities[0].name" == "Limit 01"
jsonpath "$.cities[9].name" == "Limit 10"

# 11. Nothing found, or an unknown country, is an empty list, not an error
POST {{base_url}}/geo/cities
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "XX", "query": "zur"}
HTTP 200
[Asserts]
jsonpath "$.cities" count == 0

# 12. Validation: country is checked first, then query
POST {{base_url}}/geo/cities
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": 7, "query": "zur"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "country is required and must be at most 2 characters"

POST {{base_url}}/geo/cities
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "CH"}
HTTP 422
[Asserts]
jsonpath "$.detail" == "query is required and must be at most 100 characters"

# NUL inside the query: no city name holds one, so an empty list (200), never an error
POST {{base_url}}/geo/cities
Content-Type: application/json
{{auth_header}}: {{auth_value}}
{"country": "CH", "query": "z\u0000r"}
HTTP 200
[Asserts]
jsonpath "$.cities" count == 0
