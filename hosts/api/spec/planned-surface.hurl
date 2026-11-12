# The API's whole route surface, spot-checked on the running stack: one placeholder route per domain, plus PHP's router
# answers for a path or verb it does not know. A placeholder (state "planned" in docs/specs/initial-build/operations.csv)
# signs the caller in and answers 501 {"detail": "Not implemented"}. When the slice behind one of these is built, point
# its line at another planned route of the same domain. New API only: PHP has no 501.
# Cross-domain, so it lives here and not in a domain's spec/tests. Variables: base_url, auth_header, auth_value.
#   hurl --test --variable base_url=http://localhost:8088 --variables-file build/dev/token.vars \
#        hosts/api/spec/planned-surface.hurl
# Every contract file at once: see CLAUDE.md, Commands. Synthetic members only.

# identity (member route)
GET {{base_url}}/me/deletion-request
{{auth_header}}: {{auth_value}}
HTTP 501
[Asserts]
jsonpath "$.detail" == "Not implemented"

# identity (public route: no token needed)
POST {{base_url}}/auth/debug-token
Content-Type: application/json
{}
HTTP 501
[Asserts]
jsonpath "$.detail" == "Not implemented"

# access
GET {{base_url}}/admin/permissions/members
{{auth_header}}: {{auth_value}}
HTTP 501
[Asserts]
jsonpath "$.detail" == "Not implemented"

# platform
GET {{base_url}}/admin/access-log
{{auth_header}}: {{auth_value}}
HTTP 501
[Asserts]
jsonpath "$.detail" == "Not implemented"

# classes (a path with parameters: any non-slash segment)
GET {{base_url}}/me/guides/a-slug
{{auth_header}}: {{auth_value}}
HTTP 501
[Asserts]
jsonpath "$.detail" == "Not implemented"

# assessment
GET {{base_url}}/mcq/manage/900009/scores
{{auth_header}}: {{auth_value}}
HTTP 501
[Asserts]
jsonpath "$.detail" == "Not implemented"

# notifications
POST {{base_url}}/devices
{{auth_header}}: {{auth_value}}
Content-Type: application/json
{}
HTTP 501
[Asserts]
jsonpath "$.detail" == "Not implemented"

# content
GET {{base_url}}/holy-quran
{{auth_header}}: {{auth_value}}
HTTP 501
[Asserts]
jsonpath "$.detail" == "Not implemented"

# search has no placeholder left (GET /search is built); its path still answers 401 without a sign-in
GET {{base_url}}/search
HTTP 401
[Asserts]
jsonpath "$.detail" == "Not authenticated"

# A known path with another verb: 405 in the detail envelope, even without a token
PUT {{base_url}}/search
Content-Type: application/json
{}
HTTP 405
[Asserts]
jsonpath "$.detail" == "Method Not Allowed"

# A built route is not a placeholder: its path with an unrouted verb is 405 too
POST {{base_url}}/health
Content-Type: application/json
{}
HTTP 405
[Asserts]
jsonpath "$.detail" == "Method Not Allowed"

# A planned literal path under a class (a path with parameters answers 501 the same way)
POST {{base_url}}/classes/1/mcq
{{auth_header}}: {{auth_value}}
Content-Type: application/json
{}
HTTP 501
[Asserts]
jsonpath "$.detail" == "Not implemented"

# A path no route knows: the gateway's fallback answers (the API's own "Not Found" is tested in hosts/api/tests)
GET {{base_url}}/no/such/path
HTTP 404
[Asserts]
jsonpath "$.detail" matches /\S/
