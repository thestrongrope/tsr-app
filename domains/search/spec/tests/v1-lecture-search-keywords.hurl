# GET /api/v1/lectures/search WITHOUT the embedding service: keyword answers only, searchEngine "elasticsearch", no error (SRCH-R11).
# Run it on a stack where the meaning layer has no service: a lane started without TSR_LANE_EMBEDDINGS (the settings carry the weight, there is no address), or any stack whose embedding container is stopped or slow.
# Data: the invented lectures of db/synthetic/lectures. Cases: TC-SRCH-R11-01, R7-01, R8-01, R9-01, R13-01 of docs/specs/website-port/search-port-plan.md.
# Variable: base_url. Under 60 requests a minute.

# 1. TC-SRCH-R11-01: a search answers 200 from keywords; the lecture whose title and chapter hold the words is first
GET {{base_url}}/api/v1/lectures/search?q=first%20hour%20of%20the%20morning
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.data.searchEngine" == "elasticsearch"
jsonpath "$.data.results[0].slug" == "SYNTHLEC001"
jsonpath "$.data.results[0].matchedChapters[0].title" == "Choosing the first hour of the morning"
jsonpath "$.data.results[0].matchedChapters[0].highlight.title[0]" contains "<em>first</em>"
jsonpath "$.data.total" >= 1
jsonpath "$.pagination.total" == 5
jsonpath "$.pagination.hasMore" == false

# A concept that no keyword names finds nothing by keywords (the meaning layer is what finds it): 200 with an empty page, not an error
GET {{base_url}}/api/v1/lectures/search?q=grief
HTTP 200
[Asserts]
jsonpath "$.data.searchEngine" == "elasticsearch"
jsonpath "$.data.results" count == 0
jsonpath "$.data.total" == 0
jsonpath "$.pagination.hasMore" == false

# 2. TC-SRCH-R9-01 (the layer off): a language keeps only that language
GET {{base_url}}/api/v1/lectures/search?q=%E0%A4%B8%E0%A4%AE%E0%A4%AF%20%E0%A4%B8%E0%A4%BE%E0%A4%B0%E0%A4%A3%E0%A5%80&language=hi
HTTP 200
[Asserts]
jsonpath "$.data.results[0].slug" == "SYNTHLEC010"
jsonpath "$.data.results[*].language" contains "hi"
jsonpath "$.data.results[*].language" not contains "en"
jsonpath "$.data.results[*].language" not contains "ar"

# 3. TC-SRCH-R8-01 and R13-01: browse is the same with or without the embedding service
GET {{base_url}}/api/v1/lectures/search?limit=5&offset=10
HTTP 200
[Asserts]
jsonpath "$.data.query" == ""
jsonpath "$.data.results" count == 2
jsonpath "$.data.total" == 12
jsonpath "$.pagination.total" == 12
jsonpath "$.pagination.hasMore" == false

GET {{base_url}}/api/v1/lectures/search
HTTP 200
[Asserts]
jsonpath "$.data.results[0].slug" == "SYNTHLEC011"
jsonpath "$.data.results[11].slug" == "SYNTHLEC012"
