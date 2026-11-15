# GET /join/{code} contract (PUBLIC, no sign-in): the class a join link names. Runs against any implementation. The limit is 30 calls a minute per client address, so this file makes few calls (no 429 case here: the limit is unit tested).
# Variables: base_url. ENROLMENT fixtures (reset by tools/classes-contract.sh): class 9418 (gents, MIQDAD, English, link WrJoin9418), the closed class 9419 (link wrjoin9419), the ladies class 9414 (link enlnk9414).

# 1. An open class: only the public facts; the link matches in any case
GET {{base_url}}/join/WrJoin9418
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"
jsonpath "$.name" == "En Join Class"
jsonpath "$.level" == "MIQDAD"
jsonpath "$.language" == "English"
jsonpath "$.gender" matches /\S/
jsonpath "$.open" == true
jsonpath "$.teacher" not exists
jsonpath "$.id" not exists

GET {{base_url}}/join/wrjoin9418
HTTP 200
[Asserts]
jsonpath "$.name" == "En Join Class"

# 2. A closed class is still named, as not open
GET {{base_url}}/join/wrjoin9419
HTTP 200
[Asserts]
jsonpath "$.name" == "En Closed Join Class"
jsonpath "$.open" == false

# 3. The ladies class names its own gender
GET {{base_url}}/join/enlnk9414
HTTP 200
[Asserts]
jsonpath "$.gender" matches /\S/
jsonpath "$.open" == true

# 4. Unknown codes and malformed codes: a bare 404
GET {{base_url}}/join/nosuchlink
HTTP 404
[Asserts]
jsonpath "$.detail" == "Not Found"

GET {{base_url}}/join/bad-code
HTTP 404
[Asserts]
jsonpath "$.detail" == "Not Found"

GET {{base_url}}/join/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
HTTP 404
