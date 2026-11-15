# GET /api/v1/articles contract: the list of published articles the app's Library reads, in the answer shape of today's website.
# Public: no sign-in. Data: the synthetic content files of db/synthetic/content (its README.md maps them to these cases): 12 published articles and 2 drafts.
# Cases: TC-LIB-R1-01, R2-01 to R9-01, R19-01, R25-01, R26-01 of docs/specs/website-port/f1-plan-draft.md.
# Variable: base_url. Run through tools/contract-website.sh test, which first waits for the content to be loaded.
# Two requests with the same data and paging have the same ETag (it is a hash of "data" and "pagination"), so "the same answer" is asserted on it.

# 1. TC-LIB-R1-01, R2-01, R19-01: no sign-in; all 12 newest first; every field the app reads, by name and kind
GET {{base_url}}/api/v1/articles
HTTP 200
[Captures]
etag: header "ETag"
[Asserts]
header "Content-Type" == "application/json"
header "Cache-Control" == "public, max-age=300, stale-while-revalidate=600"
header "ETag" matches /^"[0-9a-f]{32}"$/
header "Last-Modified" == "Sat, 01 Mar 2031 00:00:00 GMT"
header "Access-Control-Allow-Origin" == "*"
header "X-Content-Type-Options" == "nosniff"
jsonpath "$.success" == true
jsonpath "$.meta.timestamp" matches /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/
jsonpath "$.meta.version" == "1.0"
jsonpath "$.meta.cache.maxAge" == 300
jsonpath "$.meta.cache.expires" matches /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/
jsonpath "$.pagination.total" == 12
jsonpath "$.pagination.limit" == 20
jsonpath "$.pagination.offset" == 0
jsonpath "$.pagination.hasMore" == false
jsonpath "$.data" count == 12
jsonpath "$.data[0].slug" == "term-planner-for-next-year"
jsonpath "$.data[1].slug" == "the-zorvath-timetable"
jsonpath "$.data[2].slug" == "choosing-a-quiet-hour"
jsonpath "$.data[3].slug" == "drafting-questions-before-a-lesson"
jsonpath "$.data[4].slug" == "every-table-tells-a-story"
jsonpath "$.data[5].slug" == "a-first-look-at-margin-notes"
jsonpath "$.data[6].slug" == "%d9%85%d8%b7%d8%a7%d9%84%d8%b9%db%81-%d9%86%d9%88%d9%b9%d8%b3"
jsonpath "$.data[7].slug" == "finding-the-main-idea"
jsonpath "$.data[8].slug" matches /^keeping-long-titles-readable-.{170}$/
jsonpath "$.data[9].slug" == "weekly-study-plan-right-to-left"
jsonpath "$.data[10].slug" == "building-a-weekly-summary-page"
jsonpath "$.data[11].slug" == "glossary-habits-for-new-terms"
jsonpath "$.data[0].id" == 9
jsonpath "$.data[0].title" == "Term Planner for Next Year"
jsonpath "$.data[0].excerpt" == "A blank planner for a term that has not started yet."
jsonpath "$.data[0].publishedDate" == "2031-03-01T00:00:00.000Z"
jsonpath "$.data[0].modifiedDate" == "2031-03-01T00:00:00.000Z"
jsonpath "$.data[0].author" == "admin"
jsonpath "$.data[0].language" == "en"
jsonpath "$.data[0].categories" count == 2
jsonpath "$.data[0].categories[0]" == "history"
jsonpath "$.data[0].categories[1]" == "early-schools"
jsonpath "$.data[0].tags" count == 1
jsonpath "$.data[0].tags[0]" == "Planning"
# The file has no id: 0. The date is the file's own text, whatever its shape.
jsonpath "$.data[1].id" == 0
jsonpath "$.data[1].publishedDate" == "2025-06-30T13:30:00.482913"
jsonpath "$.data[11].publishedDate" == "2021-09-12T14:00:00"
jsonpath "$.data[9].title" == "مطالعہ کا ہفتہ وار منصوبہ"
# The fields on every item, and their kinds.
jsonpath "$.data[*].id" count == 12
jsonpath "$.data[*].slug" count == 12
jsonpath "$.data[*].title" count == 12
jsonpath "$.data[*].excerpt" count == 12
jsonpath "$.data[*].publishedDate" count == 12
jsonpath "$.data[*].modifiedDate" count == 12
jsonpath "$.data[*].author" count == 12
jsonpath "$.data[*].language" count == 12
jsonpath "$.data[*].categories" count == 12
jsonpath "$.data[*].tags" count == 12
jsonpath "$.data[*].readingTime" count == 12
jsonpath "$.data[*].categories[0]" count == 12
jsonpath "$.data[*].tags[0]" count == 12
# The kind of every field of every item (Hurl has no "each": one line a field, an item).
jsonpath "$.data[0].id" isInteger
jsonpath "$.data[0].slug" isString
jsonpath "$.data[0].title" isString
jsonpath "$.data[0].excerpt" isString
jsonpath "$.data[0].publishedDate" isString
jsonpath "$.data[0].modifiedDate" isString
jsonpath "$.data[0].author" isString
jsonpath "$.data[0].language" isString
jsonpath "$.data[0].categories" isCollection
jsonpath "$.data[0].categories[0]" isString
jsonpath "$.data[0].tags" isCollection
jsonpath "$.data[0].tags[0]" isString
jsonpath "$.data[0].readingTime" isInteger
jsonpath "$.data[1].id" isInteger
jsonpath "$.data[1].slug" isString
jsonpath "$.data[1].title" isString
jsonpath "$.data[1].excerpt" isString
jsonpath "$.data[1].publishedDate" isString
jsonpath "$.data[1].modifiedDate" isString
jsonpath "$.data[1].author" isString
jsonpath "$.data[1].language" isString
jsonpath "$.data[1].categories" isCollection
jsonpath "$.data[1].categories[0]" isString
jsonpath "$.data[1].tags" isCollection
jsonpath "$.data[1].tags[0]" isString
jsonpath "$.data[1].readingTime" isInteger
jsonpath "$.data[2].id" isInteger
jsonpath "$.data[2].slug" isString
jsonpath "$.data[2].title" isString
jsonpath "$.data[2].excerpt" isString
jsonpath "$.data[2].publishedDate" isString
jsonpath "$.data[2].modifiedDate" isString
jsonpath "$.data[2].author" isString
jsonpath "$.data[2].language" isString
jsonpath "$.data[2].categories" isCollection
jsonpath "$.data[2].categories[0]" isString
jsonpath "$.data[2].tags" isCollection
jsonpath "$.data[2].tags[0]" isString
jsonpath "$.data[2].readingTime" isInteger
jsonpath "$.data[3].id" isInteger
jsonpath "$.data[3].slug" isString
jsonpath "$.data[3].title" isString
jsonpath "$.data[3].excerpt" isString
jsonpath "$.data[3].publishedDate" isString
jsonpath "$.data[3].modifiedDate" isString
jsonpath "$.data[3].author" isString
jsonpath "$.data[3].language" isString
jsonpath "$.data[3].categories" isCollection
jsonpath "$.data[3].categories[0]" isString
jsonpath "$.data[3].tags" isCollection
jsonpath "$.data[3].tags[0]" isString
jsonpath "$.data[3].readingTime" isInteger
jsonpath "$.data[4].id" isInteger
jsonpath "$.data[4].slug" isString
jsonpath "$.data[4].title" isString
jsonpath "$.data[4].excerpt" isString
jsonpath "$.data[4].publishedDate" isString
jsonpath "$.data[4].modifiedDate" isString
jsonpath "$.data[4].author" isString
jsonpath "$.data[4].language" isString
jsonpath "$.data[4].categories" isCollection
jsonpath "$.data[4].categories[0]" isString
jsonpath "$.data[4].tags" isCollection
jsonpath "$.data[4].tags[0]" isString
jsonpath "$.data[4].readingTime" isInteger
jsonpath "$.data[5].id" isInteger
jsonpath "$.data[5].slug" isString
jsonpath "$.data[5].title" isString
jsonpath "$.data[5].excerpt" isString
jsonpath "$.data[5].publishedDate" isString
jsonpath "$.data[5].modifiedDate" isString
jsonpath "$.data[5].author" isString
jsonpath "$.data[5].language" isString
jsonpath "$.data[5].categories" isCollection
jsonpath "$.data[5].categories[0]" isString
jsonpath "$.data[5].tags" isCollection
jsonpath "$.data[5].tags[0]" isString
jsonpath "$.data[5].readingTime" isInteger
jsonpath "$.data[6].id" isInteger
jsonpath "$.data[6].slug" isString
jsonpath "$.data[6].title" isString
jsonpath "$.data[6].excerpt" isString
jsonpath "$.data[6].publishedDate" isString
jsonpath "$.data[6].modifiedDate" isString
jsonpath "$.data[6].author" isString
jsonpath "$.data[6].language" isString
jsonpath "$.data[6].categories" isCollection
jsonpath "$.data[6].categories[0]" isString
jsonpath "$.data[6].tags" isCollection
jsonpath "$.data[6].tags[0]" isString
jsonpath "$.data[6].readingTime" isInteger
jsonpath "$.data[7].id" isInteger
jsonpath "$.data[7].slug" isString
jsonpath "$.data[7].title" isString
jsonpath "$.data[7].excerpt" isString
jsonpath "$.data[7].publishedDate" isString
jsonpath "$.data[7].modifiedDate" isString
jsonpath "$.data[7].author" isString
jsonpath "$.data[7].language" isString
jsonpath "$.data[7].categories" isCollection
jsonpath "$.data[7].categories[0]" isString
jsonpath "$.data[7].tags" isCollection
jsonpath "$.data[7].tags[0]" isString
jsonpath "$.data[7].readingTime" isInteger
jsonpath "$.data[8].id" isInteger
jsonpath "$.data[8].slug" isString
jsonpath "$.data[8].title" isString
jsonpath "$.data[8].excerpt" isString
jsonpath "$.data[8].publishedDate" isString
jsonpath "$.data[8].modifiedDate" isString
jsonpath "$.data[8].author" isString
jsonpath "$.data[8].language" isString
jsonpath "$.data[8].categories" isCollection
jsonpath "$.data[8].categories[0]" isString
jsonpath "$.data[8].tags" isCollection
jsonpath "$.data[8].tags[0]" isString
jsonpath "$.data[8].readingTime" isInteger
jsonpath "$.data[9].id" isInteger
jsonpath "$.data[9].slug" isString
jsonpath "$.data[9].title" isString
jsonpath "$.data[9].excerpt" isString
jsonpath "$.data[9].publishedDate" isString
jsonpath "$.data[9].modifiedDate" isString
jsonpath "$.data[9].author" isString
jsonpath "$.data[9].language" isString
jsonpath "$.data[9].categories" isCollection
jsonpath "$.data[9].categories[0]" isString
jsonpath "$.data[9].tags" isCollection
jsonpath "$.data[9].tags[0]" isString
jsonpath "$.data[9].readingTime" isInteger
jsonpath "$.data[10].id" isInteger
jsonpath "$.data[10].slug" isString
jsonpath "$.data[10].title" isString
jsonpath "$.data[10].excerpt" isString
jsonpath "$.data[10].publishedDate" isString
jsonpath "$.data[10].modifiedDate" isString
jsonpath "$.data[10].author" isString
jsonpath "$.data[10].language" isString
jsonpath "$.data[10].categories" isCollection
jsonpath "$.data[10].categories[0]" isString
jsonpath "$.data[10].tags" isCollection
jsonpath "$.data[10].tags[0]" isString
jsonpath "$.data[10].readingTime" isInteger
jsonpath "$.data[11].id" isInteger
jsonpath "$.data[11].slug" isString
jsonpath "$.data[11].title" isString
jsonpath "$.data[11].excerpt" isString
jsonpath "$.data[11].publishedDate" isString
jsonpath "$.data[11].modifiedDate" isString
jsonpath "$.data[11].author" isString
jsonpath "$.data[11].language" isString
jsonpath "$.data[11].categories" isCollection
jsonpath "$.data[11].categories[0]" isString
jsonpath "$.data[11].tags" isCollection
jsonpath "$.data[11].tags[0]" isString
jsonpath "$.data[11].readingTime" isInteger
jsonpath "$.data[?(@.author == 'admin')]" count == 12
jsonpath "$.data[?(@.language == 'en')]" count == 11
# A kept quirk of today's website: the list says 1 minute for every article.
jsonpath "$.data[?(@.readingTime == 1)]" count == 12
# A draft is in no answer.
jsonpath "$.data[?(@.slug == 'unfinished-outline-on-margin-notes')]" not exists
jsonpath "$.data[?(@.slug == 'working-draft-on-revision-cycles')]" not exists
# Never the body.
jsonpath "$.data[0].content" not exists
jsonpath "$.data[0].rawContent" not exists

