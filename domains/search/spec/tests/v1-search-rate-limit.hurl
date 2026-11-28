# GET /api/v1/search rate limit (SRCH-R14): 60 requests a minute per client; the 61st is a 429 in the website's shape.
# Run this file LAST on a stack: it uses up the client's bucket for a minute, and every other request of the other files counts toward the same bucket.
# Variable: base_url. Case: TC-SRCH-R14-01.

GET {{base_url}}/api/v1/search?q=zorvath
[Options]
repeat: 60
HTTP *

GET {{base_url}}/api/v1/search?q=zorvath
HTTP 429
[Asserts]
header "Retry-After" matches /^([1-9]|[1-5][0-9]|60)$/
header "X-RateLimit-Limit" == "60"
header "X-RateLimit-Remaining" == "0"
header "Access-Control-Allow-Origin" == "*"
header "Cache-Control" not exists
jsonpath "$.success" == false
jsonpath "$.error" == "Too many requests"
jsonpath "$.meta" not exists
