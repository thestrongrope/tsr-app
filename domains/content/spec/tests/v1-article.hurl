# GET /api/v1/articles/{slug} contract: one published article with its HTML and five related articles, in the answer shape of today's website.
# Public: no sign-in. Data: the synthetic content files of db/synthetic/content (its README.md maps them to these cases): 12 published articles and 2 drafts.
# Cases: TC-LIB-R1-01, R10-01, R10-02, R11-01, R19-01, R25-01 of docs/specs/website-port/f1-plan-draft.md.
# Variable: base_url. Run through tools/contract-website.sh test, which first waits for the content to be loaded.

# 1. TC-LIB-R1-01, R10-01, R19-01: no sign-in; the article with every field the app reads, its HTML and its related articles
GET {{base_url}}/api/v1/articles/a-first-look-at-margin-notes
HTTP 200
[Captures]
etag: header "ETag"
[Asserts]
header "Content-Type" == "application/json"
header "Cache-Control" == "public, max-age=3600, stale-while-revalidate=86400"
header "ETag" matches /^"[0-9a-f]{32}"$/
header "Last-Modified" == "Sun, 12 May 2024 09:00:00 GMT"
header "Access-Control-Allow-Origin" == "*"
header "X-Content-Type-Options" == "nosniff"
jsonpath "$.success" == true
jsonpath "$.meta.timestamp" matches /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/
jsonpath "$.meta.version" == "1.0"
jsonpath "$.meta.cache.maxAge" == 3600
jsonpath "$.pagination" not exists
jsonpath "$.data.id" == 1
jsonpath "$.data.slug" == "a-first-look-at-margin-notes"
jsonpath "$.data.title" == "A First Look at Margin Notes"
jsonpath "$.data.excerpt" == "A short introduction to writing brief notes beside a text while reading."
jsonpath "$.data.publishedDate" == "2024-05-10T08:15:00.000Z"
jsonpath "$.data.modifiedDate" == "2024-05-12T09:00:00.000Z"
jsonpath "$.data.author" == "admin"
jsonpath "$.data.language" == "en"
jsonpath "$.data.categories" count == 1
jsonpath "$.data.categories[0]" == "note-taking"
jsonpath "$.data.tags" count == 1
jsonpath "$.data.tags[0]" == "Study Skills"
jsonpath "$.data.readingTime" == 1
jsonpath "$.data.id" isInteger
jsonpath "$.data.readingTime" isInteger
jsonpath "$.data.content" isString
# The Markdown itself is never sent: the app shows content, and the file's raw HTML would ride along in it.
jsonpath "$.data.rawContent" not exists
# The heading is an HTML element in content.
jsonpath "$.data.content" contains "<h2>Why margins matter</h2>"
jsonpath "$.data.content" contains "<li>Underline one sentence a page.</li>"
jsonpath "$.data.content" not contains "## Why"
# Related: the one sharing the tag AND the category first, then the others sharing the tag, newest first. A sixth shares the tag and is left out.
jsonpath "$.data.relatedArticles" count == 5
jsonpath "$.data.relatedArticles[0].slug" == "building-a-weekly-summary-page"
jsonpath "$.data.relatedArticles[1].slug" == "choosing-a-quiet-hour"
jsonpath "$.data.relatedArticles[2].slug" == "drafting-questions-before-a-lesson"
jsonpath "$.data.relatedArticles[3].slug" == "every-table-tells-a-story"
jsonpath "$.data.relatedArticles[4].slug" == "finding-the-main-idea"
jsonpath "$.data.relatedArticles[?(@.slug == 'glossary-habits-for-new-terms')]" not exists
jsonpath "$.data.relatedArticles[?(@.slug == 'a-first-look-at-margin-notes')]" not exists
# A related article is a list item: the list's fields, no body.
jsonpath "$.data.relatedArticles[0].id" == 2
jsonpath "$.data.relatedArticles[0].title" == "Building a Weekly Summary Page"
jsonpath "$.data.relatedArticles[0].excerpt" == "How one page written at the end of the week can gather the main points of every lesson."
jsonpath "$.data.relatedArticles[0].publishedDate" == "2022-02-14T06:30:00.000Z"
jsonpath "$.data.relatedArticles[0].modifiedDate" == "2022-02-14T06:30:00.000Z"
jsonpath "$.data.relatedArticles[0].author" == "admin"
jsonpath "$.data.relatedArticles[0].language" == "en"
jsonpath "$.data.relatedArticles[0].categories[1]" == "practice"
jsonpath "$.data.relatedArticles[0].tags[1]" == "Summaries"
jsonpath "$.data.relatedArticles[0].readingTime" == 1
jsonpath "$.data.relatedArticles[0].content" not exists
jsonpath "$.data.relatedArticles[0].rawContent" not exists
jsonpath "$.data.relatedArticles[*].id" count == 5
jsonpath "$.data.relatedArticles[*].title" count == 5
jsonpath "$.data.relatedArticles[*].publishedDate" count == 5
jsonpath "$.data.relatedArticles[*].categories" count == 5
jsonpath "$.data.relatedArticles[*].tags" count == 5
jsonpath "$.data.relatedArticles[*].readingTime" count == 5
# A draft sharing the tag and the category, newer than all five, is not related.
jsonpath "$.data.relatedArticles[?(@.slug == 'unfinished-outline-on-margin-notes')]" not exists