# 2. TC-LIB-R2-01: a page of 5 with more to come
GET {{base_url}}/api/v1/articles
[Query]
limit: 5
HTTP 200
[Asserts]
jsonpath "$.data" count == 5
jsonpath "$.data[0].slug" == "term-planner-for-next-year"
jsonpath "$.data[4].slug" == "every-table-tells-a-story"
jsonpath "$.pagination.total" == 12
jsonpath "$.pagination.limit" == 5
jsonpath "$.pagination.offset" == 0
jsonpath "$.pagination.hasMore" == true
header "ETag" != "{{etag}}"

# 3. TC-LIB-R2-01: the last page has the last two
GET {{base_url}}/api/v1/articles
[Query]
limit: 5
offset: 10
HTTP 200
[Asserts]
jsonpath "$.data" count == 2
jsonpath "$.data[0].slug" == "building-a-weekly-summary-page"
jsonpath "$.data[1].slug" == "glossary-habits-for-new-terms"
jsonpath "$.pagination.total" == 12
jsonpath "$.pagination.offset" == 10
jsonpath "$.pagination.hasMore" == false

# 4. A page past the end is empty, with the total still told
GET {{base_url}}/api/v1/articles
[Query]
offset: 12
HTTP 200
[Asserts]
jsonpath "$.data" count == 0
jsonpath "$.pagination.total" == 12
jsonpath "$.pagination.offset" == 12
jsonpath "$.pagination.hasMore" == false

