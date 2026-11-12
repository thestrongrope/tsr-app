# What only the new API does on GET /search: a NUL byte inside q is 422 (PHP answers 200 and puts every kind in `unavailable`: the text goes to the index). New API only.
# Variables: base_url, auth_edge_search (super admin).

GET {{base_url}}/search?q=ab%00cd
Authorization: {{auth_edge_search}}
HTTP 422
[Asserts]
jsonpath "$.detail" == "q must not contain NUL characters"
