# GET /api/v1/search while Elasticsearch is unavailable (SRCH-R6): the published articles in the database answer, searchEngine "fuse", never a 500.
# Run it on a stack whose Elasticsearch is stopped (a lane: stop the lane's own elasticsearch container). The shape and the paging rules are v1-search.hurl's.
# Variable: base_url. Cases: TC-SRCH-R6-01 (and, on the database side, R6-03: db/tests/V1SearchTests.cs).

GET {{base_url}}/api/v1/search?q=zorvath
HTTP 200
[Asserts]
header "Cache-Control" == "public, max-age=60"
jsonpath "$.success" == true
jsonpath "$.data.searchEngine" == "fuse"
jsonpath "$.data.query" == "zorvath"
jsonpath "$.data.results" count == 3
jsonpath "$.data.results[0].slug" == "the-zorvath-timetable"
jsonpath "$.data.results[0].score" == 1
jsonpath "$.data.results[0].highlights.title[0]" == "The <em>Zorvath</em> Timetable"
jsonpath "$.data.results[1].slug" == "drafting-questions-before-a-lesson"
jsonpath "$.data.results[2].slug" == "finding-the-main-idea"
jsonpath "$.pagination.total" == 3
jsonpath "$.pagination.hasMore" == false

GET {{base_url}}/api/v1/search?q=study&category=note-taking
HTTP 200
[Asserts]
jsonpath "$.data.searchEngine" == "fuse"
jsonpath "$.data.results" count == 2

GET {{base_url}}/api/v1/search?q=zorvath%20quelmbry
HTTP 200
[Asserts]
jsonpath "$.data.results" count == 0

GET {{base_url}}/api/v1/search?q=%20
HTTP 400
[Asserts]
jsonpath "$.error.code" == "VALIDATION_ERROR"
