# The API's whole route surface, spot-checked on the running stack: PHP's router answers for a path or verb it does not know,
# and the paths that were the last placeholders. No placeholder is left: every operation in docs/specs/initial-build/operations.csv
# is "built" (a "planned" one would sign the caller in and answer 501 {"detail": "Not implemented"}; hosts/api/tests checks that
# none is mapped). New API only: the 404 fallback and the 405 texts are the gateway's and the API's.
# Cross-domain, so it lives here and not in a domain's spec/tests. Variables: base_url, auth_header, auth_value.
#   hurl --test --variable base_url=http://localhost:8088 --variables-file build/dev/token.vars \
#        hosts/api/spec/planned-surface.hurl
# Every contract file at once: see CLAUDE.md, Commands. Synthetic members only.

# classes: the last placeholders (GET /me/guides and /me/guides/{slug}) are built; signed in, the path no longer answers 501
# (403 for a member who neither studies nor teaches, 404 for an unknown slug: domains/classes/spec/tests/me-guide.hurl)
GET {{base_url}}/me/guides/a-slug
{{auth_header}}: {{auth_value}}
HTTP *
[Asserts]
status != 501
jsonpath "$.detail" != "Not implemented"

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

# A path no route knows: the gateway's fallback answers (the API's own "Not Found" is tested in hosts/api/tests)
GET {{base_url}}/no/such/path
HTTP 404
[Asserts]
jsonpath "$.detail" matches /\S/
