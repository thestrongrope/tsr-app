# GET /articles contract. Public: no sign-in. Only published articles are listed; the synthetic
# seed (db/synthetic/seed.sql) has one published, one draft and one scheduled article.
# Variable: base_url.
#   hurl --test --variable base_url=http://localhost:8088 list-published-articles.hurl

# 1. Anyone can list articles without sign in
GET {{base_url}}/articles
HTTP 200
[Asserts]
header "Content-Type" startsWith "application/json"

# 2. Exactly one published article is listed, with its fields. publishedAt is UTC written with the
#    offset +00:00, never Z (api.yaml).
GET {{base_url}}/articles
HTTP 200
[Asserts]
jsonpath "$.articles" count == 1
jsonpath "$.articles[0].slug" == "synthetic-published-article"
jsonpath "$.articles[?(@.slug=='synthetic-published-article')]" exists
jsonpath "$.articles[?(@.slug=='synthetic-published-article')].title" matches /\S/
jsonpath "$.articles[?(@.slug=='synthetic-published-article')].body" matches /\S/
jsonpath "$.articles[?(@.slug=='synthetic-published-article')].publishedAt" matches /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+00:00$/

# 3. A draft article is never listed
GET {{base_url}}/articles
HTTP 200
[Asserts]
jsonpath "$.articles[?(@.slug=='synthetic-published-article')]" exists
jsonpath "$.articles[?(@.slug=='synthetic-draft-article')]" not exists

# 4. A scheduled article is never listed
GET {{base_url}}/articles
HTTP 200
[Asserts]
jsonpath "$.articles[?(@.slug=='synthetic-published-article')]" exists
jsonpath "$.articles[?(@.slug=='synthetic-scheduled-article')]" not exists