# 2. A kept quirk of today's website: related are filled up to five with the newest articles that share nothing
GET {{base_url}}/api/v1/articles/the-zorvath-timetable
HTTP 200
[Asserts]
jsonpath "$.data.id" == 0
jsonpath "$.data.publishedDate" == "2025-06-30T13:30:00.482913"
header "Last-Modified" == "Tue, 01 Jul 2025 13:30:00 GMT"
jsonpath "$.data.relatedArticles" count == 5
jsonpath "$.data.relatedArticles[0].slug" == "drafting-questions-before-a-lesson"
jsonpath "$.data.relatedArticles[1].slug" == "building-a-weekly-summary-page"
jsonpath "$.data.relatedArticles[2].slug" == "term-planner-for-next-year"
jsonpath "$.data.relatedArticles[3].slug" == "choosing-a-quiet-hour"
jsonpath "$.data.relatedArticles[4].slug" == "every-table-tells-a-story"
jsonpath "$.data.relatedArticles[?(@.slug == 'working-draft-on-revision-cycles')]" not exists

# 3. TC-LIB-R10-02: the 199 character slug opens
GET {{base_url}}/api/v1/articles/keeping-long-titles-readable-when-a-heading-runs-past-the-edge-of-the-page-and-the-reader-still-needs-to-find-the-one-idea-that-matters-most-in-a-crowded-set-of-lesson-notes-written-across-a-full-ter
HTTP 200
[Asserts]
jsonpath "$.data.slug" == "keeping-long-titles-readable-when-a-heading-runs-past-the-edge-of-the-page-and-the-reader-still-needs-to-find-the-one-idea-that-matters-most-in-a-crowded-set-of-lesson-notes-written-across-a-full-ter"
jsonpath "$.data.slug" matches /^.{199}$/
jsonpath "$.data.content" contains "<h2>When a heading is too long</h2>"
jsonpath "$.data.relatedArticles" count == 5

# 4. TC-LIB-R10-02: the percent-encoded slug opens when asked as the file writes it; the answer's slug is the file's own text
GET {{base_url}}/api/v1/articles/%d9%85%d8%b7%d8%a7%d9%84%d8%b9%db%81-%d9%86%d9%88%d9%b9%d8%b3
HTTP 200
[Captures]
encoded_etag: header "ETag"
[Asserts]
jsonpath "$.data.slug" == "%d9%85%d8%b7%d8%a7%d9%84%d8%b9%db%81-%d9%86%d9%88%d9%b9%d8%b3"
jsonpath "$.data.id" == 7
jsonpath "$.data.title" == "Lesson Notes in Another Script"
jsonpath "$.data.content" contains "<h2>A second script</h2>"