# 5. TC-LIB-R2-01: an offset below 0 is 0: the same answer as with none
GET {{base_url}}/api/v1/articles
[Query]
offset: -3
HTTP 200
[Asserts]
jsonpath "$.pagination.offset" == 0
jsonpath "$.data" count == 12
header "ETag" == "{{etag}}"

# 6. TC-LIB-R2-01: an offset that is no number is 0 too
GET {{base_url}}/api/v1/articles
[Query]
offset: abc
HTTP 200
[Asserts]
jsonpath "$.pagination.offset" == 0
jsonpath "$.data" count == 12
header "ETag" == "{{etag}}"

# 7. TC-LIB-R3-01: one category, by its exact slug
GET {{base_url}}/api/v1/articles
[Query]
category: note-taking
HTTP 200
[Asserts]
jsonpath "$.data" count == 2
jsonpath "$.data[0].slug" == "a-first-look-at-margin-notes"
jsonpath "$.data[1].slug" == "building-a-weekly-summary-page"
jsonpath "$.pagination.total" == 2
jsonpath "$.pagination.hasMore" == false

# 8. TC-LIB-R3-01: the start of a slug matches nothing
GET {{base_url}}/api/v1/articles
[Query]
category: note
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.data" count == 0
jsonpath "$.pagination.total" == 0

