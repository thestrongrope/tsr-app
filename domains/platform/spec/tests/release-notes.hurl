# GET /release-notes contract: public, the valid releases in file order, from the synthetic catalog
# (app_versions.synthetic.json in this folder; see app-version.hurl for how both sides read it).
# Variable: base_url. No sign-in is used or needed.

# 1. The three valid releases, in file order (not sorted); the two malformed ones are dropped
GET {{base_url}}/release-notes
HTTP 200
[Asserts]
header "Content-Type" startsWith "application/json"
jsonpath "$.releases" count == 3
jsonpath "$.releases[0].version" == "9.2.0"
jsonpath "$.releases[1].version" == "9.1.0"
jsonpath "$.releases[2].version" == "9.0.0"
jsonpath "$.releases[0].date" == "2030-02-02"
# a date is checked for its shape only
jsonpath "$.releases[2].date" == "2030-99-99"

# 2. Notes keep only non-empty strings; a release with none has an empty list
GET {{base_url}}/release-notes
HTTP 200
[Asserts]
jsonpath "$.releases[0].notes" count == 2
jsonpath "$.releases[0].notes[1]" == "Third note"
jsonpath "$.releases[1].notes" count == 0
body contains "\"notes\":[]"

# 3. Builds keep integer values only; a quoted "51" is dropped
GET {{base_url}}/release-notes
HTTP 200
[Asserts]
jsonpath "$.releases[0].builds.android" == 52
jsonpath "$.releases[0].builds.ios" not exists
jsonpath "$.releases[1].builds.android" == 51
jsonpath "$.releases[1].builds.ios" == 50

# 4. A release with no integer build is written with an empty LIST, not an object (PHP's empty array)
GET {{base_url}}/release-notes
HTTP 200
[Asserts]
body contains "\"builds\":[]"
body not contains "\"builds\":{}"
jsonpath "$.releases[2].builds" count == 0