# 5. TC-LIB-R10-02: and when asked as the characters the slug stands for: the same answer
GET {{base_url}}/api/v1/articles/مطالعہ-نوٹس
HTTP 200
[Asserts]
jsonpath "$.data.slug" == "%d9%85%d8%b7%d8%a7%d9%84%d8%b9%db%81-%d9%86%d9%88%d9%b9%d8%b3"
jsonpath "$.data.id" == 7
header "ETag" == "{{encoded_etag}}"

# 6. And in upper case hexadecimal, as most clients write it
GET {{base_url}}/api/v1/articles/%D9%85%D8%B7%D8%A7%D9%84%D8%B9%DB%81-%D9%86%D9%88%D9%B9%D8%B3
HTTP 200
[Asserts]
header "ETag" == "{{encoded_etag}}"

# 7. TC-LIB-R10-02: the raw-HTML article opens with nothing that could run; its heading and its safe link stay
GET {{base_url}}/api/v1/articles/every-table-tells-a-story
HTTP 200
[Asserts]
jsonpath "$.data.slug" == "every-table-tells-a-story"
jsonpath "$.data.content" contains "<h2>Rows and columns</h2>"
jsonpath "$.data.content" contains "href=\"/articles/a-first-look-at-margin-notes\""
jsonpath "$.data.content" not matches /(?i)<script/
jsonpath "$.data.content" not matches /(?i)onerror\s*=/
jsonpath "$.data.content" not matches /(?i)javascript:/
jsonpath "$.data.content" not matches /(?i)<img/
jsonpath "$.data.content" not contains "studyNote = 1"
# The file's own Markdown, raw HTML and all, is not in the answer.
jsonpath "$.data.rawContent" not exists

# 8. The right-to-left article: its language, and text in its own script
GET {{base_url}}/api/v1/articles/weekly-study-plan-right-to-left
HTTP 200
[Asserts]
jsonpath "$.data.language" == "ur"
jsonpath "$.data.title" == "مطالعہ کا ہفتہ وار منصوبہ"
jsonpath "$.data.content" contains "<h2>ہفتہ وار منصوبہ</h2>"

# 9. TC-LIB-R11-01: a slug that does not exist: 404 in the error shape of these routes, naming only the slug asked
GET {{base_url}}/api/v1/articles/no-such-article
HTTP 404
[Asserts]
header "Content-Type" == "application/json"
header "Access-Control-Allow-Origin" == "*"
# The message repeats the slug asked: no browser may read the answer as anything but JSON.
header "X-Content-Type-Options" == "nosniff"
header "ETag" not exists
header "Cache-Control" not exists
jsonpath "$.success" == false
jsonpath "$.error.code" == "NOT_FOUND"
jsonpath "$.error.message" == "Article not found: no-such-article"
jsonpath "$.error.*" count == 2
jsonpath "$.meta.version" == "1.0"
jsonpath "$.meta.cache.maxAge" == 0
jsonpath "$.*" count == 3
jsonpath "$.data" not exists
jsonpath "$.detail" not exists

# 10. TC-LIB-R11-01: a draft's slug: the same answer as for a slug that does not exist
GET {{base_url}}/api/v1/articles/unfinished-outline-on-margin-notes
HTTP 404
[Asserts]
header "ETag" not exists
jsonpath "$.success" == false
jsonpath "$.error.code" == "NOT_FOUND"
jsonpath "$.error.message" == "Article not found: unfinished-outline-on-margin-notes"
jsonpath "$.error.*" count == 2
jsonpath "$.*" count == 3
jsonpath "$.data" not exists