# 9. A category in another case matches nothing
GET {{base_url}}/api/v1/articles
[Query]
category: Note-Taking
HTTP 200
[Asserts]
jsonpath "$.data" count == 0

# 10. Two categories joined with a comma match nothing (a kept quirk: one exact value)
GET {{base_url}}/api/v1/articles
[Query]
category: note-taking,practice
HTTP 200
[Asserts]
jsonpath "$.data" count == 0

# 11. TC-LIB-R4-01: one tag, by its exact name
GET {{base_url}}/api/v1/articles
[Query]
tag: Night Reading
HTTP 200
[Asserts]
jsonpath "$.data" count == 2
jsonpath "$.data[0].slug" == "choosing-a-quiet-hour"
jsonpath "$.data[1].slug" == "%d9%85%d8%b7%d8%a7%d9%84%d8%b9%db%81-%d9%86%d9%88%d9%b9%d8%b3"
jsonpath "$.pagination.total" == 2

# 12. TC-LIB-R4-01: the tag's first word alone matches nothing
GET {{base_url}}/api/v1/articles
[Query]
tag: Night
HTTP 200
[Asserts]
jsonpath "$.data" count == 0
jsonpath "$.pagination.total" == 0

# 13. A tag in another case matches nothing
GET {{base_url}}/api/v1/articles
[Query]
tag: night reading
HTTP 200
[Asserts]
jsonpath "$.data" count == 0

