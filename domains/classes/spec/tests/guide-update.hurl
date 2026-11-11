# PUT /guides/{level_id} contract: replace a level's English guide. Runs against any implementation.
# Variables: base_url and auth_<alias>. WRITE fixtures (reset by tools/classes-contract.sh): level 2 (ABUZAR) has no guide at the start; the write admin 900331 holds guides:manage.

# 1. Without sign-in: 401
PUT {{base_url}}/guides/2
{"guide": "x"}
HTTP 401
[Asserts]
jsonpath "$.detail" matches /\S/

# 2. A member without guides:manage: 403
PUT {{base_url}}/guides/2
Authorization: {{auth_student_g}}
{"guide": "x"}
HTTP 403
[Asserts]
jsonpath "$.detail" == "You do not have permission to do that"

# 3. A level without a guide page (1, 6, text): 404 before the body
PUT {{base_url}}/guides/1
Authorization: {{auth_wr_admin}}
{"guide": "x"}
HTTP 404
[Asserts]
jsonpath "$.detail" == "Level not found"

PUT {{base_url}}/guides/abc
Authorization: {{auth_wr_admin}}
{}
HTTP 404

# 4. The body (422)
PUT {{base_url}}/guides/2
Authorization: {{auth_wr_admin}}
Content-Type: application/json
```
{"guide":
```
HTTP 422
[Asserts]
jsonpath "$.detail" == "Invalid JSON body"

PUT {{base_url}}/guides/2
Authorization: {{auth_wr_admin}}
{}
HTTP 422
[Asserts]
jsonpath "$.detail" == "guide must be the guide text"

PUT {{base_url}}/guides/2
Authorization: {{auth_wr_admin}}
{"guide": "  \n "}
HTTP 422
[Asserts]
jsonpath "$.detail" == "guide must be the guide text"

PUT {{base_url}}/guides/2
Authorization: {{auth_wr_admin}}
{"guide": 5}
HTTP 422

PUT {{base_url}}/guides/2
Authorization: {{auth_wr_admin}}
{"guide": null}
HTTP 422

# ... nothing was saved
GET {{base_url}}/guides/2
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.guide" == null
jsonpath "$.level_name" == "ABUZAR"

# 5. Saving creates the guide, the text untouched (no trimming); the editor read shows it
PUT {{base_url}}/guides/2
Authorization: {{auth_wr_admin}}
{"guide": "  <p>Wr guide one</p>\n"}
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.guide" == "  <p>Wr guide one</p>\n"

GET {{base_url}}/guides/2
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.guide" == "  <p>Wr guide one</p>\n"

# 6. Saving again replaces it (the level id is the (int) cast: 2abc is level 2)
PUT {{base_url}}/guides/2abc
Authorization: {{auth_wr_admin}}
{"guide": "<p>Wr guide two</p>"}
HTTP 200
[Asserts]
jsonpath "$.guide" == "<p>Wr guide two</p>"

GET {{base_url}}/guides/2
Authorization: {{auth_wr_admin}}
HTTP 200
[Asserts]
jsonpath "$.guide" == "<p>Wr guide two</p>"