# 11. TC-LIB-R11-01: the other draft
GET {{base_url}}/api/v1/articles/working-draft-on-revision-cycles
HTTP 404
[Asserts]
jsonpath "$.error.code" == "NOT_FOUND"
jsonpath "$.error.message" == "Article not found: working-draft-on-revision-cycles"
jsonpath "$.*" count == 3

# 12. A slug in another case is another slug
GET {{base_url}}/api/v1/articles/A-First-Look-At-Margin-Notes
HTTP 404
[Asserts]
jsonpath "$.error.message" == "Article not found: A-First-Look-At-Margin-Notes"

# 13. Text that would change a query built from strings is only an unknown slug
GET {{base_url}}/api/v1/articles/a'%20or%20'1'='1
HTTP 404
[Asserts]
jsonpath "$.error.code" == "NOT_FOUND"
jsonpath "$.error.message" == "Article not found: a' or '1'='1"

# 14. A slug of bytes that are no text is only an unknown slug, never a server error
GET {{base_url}}/api/v1/articles/%ff%fe
HTTP 404
[Asserts]
jsonpath "$.error.code" == "NOT_FOUND"

# 15. A NUL in the path is refused before any route sees it (so it cannot reach the database): a 400, never a 500
GET {{base_url}}/api/v1/articles/a%00b
HTTP 400

# 16. TC-LIB-R25-01: not changed since the ETag of request 1: 304 with no body
GET {{base_url}}/api/v1/articles/a-first-look-at-margin-notes
If-None-Match: {{etag}}
HTTP 304
[Asserts]
bytes count == 0

# 17. TC-LIB-R25-01: another ETag gets the whole answer
GET {{base_url}}/api/v1/articles/a-first-look-at-margin-notes
If-None-Match: "0123456789abcdef0123456789abcdef"
HTTP 200
[Asserts]
jsonpath "$.data.slug" == "a-first-look-at-margin-notes"
header "ETag" == "{{etag}}"

# 18. One article's ETag does not match another article
GET {{base_url}}/api/v1/articles/choosing-a-quiet-hour
If-None-Match: {{etag}}
HTTP 200
[Asserts]
jsonpath "$.data.slug" == "choosing-a-quiet-hour"
header "ETag" != "{{etag}}"

# 19. Not changed since the article's own last change: 304
GET {{base_url}}/api/v1/articles/a-first-look-at-margin-notes
If-Modified-Since: Sun, 12 May 2024 09:00:00 GMT
HTTP 304

# 20. Changed since a second earlier: the whole answer
GET {{base_url}}/api/v1/articles/a-first-look-at-margin-notes
If-Modified-Since: Sun, 12 May 2024 08:59:59 GMT
HTTP 200
[Asserts]
jsonpath "$.data.slug" == "a-first-look-at-margin-notes"

# 21. If-None-Match is judged alone (RFC 9110 section 13.1.3): another ETag with a date that would pass still gets the whole answer
GET {{base_url}}/api/v1/articles/a-first-look-at-margin-notes
If-None-Match: "0123456789abcdef0123456789abcdef"
If-Modified-Since: Sun, 12 May 2024 09:00:00 GMT
HTTP 200
[Asserts]
jsonpath "$.data.slug" == "a-first-look-at-margin-notes"

# 22. The right ETag with the same date: 304 with no body
GET {{base_url}}/api/v1/articles/a-first-look-at-margin-notes
If-None-Match: {{etag}}
If-Modified-Since: Sun, 12 May 2024 09:00:00 GMT
HTTP 304
[Asserts]
bytes count == 0

# 23. TC-LIB-R9-01: an option the route does not know is ignored: the answer of request 1
GET {{base_url}}/api/v1/articles/a-first-look-at-margin-notes
[Query]
unknownOption: 1
limit: 0
HTTP 200
[Asserts]
jsonpath "$.data.slug" == "a-first-look-at-margin-notes"
header "ETag" == "{{etag}}"