# 14. TC-LIB-R5-01: a word found in one title, one excerpt and one tag
GET {{base_url}}/api/v1/articles
[Query]
q: zorvath
HTTP 200
[Asserts]
jsonpath "$.data" count == 3
jsonpath "$.data[0].slug" == "the-zorvath-timetable"
jsonpath "$.data[1].slug" == "drafting-questions-before-a-lesson"
jsonpath "$.data[2].slug" == "finding-the-main-idea"
jsonpath "$.pagination.total" == 3

# 15. TC-LIB-R5-01: the word in another case finds the same three
GET {{base_url}}/api/v1/articles
[Query]
q: ZORVATH
HTTP 200
[Asserts]
jsonpath "$.data" count == 3
jsonpath "$.data[2].slug" == "finding-the-main-idea"

# 16. TC-LIB-R5-01: a word found only in a body finds nothing
GET {{base_url}}/api/v1/articles
[Query]
q: quelmbry
HTTP 200
[Asserts]
jsonpath "$.data" count == 0
jsonpath "$.pagination.total" == 0

# 17. A word that is a search pattern character finds nothing by accident
GET {{base_url}}/api/v1/articles
[Query]
q: %
HTTP 200
[Asserts]
jsonpath "$.data" count == 0

# 18. The options narrow together: the word, within one category
GET {{base_url}}/api/v1/articles
[Query]
q: zorvath
category: practice
HTTP 200
[Asserts]
jsonpath "$.data" count == 2
jsonpath "$.data[0].slug" == "the-zorvath-timetable"
jsonpath "$.data[1].slug" == "drafting-questions-before-a-lesson"

# 19. TC-LIB-R6-01: newest first, asked by name
GET {{base_url}}/api/v1/articles
[Query]
sort: publishedDate:desc
HTTP 200
[Asserts]
jsonpath "$.data[0].slug" == "term-planner-for-next-year"
jsonpath "$.data[11].slug" == "glossary-habits-for-new-terms"
header "ETag" == "{{etag}}"

# 20. TC-LIB-R6-01: oldest first
GET {{base_url}}/api/v1/articles
[Query]
sort: publishedDate:asc
HTTP 200
[Asserts]
jsonpath "$.data" count == 12
jsonpath "$.data[0].slug" == "glossary-habits-for-new-terms"
jsonpath "$.data[1].slug" == "building-a-weekly-summary-page"
jsonpath "$.data[11].slug" == "term-planner-for-next-year"

# 21. TC-LIB-R6-01: by title. The title in Arabic script comes after every Latin one in any collation; the last Latin title is "The Zorvath Timetable".
GET {{base_url}}/api/v1/articles
[Query]
sort: title:asc
HTTP 200
[Asserts]
jsonpath "$.data" count == 12
jsonpath "$.data[0].slug" == "a-first-look-at-margin-notes"
jsonpath "$.data[1].slug" == "building-a-weekly-summary-page"
jsonpath "$.data[8].title" == "Lesson Notes in Another Script"
jsonpath "$.data[9].slug" == "term-planner-for-next-year"
jsonpath "$.data[10].slug" == "the-zorvath-timetable"
jsonpath "$.data[11].slug" == "weekly-study-plan-right-to-left"

# 22. TC-LIB-R6-01: by title, last first
GET {{base_url}}/api/v1/articles
[Query]
sort: title:desc
HTTP 200
[Asserts]
jsonpath "$.data[0].slug" == "weekly-study-plan-right-to-left"
jsonpath "$.data[1].slug" == "the-zorvath-timetable"
jsonpath "$.data[11].slug" == "a-first-look-at-margin-notes"

# 23. An order pages like any other
GET {{base_url}}/api/v1/articles
[Query]
sort: title:asc
limit: 2
offset: 2
HTTP 200
[Asserts]
jsonpath "$.data" count == 2
jsonpath "$.data[0].slug" == "choosing-a-quiet-hour"
jsonpath "$.data[1].slug" == "drafting-questions-before-a-lesson"
jsonpath "$.pagination.hasMore" == true

# 24. TC-LIB-R7-01: an unknown order is refused, in the error shape of these routes
GET {{base_url}}/api/v1/articles
[Query]
sort: views:desc
HTTP 400
[Asserts]
jsonpath "$.success" == false
jsonpath "$.error.code" == "VALIDATION_ERROR"
jsonpath "$.error.message" == "Invalid sort parameter. Valid options: publishedDate:asc, publishedDate:desc, title:asc, title:desc"
jsonpath "$.meta.version" == "1.0"
jsonpath "$.data" not exists
jsonpath "$.detail" not exists
header "ETag" not exists
header "X-Content-Type-Options" == "nosniff"

# 25. An order in another case is unknown too
GET {{base_url}}/api/v1/articles
[Query]
sort: Title:asc
HTTP 400
[Asserts]
jsonpath "$.error.code" == "VALIDATION_ERROR"

# 26. An empty order is the default one
GET {{base_url}}/api/v1/articles?sort=
HTTP 200
[Asserts]
header "ETag" == "{{etag}}"

# 27. TC-LIB-R8-01: a page size of 0 is 1
GET {{base_url}}/api/v1/articles
[Query]
limit: 0
HTTP 200
[Asserts]
jsonpath "$.pagination.limit" == 1
jsonpath "$.data" count == 1
jsonpath "$.pagination.hasMore" == true

# 28. TC-LIB-R8-01: a page size of 500 is 100
GET {{base_url}}/api/v1/articles
[Query]
limit: 500
HTTP 200
[Asserts]
jsonpath "$.pagination.limit" == 100
jsonpath "$.data" count == 12

# 29. TC-LIB-R8-01: a page size that is no number is 20
GET {{base_url}}/api/v1/articles
[Query]
limit: abc
HTTP 200
[Asserts]
jsonpath "$.pagination.limit" == 20
header "ETag" == "{{etag}}"

# 30. TC-LIB-R9-01: options the route does not use are ignored: the same answer as with none
GET {{base_url}}/api/v1/articles
[Query]
fields: title
nonsense: 1
HTTP 200
[Asserts]
jsonpath "$.data" count == 12
jsonpath "$.data[0].excerpt" exists
header "ETag" == "{{etag}}"

# 31. TC-LIB-R26-01: one language
GET {{base_url}}/api/v1/articles
[Query]
locale: ur
HTTP 200
[Asserts]
jsonpath "$.data" count == 1
jsonpath "$.data[0].slug" == "weekly-study-plan-right-to-left"
jsonpath "$.data[0].language" == "ur"
jsonpath "$.pagination.total" == 1

# 32. TC-LIB-R26-01: the start of a language code matches nothing
GET {{base_url}}/api/v1/articles
[Query]
locale: u
HTTP 200
[Asserts]
jsonpath "$.data" count == 0
jsonpath "$.pagination.total" == 0

# 33. A language code in another case matches nothing
GET {{base_url}}/api/v1/articles
[Query]
locale: UR
HTTP 200
[Asserts]
jsonpath "$.data" count == 0

# 34. TC-LIB-R25-01: not changed since the ETag of request 1: 304 with no body
GET {{base_url}}/api/v1/articles
If-None-Match: {{etag}}
HTTP 304
[Asserts]
bytes count == 0

# 35. TC-LIB-R25-01: another ETag gets the whole answer
GET {{base_url}}/api/v1/articles
If-None-Match: "0123456789abcdef0123456789abcdef"
HTTP 200
[Asserts]
jsonpath "$.data" count == 12
header "ETag" == "{{etag}}"

# 36. The ETag of one request does not match another request's answer
GET {{base_url}}/api/v1/articles
If-None-Match: {{etag}}
[Query]
limit: 5
HTTP 200
[Asserts]
jsonpath "$.data" count == 5

# 37. Not changed since a date after the newest change: 304
GET {{base_url}}/api/v1/articles
If-Modified-Since: Sun, 02 Mar 2031 00:00:00 GMT
HTTP 304

# 38. Changed since an earlier date: the whole answer
GET {{base_url}}/api/v1/articles
If-Modified-Since: Fri, 28 Feb 2031 23:59:59 GMT
HTTP 200
[Asserts]
jsonpath "$.data" count == 12

# A NUL in a filter value: no article can hold one, so nothing matches. An empty page as for any other value that matches nothing, never a failure.

# 39. A word that is a NUL matches nothing
GET {{base_url}}/api/v1/articles?q=%00
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.data" count == 0
jsonpath "$.pagination.total" == 0
jsonpath "$.pagination.hasMore" == false
header "Last-Modified" == "Sat, 01 Mar 2031 00:00:00 GMT"

# 40. A category that is a NUL matches nothing
GET {{base_url}}/api/v1/articles?category=%00
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.data" count == 0
jsonpath "$.pagination.total" == 0
jsonpath "$.pagination.hasMore" == false
header "Last-Modified" == "Sat, 01 Mar 2031 00:00:00 GMT"

# 41. A tag that is a NUL matches nothing
GET {{base_url}}/api/v1/articles?tag=%00
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.data" count == 0
jsonpath "$.pagination.total" == 0
jsonpath "$.pagination.hasMore" == false
header "Last-Modified" == "Sat, 01 Mar 2031 00:00:00 GMT"

# 42. A language code that is a NUL matches nothing
GET {{base_url}}/api/v1/articles?locale=%00
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.data" count == 0
jsonpath "$.pagination.total" == 0
jsonpath "$.pagination.hasMore" == false
header "Last-Modified" == "Sat, 01 Mar 2031 00:00:00 GMT"

# 43. A NUL inside a word matches nothing
GET {{base_url}}/api/v1/articles?q=zor%00vath
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.data" count == 0
jsonpath "$.pagination.total" == 0
jsonpath "$.pagination.hasMore" == false
header "Last-Modified" == "Sat, 01 Mar 2031 00:00:00 GMT"

# 44. A NUL after a real category matches nothing
GET {{base_url}}/api/v1/articles?category=note-taking%00
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.data" count == 0
jsonpath "$.pagination.total" == 0
jsonpath "$.pagination.hasMore" == false
header "Last-Modified" == "Sat, 01 Mar 2031 00:00:00 GMT"

# 45. A NUL inside a tag matches nothing
GET {{base_url}}/api/v1/articles?tag=Night%00Reading
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.data" count == 0
jsonpath "$.pagination.total" == 0
jsonpath "$.pagination.hasMore" == false
header "Last-Modified" == "Sat, 01 Mar 2031 00:00:00 GMT"

# 46. A NUL after a real language code matches nothing
GET {{base_url}}/api/v1/articles?locale=en%00
HTTP 200
[Asserts]
jsonpath "$.success" == true
jsonpath "$.data" count == 0
jsonpath "$.pagination.total" == 0
jsonpath "$.pagination.hasMore" == false
header "Last-Modified" == "Sat, 01 Mar 2031 00:00:00 GMT"
