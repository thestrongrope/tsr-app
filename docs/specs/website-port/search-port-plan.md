# Article search and lecture search: spec and plan (issue 22)

Status: draft for the owner, 27 Nov 2026. Nothing is built. Source read: tsr-web at commit `109927c` (clean tree).
"tsr-web" below means `~/Projects/tsr-web`; paths under it start at `web/` unless they say otherwise.

---

## 1. Spec (what and why)

### Problem
The app's Library search calls two routes of the old website: article search and lecture search. Neither is ported.
So the app still needs the old website, its Elasticsearch and its embedding service.

### Outcome
Both routes answer from the new API with the same paths, parameters and answer shape. Released app builds keep working
with no change. When the new API serves them, nothing the app calls needs the old website any more.

### Requirements (EARS)

| ID | Requirement |
|---|---|
| SRCH-R1 | WHEN a client sends `GET /api/v1/search` with a `q` that is not blank THEN the system SHALL answer 200 with the published articles that match `q`, best match first, in the website's answer shape. |
| SRCH-R2 | IF `q` is missing or blank on `GET /api/v1/search` THEN the system SHALL answer 400 with code `VALIDATION_ERROR` and message `Missing required parameter: q`. |
| SRCH-R3 | WHEN either search route reads `limit` or `offset` THEN the system SHALL read them as the website does: `limit` 20 by default, kept between 1 and 100; `offset` 0 by default, never below 0; a value that is not a number gives the default. |
| SRCH-R4 | WHERE `category` is given on article search, the system SHALL return only articles in that category. |
| SRCH-R5 | WHEN article search answers THEN `pagination.total` SHALL be the number of results on this page and `hasMore` SHALL be true exactly when that number equals `limit` (the website's rule, kept). |
| SRCH-R6 | IF the search engine is not configured, cannot be reached or fails on article search THEN the system SHALL still answer 200 from the published articles in the database, with `searchEngine` `fuse`. |
| SRCH-R7 | WHEN a client sends `GET /api/v1/lectures/search` with a `q` that is not blank THEN the system SHALL answer 200 with the matching lectures, best first, each with the chapters that matched. |
| SRCH-R8 | WHEN `q` is missing or blank on lecture search THEN the system SHALL list all lectures newest first, with `query` empty and a `total` of every lecture. |
| SRCH-R9 | WHERE `language` is given on lecture search, the system SHALL return only lectures in that language, in the keyword part and the meaning part alike. |
| SRCH-R10 | WHERE the meaning layer is switched on, WHEN the embedding service gives a vector for `q` THEN lecture search SHALL blend the keyword ranking with the meaning ranking and answer `searchEngine` `elasticsearch+semantic`. |
| SRCH-R11 | IF the embedding service fails, answers late (over 1.5 s) or answers an error THEN lecture search SHALL answer from keywords only, with `searchEngine` `elasticsearch`, and no error. |
| SRCH-R12 | IF the search engine is not configured or fails on lecture search THEN the system SHALL answer 500 with code `INTERNAL_ERROR` in the website's failure shape (the website has no fallback here). |
| SRCH-R13 | WHEN lecture search answers THEN `pagination.total` SHALL equal `data.total` and `hasMore` SHALL be true exactly when `offset` plus the results on this page is below `total`. |
| SRCH-R14 | IF one client sends more than 60 requests in a minute to one search route THEN the system SHALL answer 429 with `{"success": false, "error": "Too many requests"}` and the headers `Retry-After`, `X-RateLimit-Limit` and `X-RateLimit-Remaining: 0`. |
| SRCH-R15 | WHEN a search route answers 200 THEN it SHALL send `Cache-Control: public, max-age=60`, an `ETag` and `Vary: Accept-Encoding`, and SHALL never answer 304. |
| SRCH-R16 | IF anything else fails while a search route answers THEN the system SHALL answer 500 `INTERNAL_ERROR` "An unexpected error occurred" in the website's failure shape, with nothing of the failure in it. |
| SRCH-R17 | WHEN the published articles or the lecture data change THEN the article index and the lecture index SHALL match them within 10 minutes; IF a source reads as empty THEN its index SHALL be kept as it was. |
| SRCH-R18 | The system SHALL NOT record search queries (pending decision 4b; if the owner chooses to port analytics, this is replaced). |

### Quality requirements

| ID | Characteristic | Requirement |
|---|---|---|
| SRCH-Q1 | Compatibility | For a fixed list of queries, the answers SHALL equal tsr-web's (same lectures and articles, same order, same fields), apart from the differences allowed in the parity allow file. |
| SRCH-Q2 | Performance | On the test stack, 95 of 100 lecture searches with the meaning layer on SHALL answer within 300 ms (the Library's read target). |
| SRCH-Q3 | Security | The caller's text SHALL reach Elasticsearch only as a JSON string value, never as query syntax. No log line SHALL hold the query text. |
| SRCH-Q4 | Portability | Both routes SHALL pass their Hurl files against the native API image. |
| SRCH-Q5 | Resources | The embedding container SHALL stay under a 1 GB memory limit and serve single queries at about 260 MB. |
| SRCH-Q6 | Availability | The API SHALL start and answer when Elasticsearch or the embedding service is absent. |

### Out of scope
- The site's `/lectures/` page moving from the data file to the API (LEC-D1; see decision 4f).
- Search analytics and the click route `POST /api/v1/events` (decision 4b; the app never calls it).
- The admin reindex routes `POST /api/admin/reindex` and `/api/admin/reindex-lectures`: the worker replaces them.
- Making the lecture data: the lecture pipeline and the embedding script stay in tsr-web.
- The app's cut-over to the new API host (decision 4e).

---

## 2. Behaviour of the source, exactly

### 2.1 `GET /api/v1/search` (`src/app/api/v1/search/route.ts`)

**Order of work.** The rate limit runs first (lines 56-70), then `q` is checked, then the search runs, then the analytics write,
then the answer. Everything after the rate limit is inside the `try`. A failure goes to `errorResponse` (lines 120-122).

**Parameters**
- `q`: required. `validateRequiredParam` (`api/lib/api-response.ts:121-131`): missing or blank after trim throws
  `VALIDATION_ERROR` "Missing required parameter: q", which answers 400. The trimmed value is used from then on.
- `limit`: `parseIntParam(raw, 20, 1, 100)` (route line 79; `api-response.ts:103-119`). An empty value gives the default.
  Otherwise JavaScript `parseInt(raw, 10)`, NaN gives the default, then it is clamped. This is already ported as `V1.Int`.
- `offset`: `parseIntParam(raw, 0, 0)` (line 80), no top bound.
- `category`: one value, used as written; empty means none (line 81).
- `fields`: split on commas (line 82) and then ignored by every search path.

**Engine choice** (`api/lib/search-service.ts:448-460`). With `ELASTICSEARCH_URL` set, Elasticsearch is tried. Any throw is
logged and falls through to Fuse.js. Without the setting, Fuse.js runs at once.

**Elasticsearch query** (`search-service.ts:285-445`, index `tsr-articles`, line 13)
- Filter (lines 296-301): `term status: "publish"`, plus `terms categories: [category]` when given.
  The index keeps each file's own `status`, so the 2 articles whose status is `published` (not `publish`) are never found.
- Query expansion:
  - `normalizeArabicTransliteration` (lines 179-213) is a fixed chain of regex replacements: digits as letters (2, 3 dropped;
    5→kh, 6→t, 7→h, 8→q, 9→s), doubled vowels, `dh`→z, `th`→s, `gh`→g, `kh`→k, `sh`→s, word-final `ah`/`eh`, final h or p,
    final y, and the hussain/hussein/husein spellings.
  - `expandedQuery` is `q + " " + normalized`. Then the synonyms of every key found in the lower-cased `q` or in the normalized
    text are appended (synonym table lines 304-326; loop lines 332-338).
  - `extractSearchTerms` (lines 216-255): replace the first occurrence of five name phrases, split on white space, drop words
    of 2 characters or fewer and stopwords, then join `imam` with the next word.
- `bool.should`, `minimum_should_match: 1` (lines 344-405):
  1. `match_phrase title {q, boost 15, slop 3}`
  2. `match_phrase content {q, boost 5, slop 3}`
  3. `bool must [ one multi_match per term: query term + " " + its synonyms, fields title^3, excerpt, best_fields ], boost 30`.
     **Quirk:** when no term is left (for example "of the"), `must` is empty, so this clause matches every article.
  4. `multi_match {q, fields title^4 excerpt^2 content tags^1.5, cross_fields, operator or}`
  5. `multi_match {expandedQuery, fields title^2 excerpt^1.5 content tags, best_fields, fuzziness AUTO}`
- `size` is limit and `from` is offset. `_source` excludes `content_embedding`, `title_embedding` and `content` (lines 406-410).
- Highlights (lines 411-419): `<em>`/`</em>`; `title` gives whole field (0 fragments); `excerpt` gives 1 fragment of 200;
  `content` gives 3 fragments of 150.
- Result fields, in this order (lines 422-437): `id` (always 0), `slug`, `title`, `excerpt`, `publishedDate` (or ""), `modifiedDate`,
  `featuredImage`, `author` (or "admin"), `categories` (or []), `tags` (or []), `language` (or "en"), `readingTime` (always 1),
  `score` (`_score` or 0), `highlights` (Elasticsearch's own object). Undefined fields are left out. The index has no
  `featuredImage`, so it is never sent.
- `data` is `{results, query, searchEngine: "elasticsearch", took}`. `took` is wall-clock milliseconds.

**The live index has no article body.** The runtime reindex (`api/lib/reindex-service.ts:89-123`) takes its articles from
`getPublishedPosts` (`src/lib/markdown.ts:136`). That reads front matter only (`getAllPosts`, `matter()` `data`, line 118), so
`content: article.content || article.rawContent || ''` (line 113) is empty. The script `scripts/index-to-elasticsearch.ts:54,65`
does index the Markdown body. Production follows `DEPLOYMENT.md` §5, which calls the reindex route. Measured on the live site, 27 Nov 2026:
`q=patience` returns 1 article with only an `excerpt` highlight, while 65 article files contain the word. `q=karbala` returns
10 results with only `title` and `excerpt` highlights. See decision 4c.

**Fuse.js fallback** (`search-service.ts:61-171`)
- Reads every published article with its Markdown body (`rawContent`). The list is cached for 5 minutes (line 35).
- Keys and weights (lines 81-87): title 2, excerpt 1.5, rawContent 1, tags 1.2, categories 0.8. Options: `threshold 0.4`,
  `minMatchCharLength 2`, `ignoreLocation`, `useExtendedSearch` (lines 88-94). Under extended search, words separated by a space
  must all match, and `'`, `!`, `^`, `=` and `|` are operators.
- The category is filtered after the search, by exact membership (lines 147-151). Then `offset`/`limit` are applied.
- Each result is the list item (`transformToListItem`, lines 44-59: front matter `id` or 0, `readingTime` = words/200 rounded
  up, at least 1), plus `score` = 1 − Fuse score, plus `highlights` (lines 100-137). Highlights cover at most 3 matches per
  field among title, excerpt and content, each with 30 characters of context, "..." at a cut, and the first occurrence of the
  match text wrapped in `<em>`.
- `searchEngine` is `fuse`.

**Pagination** (route lines 113-118): `total` = results on this page; `limit`; `offset`; `hasMore` = (results on this page == limit).

**Cache** (lines 102-108; `api/lib/cache-utils.ts:14,19-54`): `Cache-Control: public, max-age=60` (no stale-while-revalidate),
`ETag` = MD5 of `JSON.stringify({query, category, resultsCount})`, `Vary: Accept-Encoding`. The route never compares
`If-None-Match`, so it never answers 304. `meta.cache.maxAge` is 60.
The middleware (`src/middleware.ts:43-45`) adds the three `Access-Control-*` headers to every `/api/` answer.

**Rate limit** (route line 16; `api/lib/rate-limit.ts`)
- Fixed window of 60 s per client key, limit `SEARCH_RATE_LIMIT` (default 60). Lines 38-60.
- A refused request still counts. Expired windows are swept at most once a minute.
- The key is the **first** `X-Forwarded-For` entry, else `X-Real-IP`, else "unknown" (lines 64-68).
- The 429 body is `{"success": false, "error": "Too many requests"}`: `error` is a string and there is no `meta`. Headers:
  `Retry-After` (seconds to the window's end, rounded up), `X-RateLimit-Limit`, `X-RateLimit-Remaining: 0`.

**Analytics** (route lines 90-99; `api/lib/analytics-service.ts:112-132`). Only when `offset` is 0 and the trimmed query is not
empty, it writes fire-and-forget to index `tsr-analytics` (line 19). Fields: `ts`, `type: search`, `surface`, `query` (cut to 512),
`query_norm` (trimmed, lower-cased, spaces folded, cut to 512), `result_count`, `zero_results`, `engine`, `took_ms`, and
`language`/`category` when set. Mapping at lines 42-60. A failure is swallowed and warned once per process.

### 2.2 `GET /api/v1/lectures/search` (`src/app/api/v1/lectures/search/route.ts`)

**Parameters** (lines 69-76)
- `q`: optional, used **untrimmed** (`searchParams.get('q') || ''`). Blank after trim means browse (`lectures-search-service.ts:332`).
- `limit` and `offset`: as article search.
- `language`: one value, an exact `term` filter; empty means none.
- The rate limit is as article search, with its own setting `LECTURES_SEARCH_RATE_LIMIT` (default 60, line 17).

**No client means a failure.** Without `ELASTICSEARCH_URL`, `searchLectures` throws (`api/lib/lectures-search-service.ts:322-325`),
which answers 500 `INTERNAL_ERROR`. An Elasticsearch failure does the same. There is no fallback.

**Browse** (lines 274-314)
- `bool {must match_all, filter}`, sort `publishedDate desc, missing _last`, `size` limit, `from` offset, `track_total_hits`,
  `_source` excludes `content` and `embedding`.
- Each result has `score` 0, `matchedChapters` [] and no `highlights`. `query` is "", `searchEngine` is `elasticsearch`, and
  `total` is the hit total.

**Search: keyword query** (`buildQuery(fuzzy)`, lines 354-431). Same expansion helpers as articles (copied at lines 122-213).
`should`, `minimum_should_match 1`, filter `term language` when given:
1. `match_phrase title {q, boost 15, slop 3}`
2. `match_phrase content {q, boost 5, slop 3}` (content is the transcript)
3. `bool must [multi_match per term: fields title^3, excerpt, search_phrases^2, best_fields], boost 30` (same empty-must quirk)
4. `multi_match {q, title^4 excerpt^2 search_phrases^3 key_points^1.5 content tags^1.5, cross_fields, or}`
5. `multi_match {expandedQuery, title^2 excerpt^1.5 search_phrases^2 content tags, best_fields}`. In the fuzzy stage only, its
   `fields` become `["content"]` with `fuzziness AUTO` (line 394).
6. `nested path chapters`: `multi_match {expandedQuery, chapters.title^2 chapters.summary, best_fields}` (fuzziness AUTO in the
   fuzzy stage), `score_mode max`, `boost 8`. `inner_hits` is named `matched_chapters`, size 3, `_source` start_sec/title/summary/url.
   Its highlight is `chapters.title` whole and `chapters.summary` 1 fragment of 160 (lines 399-426).

**Common body** (lines 436-453)
- `size` = 50 and `from` = 0 when the meaning layer is on; otherwise `size` = limit and `from` = offset.
- `track_total_hits`. `_source` excludes `content` and `embedding`.
- Highlights: title whole; excerpt 1×200; content 2×150; search_phrases 2×120; key_points 2×150.

**Fuzzy retry** (lines 457-465): run the strict query. If its hit **total** (not the page) is below 3 (line 6), run the fuzzy
query once and use that answer instead.

**Meaning layer** (lines 8-25, 29-66, 474-503)
- It is on when `LECTURES_SEMANTIC_WEIGHT` > 0 and `EMBEDDINGS_URL` is set. BM25 weight `LECTURES_BM25_WEIGHT` defaults to 1.
- The query vector comes from `POST {EMBEDDINGS_URL}/embed` with body `{"texts": [q], "mode": "query"}`. The timeout is
  `EMBED_TIMEOUT_MS` (default 1500). The answer's `vectors[0]` is used. A failure, a non-200 or a missing vector gives null.
- With a vector, a second search runs: `knn {field embedding, query_vector, k 50, num_candidates 200, filter (the language
  filter, when given)}`, `size 50`, the same `_source` excludes.
- Fusion is `rrfFuse` (lines 49-66). For each list in order (BM25 first), each hit at 0-based place `i` adds
  `weight / (60 + i + 1)` to its slug's score. The first list's hit object is kept (so a lecture in both keeps BM25's
  highlights and matched chapters). Then a stable sort by score, descending: equal scores keep first-met order.
- `total` = the length of the fused list (at most 100). The page is `fused[offset .. offset+limit]`. `searchEngine` is
  `elasticsearch+semantic`. `score` is each kept hit's own `_score`, not the fused score.
- **Quirk, no vector with the layer on:** the hits are the BM25 pool of 50 sliced by offset/limit, and `total` stays the BM25
  hit total. A page at offset 50 or more is empty while `hasMore` can be true.

**Result fields, in order** (`toResult`, lines 244-270): `slug`, `title`, `url`, `excerpt`, `tags` (or []), `language` (or "en"),
`publishedDate`, `durationSec`, `chapters` (or []), `matchedChapters` (each inner hit's `_source` plus `highlight {title, summary}`
when highlighted), `key_points` (or []), `thumbnail` (`https://i.ytimg.com/vi/<slug>/mqdefault.jpg`), `score`, `highlights`.
`data` is `{results, query, searchEngine, total, took}`.

**Pagination** (route lines 104-109): `total` = `data.total`; `hasMore` = offset + results on this page < total.
**Cache:** as article search. The ETag is MD5 of `{query, language, total}` (lines 93-97). Never a 304.
**Analytics:** as article search, with `surface: lectures`, `result_count` = `total`, and `language` (lines 82-91). Browse is skipped.

### 2.3 The indexes and the embedding service
- **`tsr-articles`** (`reindex-service.ts:13-54`): 1 shard, 0 replicas. Analyzer `multilingual_analyzer` = standard tokenizer,
  `html_strip`, `lowercase`, `asciifolding`. Text fields with that analyzer: title (+ `keyword`), excerpt, content. Keyword fields:
  slug, categories, tags, author, language, status. Date fields: publishedDate, modifiedDate, indexed_at. Document id = slug.
- **`tsr-lectures`** (`api/lib/lectures-index.ts:12-72`): same settings. Text: title (+keyword), excerpt, content (transcript),
  search_phrases, key_points. Keyword: slug, tags, language, url. Also publishedDate (date) and durationSec (integer).
  `chapters` is nested: start_sec integer, title and summary text, url keyword.
  `embedding` is `dense_vector` with 384 dims, `index true`, `similarity cosine`, `index_options {type: flat}`. indexed_at is a date.
- **Feeding.** Both are full reconciles started by hand through secret-protected POST routes. Each ensures the index, bulk-indexes
  in batches of 100 (refreshing on the last batch), then deletes ids not seen. An empty source refuses to run
  (`reindex-service.ts:89-94`, `reindex-lectures-service.ts:66-107`). The lecture documents are the data file's lines as they are,
  plus `indexed_at`.
- **Lecture data** (`content/lectures/lectures.ndjson`): 917 lines and 22,696,447 bytes. Keys: slug, title, url, excerpt,
  content, search_phrases, key_points, tags, language, publishedDate, durationSec, chapters (start_sec, title, summary, url),
  embedding. **19 lectures have no `embedding`** (the ones recovered on 15-16 Sep 2026), so kNN never returns them.
  Measured sizes: 15.4 MB without vectors; 10.5 MB without transcripts; 3.2 MB without both; vectors alone 7.25 MB;
  the whole file gzipped 8.5 MB. Languages: hi 846, en 41, ur 27, ar 3.
- **Embedding service** (tsr-web `embeddings/`, 163 lines: FastAPI + fastembed, `python:3.12-slim`, uv). It serves
  `POST /embed {texts, mode}` → `{vectors, dim, model, mode, count}`, `POST /tokens`, and `GET /health`. The model is
  **`BAAI/bge-small-en-v1.5`**, baked into the image at build (`embeddings/Dockerfile`, `warmup.py` asserts 384 dims). It is
  not all-MiniLM-L6-v2 (decision 4d). Measured by tsr-web (`DEPLOYMENT.md` §1): 490 MB image, about 258 MB steady memory,
  limit 1 GB. A bulk re-embed drives it to about 1.5 GB and the memory is kept, so tsr-web never embeds on production (§8).
- **The weight.** 0.25 is "the evaluated value" (`DEPLOYMENT.md:123,130`; the comment in tsr-web's root `docker-compose.yml`).
  Both default to 0. The live site answered `elasticsearch+semantic` on 27 Nov 2026 (`q=grief`, total 79), so production sets it
  above 0 in Dokploy. The exact value is not in the repository (decision 4d).

### 2.4 What the app reads (`hosts/app/lib/features/wordpress/services/tsr_web_service.dart:137-206`)
- Article search sends `q`, `limit`, `offset`, and `category`/`fields` when set (callers `tsr_providers.dart:156`,
  `search_repository.dart:91`). `TsrSearchResult` reads `results`, `query` and `total`. This route sends no `data.total`,
  so the app gets 0 (`recon.md` §2). Each result is read as an article list item.
- Lecture search sends `q` and `limit` only (`search_repository.dart:110`). It reads `data.results` (it throws if that is not a
  list), `data.total`, and per lecture `slug`, `title`, `url`, `thumbnail`, `chapters` and `matchedChapters` (`title`, `start_sec`, `url`).
- Neither reads `searchEngine`, `score`, `highlights` or `took`. The base address is the constant `_base`
  (`tsr_web_service.dart:14`), which is also used to resolve publication links (line 382).

---

## 3. Plan

### 3.1 Ownership

**Recommendation: `search` owns both routes, both indexes and their feed.** This follows the table in `domains/CLAUDE.md`
("search: read model only ... global and public search") and the website port's `operations.csv` (proposed domain `search` for both).
The Elasticsearch client, its settings, the raw-JSON transport and the reconcile pattern are already there.

What this costs:
1. **`V1` moves to `shared/api`** as `shared/api/WebsiteV1.cs` (public class `WebsiteV1`, same code). Today it is `internal` to content
   (`domains/content/api/domain/V1.cs`), and a second domain now needs it. It is wire-shape plumbing with no business rule.
   This is a first task that changes no behaviour: content's six slices and `db/tests/V1FailureTests.cs` change only their `using` lines.
2. **content publishes a view** `content.v_published_articles` in a new migration. It is read by the article feed and by the
   database fallback (rule 2: search reads content's tables only through it).
3. **`domains/search/spec/api.yaml`** says every error is `{"detail"}`. Its header gains the named exception for the two `/api/v1/` paths.

The alternative is that content owns them. That would need a second Elasticsearch client, settings and transport in content, and
content would grow a feed worker. The two indexes and `tsr-search` would then have two owners' code for one engine. That costs more.
`SearchModule.Dependencies` stays `["access"]`: views are not listed there (as `membership.v_members` today).

### 3.2 How the queries are built (AOT)
- Both queries are written as JSON with `Utf8JsonWriter`. The caller's text goes only into string values (SRCH-Q3).
- They are sent through the existing client's transport (`ElasticSearchIndex.Writer.cs` `SendAsync`, plain JSON content type),
  and the answer is read with `JsonDocument`.
- No typed query objects and no typed reading of `inner_hits`, highlight maps or `knn`. Those are the generic, reflection-heavy
  parts of the client that issues 97 and 101 showed fail silently in a native build.
- This departs from `ElasticSearchIndex.cs`'s "typed query objects only" comment. The reason: the source bodies are JSON, so
  writing the same JSON can be compared to tsr-web line by line. The unit tests check the written body against a stored copy
  of the tsr-web body for the same query.
- Hurl against the native image stays the gate (SRCH-Q4).

### 3.3 Files

New, in `domains/search/api/`:

| File | Holds |
|---|---|
| `features/v1-search/V1Search.cs` | the slice `GET /api/v1/search`: rate limit, `q`, numbers, engine choice, answer (`WebsiteV1.OkAlways`), `.WithV1Failures()` |
| `features/v1-lecture-search/V1LectureSearch.cs` | the slice `GET /api/v1/lectures/search` |
| `domain/QueryExpansion.cs` | the four helpers ported character for character: normalize, synonyms, name expansions, terms (shared by both slices, rule 6) |
| `domain/ArticleSearchQuery.cs`, `domain/LectureSearchQuery.cs` | write the Elasticsearch bodies (keyword, browse, kNN); read hits from `JsonDocument` |
| `domain/ReciprocalRank.cs` | `Fuse(IReadOnlyList<(IReadOnlyList<Hit> hits, double weight)>)`: k 60, stable |
| `domain/EmbeddingClient.cs` | `Task<float[]?> EmbedQueryAsync(string q, CancellationToken)`: 1.5 s timeout, null on any failure; an external boundary, so an interface `IQueryEmbedder` for unit tests |
| `domain/ArticleFallback.cs` | the database fallback over `content.v_published_articles` (3.6) |
| `domain/SearchRateLimit.cs` | the 429: `MemberRateLimit` with bucket per route and key `ClientAddress.RateKey` |
| `domain/LibraryIndexMappings.cs` | the two mappings as JSON text (3.4) |
| `domain/LibraryFeed.cs` | one reconcile of one index from a list of documents (ensure, upsert in 100s, delete unseen, refuse when empty) |
| `workers/LibraryFeedWorker.cs` | worker `library-search-feed` |
| `capabilities/library-search.md` | the living capability document (template `docs/templates/capability.md`) |
| tests next to each: `*.Tests.cs` | see section 5 |

Changed:

| File | Change |
|---|---|
| `shared/api/WebsiteV1.cs` (moved from `domains/content/api/domain/V1.cs`) | renamed, public; content's six slices and `db/tests/V1FailureTests.cs` follow |
| `shared/api/MemberRateLimit.cs` | add `RetryAfterSeconds(bucket, token, windowSeconds)`, needed for `Retry-After` (additive) |
| `domains/content/api/Migrations/<new>_PublishedArticlesView.cs` | `content.v_published_articles`: slug, title, excerpt, body_markdown, published_date_text, modified_date_text, author, language, reading_minutes, legacy_id, categories, tags; granted read to the API role |
| `domains/content/CLAUDE.md` | the view in "Published views", reader `search` |
| `domains/search/api/SearchModule.cs` | map the two routes; register the embedder, the rate limit and the worker |
| `domains/search/api/domain/SearchSettings.cs` | the new settings (3.7) |
| `domains/search/api/domain/SearchJson.cs` | nothing, if every new answer is written by hand (`WebsiteV1` takes an `Action<Utf8JsonWriter>`) |
| `domains/search/CLAUDE.md` | the two routes as public reads (rule 4), the indexes, the worker, the settings, and the lock key |
| `domains/search/spec/api.yaml` | the two paths, `security: []`, the shapes of 2.1 and 2.2, and the v1 exception in the header |
| `domains/search/spec/tests/v1-search.hurl`, `v1-lecture-search.hurl` | contract files (section 5) |
| `domains/content/capabilities/lectures.md` | section 2's "out of scope" line: lecture search now exists (LEC-D1 stays unless decision 4f) |
| `hosts/gateway/default.conf` | `location = /api/v1/search` and `location = /api/v1/lectures/search` → `new_api` |
| `hosts/api/tests/RouteCatalog.cs` | both routes in `NotInPhp` |
| `docs/specs/website-port/operations.csv` | both rows' `state` → `built` |
| `db/tests/V1FailureTests.cs` | two more cases |
| `hosts/api/tests/WorkerModeTests.cs`, `HostServices.cs` | the new worker name |
| `hosts/api/Dockerfile` | nothing if the lecture file is mounted (decision 4a); one `COPY` if it is in the repository |
| `docker-compose.yml`, `docker-compose.dev.yml`, `docker-compose.test.yml` | the `embeddings` service and the settings (3.5, 3.7) |
| `hosts/embeddings/` (new: `Dockerfile`, `app.py`, `warmup.py`, `pyproject.toml`, `uv.lock`) | tsr-web's service, copied, with versions pinned |
| `db/synthetic/lectures/lectures.ndjson`, `db/synthetic/lectures/README.md`, `tools/embed-lecture-fixture.sh` | invented test lectures and their vectors (3.5) |
| `tools/search-parity.cases`, `tools/website-parity.allow` | the parity queries and allowances (section 5) |
| `docs/specs/capability-map/README.md`, `docs/status.md` | rows updated |
| root `CLAUDE.md` rule 7, `domains/CLAUDE.md` rule 6, content's "Where things are" table | they name content's `V1` path and "the six Library routes (`domains/content`)": now eight routes in two domains, and `shared/api/WebsiteV1.cs` |
| `hosts/api/tests/ProductionStackTests.cs` | read before task 8: it forbids `seed`, `synthetic`, `emulator`, `Development` and any secret value in `docker-compose.yml`. The `embeddings` service and the lecture-file mount must pass it; the mount's host path is a `${...}` setting, not a literal |

### 3.4 Index mappings
Both are written as tsr-web has them, so a query and an index from either side fit each other:

```json
{ "settings": { "number_of_shards": 1, "number_of_replicas": 0,
    "analysis": { "analyzer": { "multilingual_analyzer": { "type": "custom", "tokenizer": "standard",
      "char_filter": ["html_strip"], "filter": ["lowercase", "asciifolding"] } } } } }
```

- `tsr-articles` mappings: exactly `reindex-service.ts:33-52`.
- `tsr-lectures` mappings: exactly `lectures-index.ts:29-72`, including
  `"embedding": {"type": "dense_vector", "dims": 384, "index": true, "similarity": "cosine", "index_options": {"type": "flat"}}`.

`tsr-search` is unchanged. One owner (search) holds all three.

### 3.5 Feeding, and where the embedding service runs

**Worker `library-search-feed`** (`workers/LibraryFeedWorker.cs`, run mode `--workers`, name in `TSR_WORKERS`). It runs one tick at
start, then every 10 minutes, under its own advisory lock key, 8100002.
- **Articles:** read `content.v_published_articles` and build one document per article with id = slug. Fields: slug, title, excerpt,
  content (the Markdown body; or empty, decision 4c), categories, tags, author, language, publishedDate and modifiedDate as the
  list route writes them, status `publish`, indexed_at.
- **Lectures:** read the file named by `TSR_LECTURES_FILE`, one line per document, keys passed through as they are. A line without
  `embedding` is indexed without the field.
- **Order:** documents are indexed in tsr-web's order (articles as `getAllPosts` sorts them, newest first; lectures in file order).
  Elasticsearch breaks equal scores by internal document order, and several parity cases are mostly ties (the stopword-only query, browse with equal dates).
- **Each index is created at the first tick even when its source is missing**, so a server without the lecture file answers 200 with
  no lectures, not 500 from a missing index (tsr-web refuses before it creates the index, so there it is a 500).
- **Each index:** reconcile as tsr-web does (3.3 `LibraryFeed`). Skip the write when the source's hash equals the last one indexed
  in this process, so the 22 MB file is not re-sent every 10 minutes.
  An empty or unreadable source keeps the index (SRCH-R17) and logs one warning with counts only.
- **Separate from `search-feed`.** Production does not run `search-feed` yet (PHP still feeds `tsr-search`). A separate name lets
  production switch the Library indexes on alone.
- Production has the content in the database after `content-load`, so a worker started after it indexes the deployed articles.

**Embedding service: recommendation.** Copy tsr-web's service as its own container, `hosts/embeddings/`, with the same model,
`BAAI/bge-small-en-v1.5`. The document vectors in the data were made by that container, and query vectors must come from the same
model and pooling (the warning in `DEPLOYMENT.md` §8). Its cost:
- 163 lines of Python, kept as they are.
- One image of about 490 MB. The model is downloaded at build, so the build needs network.
- About 260 MB of memory steady, with a 1 GB limit.
- A health check in Python (the image has no curl; the copied Dockerfile already does this).
- `fastembed` is pinned (tsr-web says `>=0.5`) and a `uv.lock` is committed, so the model and the pooling cannot drift between builds.
- It has a precedent: the stack doc keeps WhatsApp in TypeScript, "in the language that earns it".

Rejected options:
- In-process ONNX in C# (`Microsoft.ML.OnnxRuntime` with `Microsoft.ML.Tokenizers`): its AOT status is not verified, it needs a native
  library in the chiseled image, and it risks a different pooling from the vectors already made.
- A hosted embedding API: a different vector space, so every vector would have to be made again, and queries would leave the server.

**In the stacks**

| Stack | Embedding service | Lecture data |
|---|---|---|
| `docker-compose.yml` (production) | `embeddings` service: internal, no port, `deploy.resources.limits.memory: 1G`; the API gets `TSR_EMBEDDINGS_URL: http://embeddings:8000` | the full file, mounted read-only into `workers` at `TSR_LECTURES_FILE` (decision 4a) |
| `docker-compose.dev.yml` | `embeddings` under the profile `workers` (as `elasticsearch`) | the full file from a host path, mounted read-only |
| `docker-compose.test.yml` (default test stack) | on; the default stack runs the meaning-layer Hurl file | `db/synthetic/lectures/lectures.ndjson` |
| lanes (`TSR_STACK=n`) | off (`TSR_EMBEDDINGS_URL` empty): 8 lanes × 260 MB is not worth it; they prove BM25 and the fallback (SRCH-R11) | the same synthetic file |

The **synthetic lecture fixture** has about 12 invented lectures, in hi, en and ar, with chapters, phrases and short invented
transcripts. Each case of section 5 is one lecture. `tools/embed-lecture-fixture.sh` runs the fixture through the test stack's
embedding container (passage mode, as tsr-web's script does), and the vectors are committed. One lecture is left without a vector on purpose.

### 3.6 The article fallback (SRCH-R6)
tsr-web falls back to Fuse.js: fuzzy matching (Bitap, threshold 0.4) over title, excerpt, body, tags and categories.

**Recommendation: a plain SQL fallback, not a Fuse.js port.** It runs on `content.v_published_articles` with prepared parameters:
- Each word of `q` (split on white space, 2 characters or more) must occur, case-insensitive (`ILIKE`, with `%`, `_` and `\` escaped),
  in at least one of title, excerpt, body, tags or categories. This is extended search's "every word" rule.
- Rank by a weighted count of the fields matched: Fuse's weights 2, 1.5, 1, 1.2 and 0.8. Equal ranks are ordered newest first.
- The category is an exact member. Then offset and limit.
- `id` = legacy id or 0; `readingTime` = the stored reading minutes. `highlights` are built by the same rule as Fuse's
  (3 matches, 30 characters, `<em>`) on the literal word found.
- `score` = rank / the best rank, from 0 to 1. `searchEngine` stays `fuse`: it is a value of the published shape, and no client reads it.

What differs from Fuse.js: a misspelt word finds nothing; the operators `'`, `!`, `^`, `=` and `|` are ordinary text; the order
of results and the scores differ. It runs only while Elasticsearch is down. 500 articles read in one query is well inside the read
target. A Fuse port would be a few hundred lines of Bitap with no test oracle, for a path that is rarely used.

### 3.7 Settings (all optional; the API starts without them, SRCH-Q6)

| Name | Read by | Meaning |
|---|---|---|
| `TSR_ELASTICSEARCH_URL`, `TSR_ELASTICSEARCH_PASSWORD` | existing | Unset: article search uses the fallback; lecture search answers 500 |
| `TSR_EMBEDDINGS_URL` | lecture search | The embedding service. Empty: the meaning layer is off |
| `TSR_LECTURES_SEMANTIC_WEIGHT` | lecture search | A number ≥ 0; 0 or unset = off. The compose files set `0.25` (decision 4d) |
| `TSR_LECTURES_FILE` | `library-search-feed` | Path of the full lecture data inside the container. Unset: the lecture index is left as it is |

Kept as constants (tsr-web settings that nobody sets): BM25 weight 1, embed timeout 1500 ms, both rate limits 60 a minute, and the
index names `tsr-articles` and `tsr-lectures`. Changing one is a one-line change with its test.

### 3.8 Catalog, gateway, `api.yaml`
- The route catalog: both in `RouteCatalog.NotInPhp`, as the six Library routes are. `docs/specs/website-port/operations.csv` rows set to `built`.
- The gateway: two `location =` blocks, after the Library ones (`hosts/gateway/default.conf:86-91`).
- `spec/api.yaml`: both paths, `security: []`; the answer and failure shapes; the 429 body; the `searchEngine` values.

### 3.9 What the app must change
Nothing in its code reads a new field, so **the answers need no app change.**
Reaching the new API is the same question as for the six Library routes, which the app still calls on `https://thestrongrope.com`
(`_base`, line 14). Either production routes `thestrongrope.com/api/v1/*` to the API, and the app changes nothing; or `_base` changes.
If `_base` changes, it also moves the base used to resolve publication files (line 382), which the API does not serve. So that is
more than a one-line change (decision 4e).

### 3.10 Deliberate differences from tsr-web
Each one is written in the capability document and allowed in the parity file:
1. The `ETag` is over `data` and `pagination` (as the Library routes), not over `{query, category, count}`. Nobody compares it.
2. The rate limit key is the caller's address after the trusted proxies (`ClientAddress`), not the first `X-Forwarded-For`
   entry, which any client can write. The window slides and a refused request is not counted (`MemberRateLimit`).
3. The 2 articles with status `published` are found (the view holds only published articles; the status filter is written as `publish` for all).
4. The fallback is SQL, not Fuse.js (3.6).
5. Analytics: none (decision 4b).
6. `X-Content-Type-Options: nosniff` on every answer (already true of `WebsiteV1`).
7. A missing lecture index is created empty by the feed, so lecture search answers 200 with no results where tsr-web answers 500.
8. Highlights are HTML-encoded (added 28 Nov 2026): `"encoder": "html"` on the engine's highlight request, and the fallback encodes the text around the match before it adds `<em>`. tsr-web does not encode, so its highlight can carry article markup. Parity: the stored bodies equal tsr-web's except that one field, and a parity run must allow highlight text that differs only by HTML entities (`&amp;`, `&lt;`, `&gt;`, `&quot;`, `&#39;`).
9. Both routes refuse a page that ends past Elasticsearch's 10000-result window (offset plus limit above 10000) and a text of more than 200 characters, and a language that is not at most 10 letters and hyphens (lecture search) or a category of more than 100 characters (article search), with a 400 `VALIDATION_ERROR` in the website's error shape, before any outside call. tsr-web has neither bound.
10. Lecture highlights, the lecture's and its matched chapters', are HTML-encoded (`"encoder": "html"` in each highlight object of the engine requests), as the article ones are (8).
11. A query vector that is not 384 numbers counts as no vector (or holds a number that is not finite, or is all zeros), so lecture search answers from keywords only; tsr-web would send it to the engine, which refuses it, and answer 500.
12. `TSR_LECTURES_FILE` unset, missing, too big (64 MB, 5000 lectures) or not whole (a line that is not a lecture, a slug twice): the lecture index is created empty at the first tick and otherwise kept as it is, with one warning of counts. tsr-web has no such file setting (its feed is a manual route).
13. The feed asks for a short retry (30 seconds, at most 20 in a row) only while the ARTICLES are empty, the start-up race; an empty lecture file is not a race.
14. The lecture file in tsr-app (12a) is tsr-web's, except that each phone-like run in a text key (10 to 13 digits, or 4 or more digits within 80 characters after whatsapp, phone, mobile or contact and then number or no, or after a `[number removed]`) (`title`, `excerpt`, `content`, `search_phrases`, `key_points`, `tags`, a chapter's `title` and `summary`) is replaced by `[number removed]` at import (LEC-R10, regex in `tools/content-import.sh`). The vectors are tsr-web's, computed from the unmasked text. A phrase search for a spoken number finds nothing here; parity cases must not use one.

---

## 4. Open decisions for the owner

**Decided by the owner on 27 Nov 2026. Where a line below or in sections 1, 3, 5 and 6 says otherwise, these win:**

- **(a) Option 1: the full lecture file is committed to this repository.** `content/lectures/lectures.ndjson` becomes the full file
  (transcripts and vectors); `tools/content-import.sh` stops trimming it; LEC-R8 and LEC-R9 are rewritten (the guard checks the full
  key set instead of the eight); the static site keeps reading the keys it reads today and ignores the rest. The image that runs
  `library-search-feed` carries the file (`hosts/api/Dockerfile`, one `COPY`), so no mount and no `${...}` host path. The owner
  accepts that the transcripts are public in git for good.
- **(b) Analytics is ported**, not dropped: the event written on a first-page search (both routes) to the index `tsr-analytics`, and
  the click route `POST /api/v1/events`, as tsr-web does them (fire and forget, no IP, cookie or user agent stored, its rate limit).
  SRCH-R18 and difference 5 of section 3.10 are reversed. The report route `GET /api/admin/analytics` (shared secret) is NOT in
  this change; it is listed as not ported.
- **(c) The article index holds no body, as the live site today**, so parity is exact. Indexing the body is a separate later change.
- **(d) The model is `BAAI/bge-small-en-v1.5`, as tsr-web's service runs.** The weight is 0.25 unless production's setting is found to differ.
- **(d2) Lecture search with Elasticsearch down answers as tsr-web does (500 in the v1 error shape).**
- **(e) and (f): as recommended** (no app change in this issue; the site's lecture page stays as it is).

**(a) Where the full lecture data comes from.** The index needs transcripts (`content`) and vectors (`embedding`). The repo's
`content/lectures/lectures.ndjson` holds eight keys on purpose (LEC-R8, LEC-R9, the guard). tsr-app is public, tsr-web is private,
and Dokploy builds from the public repository.

| Option | Size | Privacy and cost |
|---|---|---|
| 1. Commit the full file to tsr-app (13 keys) | +22.7 MB a copy (8.5 MB packed); each re-embed adds about 7 MB to history | Every transcript is public for good, including those of videos later made private or unlisted (tsr-web's 20 Jul 2026 sweep dropped 48 such). LEC-R8 and LEC-R9 are reversed. It is the simplest feed: the file goes in the image. |
| 2. Commit vectors but no transcripts | +10.5 MB | Loses the transcript match (`match_phrase content` boost 5, the fuzzy stage, content highlights): not faithful (decision 2). |
| 3. **Mount the full file at run time** (`TSR_LECTURES_FILE`, read-only into `workers`), copied from tsr-web or the private data repository | 22.7 MB on the server, none in git | Transcripts stay private. One manual step per lecture refresh (copy the file to the server; whether Dokploy can hold a 22 MB file as a file mount is to verify, else a host path). Vectors are precomputed: never embed on production (`DEPLOYMENT.md` §8). |
| 4. Index without transcripts and embed at feed time | 3.2 MB | Not faithful, and a bulk embed on production costs about 1.5 GB of memory. |

**Recommendation: option 3.** It keeps the public repository free of transcripts, needs no change to LEC-R8 or LEC-R9, and costs one
mount and one documented copy step. Test stacks use the synthetic fixture. Choose option 1 instead only if transcripts of public
lectures may be public for good. It is the cheaper build.

**(b) Search analytics (issue 40).** tsr-web writes every first-page search to its own index `tsr-analytics`, and clicks through
`POST /api/v1/events`. The app never calls the click route. **Recommendation: drop it for now.** Write no event (SRCH-R18) and
leave issue 40 to decide whether it returns. Porting it would add an index, a fire-and-forget writer and a query store, before
anyone has said they read it.

**(c) The article body.** The code means to search article bodies, but the live index has none (2.1). The port can:
- index the body (the code's intent and the script's behaviour): better recall, but answers differ from today's on many queries; or
- index no body (today's live behaviour): parity is exact, but phrase matches inside articles stay unfound.

**Recommendation: index the body.** Run parity first with the body left out, which proves the port is exact. Then switch the body
on as a separate, reviewed change. One field in the feed: `content`.

**(d) The model and the weight.** Decision 2 names all-MiniLM-L6-v2, but tsr-web's service runs **BAAI/bge-small-en-v1.5**, and
it has since the first lecture-search commit. MiniLM appears only in stale comments (`embeddings/pyproject.toml`,
`lectures-index.ts:8`). Both give 384 numbers, so the wrong model would not fail. It would quietly make the meaning ranking noise.
**Recommendation: port bge-small-en-v1.5 as built**, and please confirm. The weight: 0.25 is the evaluated value in tsr-web's docs.
Please confirm that production's Dokploy setting is 0.25; it cannot be read from the repository.

**(d2) Lecture search with Elasticsearch down.** Decision 4 can be read as "lecture search falls back to BM25". tsr-web's
fallback to BM25 is only for the embedding service being down. With Elasticsearch down, lecture search answers 500 and has no
fallback (`lectures-search-service.ts:322-325`). The plan keeps that (SRCH-R12). Please confirm; a 503 or an empty list would be a new behaviour.

**(e) How the app reaches these routes.** Route `thestrongrope.com/api/v1/*` to the new API at the cut-over (no app change), or
change `_base` in a new app build (and the publication-file base with it). This is shared with the six Library routes.
Recommendation: the routing, which works for released builds too. It is decided with the cut-over, not in this issue.

**(f) The site's `/lectures/` page.** LEC-D1 says the page is built from the file "until lecture search (issue 22) is built".
Recommendation: keep the page as it is in this issue and change only LEC-D1's wording. Moving the page to the API is its own change.

---

## 5. Verification plan

Test types: **U** NUnit unit tests next to the code (`dotnet test domains/search/api/tests`, fakes for the index and the embedder,
reflection off). **D** `db/tests` (Docker: Postgres; the fallback, the view, the feed's reads). **H** Hurl on a synthetic stack
(**HT** the default test stack with Elasticsearch and embeddings; **HL** a lane, no embeddings). **P** parity: a lane loaded with
tsr-web's articles and the full lecture file, against a local tsr-web whose stack was reindexed. The same tool and allow-file
method as `parity-results.md`, with cases in `tools/search-parity.cases`. The live site is a sanity check only.

| ID | Given | When | Then | Type |
|---|---|---|---|---|
| TC-SRCH-R1-01 | the synthetic articles indexed | `GET /api/v1/search?q=<a title word>` | 200; `success` true; `data` keys `results, query, searchEngine, took`; first result is that article; fields in the order of 2.1; `id` 0, `readingTime` 1 | HT |
| TC-SRCH-R1-02 | a query | the article body is written | it equals the stored tsr-web body for that query (all five clauses, highlights, `_source` excludes) | U |
| TC-SRCH-R1-03 | `q` = "of the" | the body is written | clause 3 has an empty `must` (the quirk kept) | U |
| TC-SRCH-R1-04 | the table of example inputs from tsr-web's helpers (`7usain`, `Fatimah`, `ameerul momineen tears`, ...) | normalize, expand, terms | the outputs equal tsr-web's (computed once with node, stored in the test) | U |
| TC-SRCH-R2-01 | — | `q` missing, empty, or "   " | 400; `error.code` `VALIDATION_ERROR`; message `Missing required parameter: q`; `meta.cache.maxAge` 0 | HL |
| TC-SRCH-R3-01 | — | `limit` = 0, 500, "abc", "7x"; `offset` = -3 | `pagination.limit` 1, 100, 20, 7; `offset` 0 | HL |
| TC-SRCH-R4-01 | two matching articles in different categories | `&category=<one>` | only that category's article | HT |
| TC-SRCH-R5-01 | three matching articles | `limit=2`, then `limit=5` | `total` 2, `hasMore` true; then `total` 3, `hasMore` false | HT |
| TC-SRCH-R6-01 | `TSR_ELASTICSEARCH_URL` unset | an article search | 200; `searchEngine` `fuse`; results from the view; highlight with `<em>` | D |
| TC-SRCH-R6-02 | the index answers 500 or times out (fake) | an article search | the fallback answers; no 500 | U |
| TC-SRCH-R6-03 | `q` holds `%` and `_` | the fallback runs | they match literally | D |
| TC-SRCH-R7-01 | the fixture indexed | `GET /api/v1/lectures/search?q=<a chapter title phrase>` | 200; that lecture first; `matchedChapters[0]` has `start_sec`, `title`, `url`, `highlight.title` with `<em>` | HT |
| TC-SRCH-R7-02 | a strict query with fewer than 3 hits in total | the search runs | a second, fuzzy body is sent (only `content` fuzzy in clause 5; chapters fuzzy) and its answer is used | U |
| TC-SRCH-R7-03 | a misspelt word that the fixture holds in one transcript | search | that lecture is found | HT |
| TC-SRCH-R8-01 | the fixture | `q` absent, then `q=%20` | newest first; `query` ""; `total` = fixture count; `score` 0; `matchedChapters` [] | HL |
| TC-SRCH-R9-01 | lectures in hi and en | `language=en` | only en, with the layer on and off | HT, HL |
| TC-SRCH-R9-02 | `language` given and the layer on | the kNN body is written | it holds the same `term language` filter | U |
| TC-SRCH-R10-01 | the layer on (weight 0.25, embeddings up) | a concept query that matches no keyword of the target lecture | `searchEngine` `elasticsearch+semantic`; the target is in the results; `total` ≤ 100 | HT |
| TC-SRCH-R10-02 | two ranked lists with a tie | `ReciprocalRank.Fuse` | scores `w/(61+i)`; BM25's hit kept for duplicates; ties keep first-met order | U |
| TC-SRCH-R10-03 | the fixture lecture with no vector | indexed and searched with the layer on | indexed without error; found by keywords only | HT |
| TC-SRCH-R11-01 | a lane (no embedding URL), weight 0.25 | a search | `searchEngine` `elasticsearch`; 200 | HL |
| TC-SRCH-R11-02 | the embedder fake answers 500, late (2 s) or with no `vectors` | a search with the layer on | keyword answer from the pool of 50; `total` = BM25 total (quirk kept) | U |
| TC-SRCH-R12-01 | `TSR_ELASTICSEARCH_URL` unset | a lecture search, with and without `q` | 500; `INTERNAL_ERROR`; "An unexpected error occurred"; nothing else of the failure | D (`V1FailureTests`) |
| TC-SRCH-R13-01 | the fixture, 12 lectures | browse with `limit=5&offset=10` | 2 results; `total` 12; `hasMore` false | HL |
| TC-SRCH-R14-01 | one client | 61 requests within a minute to one route | the 61st is 429 with the string `error`, `Retry-After` ≥ 1, `X-RateLimit-Limit: 60`, `X-RateLimit-Remaining: 0`, CORS headers | U (in-process, with a fake clock); HL (Hurl `repeat`) |
| TC-SRCH-R14-02 | 60 requests to article search | a lecture search | 200 (separate buckets) | U |
| TC-SRCH-R15-01 | — | any 200; then the same with `If-None-Match: <its ETag>` | `Cache-Control: public, max-age=60`; `ETag`; `Vary`; the second is 200, not 304 | HL |
| TC-SRCH-R16-01 | a handler throws (the test host's broken data source) | either route | 500 in the v1 shape | D (`V1FailureTests`) |
| TC-SRCH-R17-01 | an index holding an extra document | a feed tick | the extra is deleted; the published set is indexed | D + a real index on HT (worker log line) |
| TC-SRCH-R17-02 | the view returns no rows, or the file is missing or empty | a feed tick | nothing is written or deleted; one warning with counts only | U |
| TC-SRCH-R17-03 | an unchanged source | a second tick | no bulk request is sent | U |
| TC-SRCH-R18-01 | any search | it answers | no request to any analytics index (the fake index records only the search requests) | U |
| TC-SRCH-Q1-01 | indexes freshly created on both sides, in the same order; a lane with tsr-web's 501 articles (body as decided in 4c) and the full lecture file; local tsr-web reindexed on the same Elasticsearch version with the same embedding image | `tools/search-parity.cases`: about 40 queries, including the quirks (stopword-only query, typo, transliteration, name expansions, a category, `language`, offset 40 and 60 with the layer on) | same slugs in the same order, same fields and values; allowed: `took`, `meta.*`, `ETag`, the 2 `published` articles, and `score` only within 1e-6 | P |
| TC-SRCH-Q2-01 | the default test stack, the layer on | 100 sequential lecture searches through the gateway, paced under the rate limit (section 7, risk 7) | 95th fastest ≤ 300 ms | P (`--timing`) |
| TC-SRCH-Q3-01 | `q` = `"} , {"match_all": {}} ` and `q` = `*:*` | the body is written | it is a JSON string value; the body parses as one object of the expected shape | U |
| TC-SRCH-Q3-02 | a search runs | the logs are read | no line holds the query text | U (log capture) |
| TC-SRCH-Q4-01 | the native image on the test stack | `v1-search.hurl`, `v1-lecture-search.hurl` | pass | HT |
| TC-SRCH-Q5-01 | the default test stack after the Q2 run | `docker stats` on `embeddings` | under 1 GB; about 260 MB | Demonstration |
| TC-SRCH-Q6-01 | no Elasticsearch and no embedding URL | the API starts | `/health` 200; article search 200 (`fuse`); lecture search 500 | D |

Ordinary repo checks run on every task: `dotnet build TsrApp.slnx` (zero warnings), `dotnet test hosts/api/tests`
(catalog, public surface, AOT analyzer list, `ConvertedJsonUseTests`, worker mode), `dotnet test domains/content/api/tests`.

---

## 6. Tasks (one sitting each, in order)

- [x] **1. Move `V1` to `shared/api/WebsiteV1.cs`.** Content's six slices and `db/tests/V1FailureTests.cs` follow. No behaviour change.
  Test: `dotnet test db/tests --filter V1`, `tools/contract-website.sh test`.
- [x] **2. Publish `content.v_published_articles`.** Migration, read grant, content `CLAUDE.md` row. Test: a `db/tests` case that
  the view returns the 12 synthetic articles with their bodies, and only published ones.
- [x] **3. Port the query helpers** (`domain/QueryExpansion.cs`). Test: TC-SRCH-R1-04 (expected values computed once from tsr-web with node, stored in the test).
- [x] **4. Article query body and hit reading** (`domain/ArticleSearchQuery.cs`). Test: TC-SRCH-R1-02, R1-03, Q3-01.
- [x] **5. Rate limit** (`MemberRateLimit.RetryAfterSeconds`, `domain/SearchRateLimit.cs`). Test: TC-SRCH-R14-01 (U), R14-02.
- [x] **6. Slice `v1-search` with the SQL fallback** (`features/v1-search/V1Search.cs`, `domain/ArticleFallback.cs`); the gateway block;
  `RouteCatalog.NotInPhp`; `api.yaml`; `V1FailureTests` case. Test: TC-SRCH-R2-01, R3-01, R6-01..03, R15-01, R16-01; `dotnet test hosts/api/tests`.
- [x] **7. Mappings and the feed for articles** (`domain/LibraryIndexMappings.cs`, `domain/LibraryFeed.cs`, `workers/LibraryFeedWorker.cs`,
  worker name in `HostServices.cs` and `WorkerModeTests`; `TSR_WORKERS` in the test compose file). Test: TC-SRCH-R17-01..03;
  `v1-search.hurl` on the default test stack (TC-SRCH-R1-01, R4-01, R5-01).
- [x] **8. The embedding container** (`hosts/embeddings/`, pinned, `uv.lock`; the three compose files; health check). Test: the default test
  stack starts it healthy; `POST /embed` gives 384 numbers; TC-SRCH-Q5-01.
- [x] **9. Lecture fixture** (`db/synthetic/lectures/`, `tools/embed-lecture-fixture.sh`). Test: the content guard style check that the fixture
  has the 13 keys and one line without a vector; the script run twice gives the same vectors.
- [x] **10. Lecture query bodies** (`domain/LectureSearchQuery.cs`: keyword strict and fuzzy, browse, kNN). Test: TC-SRCH-R7-02, R9-02,
  body comparison with stored tsr-web bodies.
- [x] **11. Fusion and the embedder** (`domain/ReciprocalRank.cs`, `domain/EmbeddingClient.cs`). Test: TC-SRCH-R10-02, R11-02.
- [x] **12. Slice `v1-lecture-search`** with the lecture part of the feed, the settings, the gateway block, the catalog and `api.yaml`.
  Test: `v1-lecture-search.hurl` on the default stack and a lane (TC-SRCH-R7-01, R7-03, R8-01, R9-01, R10-01, R10-03, R11-01, R13-01,
  R14-01 HL); TC-SRCH-R12-01 and Q6-01 in `db/tests`.
- [x] **12a. The full lecture file (decision a).** `content/lectures/lectures.ndjson` becomes tsr-web's full file; `tools/content-import.sh`
  stops trimming; LEC-R8 and LEC-R9, the guard and `content/README.md` are rewritten for the full key set; the static site still builds
  from it; the image that runs `library-search-feed` carries it. Test: the content guard, `dotnet test hosts/site/tests`, the lecture feed on a lane.
- [ ] **12b. Analytics (decision b).** The first-page search event from both routes to the index `tsr-analytics`, and the click route
  `POST /api/v1/events`, as tsr-web's `analytics-service.ts` and `events/route.ts` (fire and forget; no IP, cookie or user agent; its
  validation and rate limit). Requirements `SRCH-R18` rewritten and new IDs added in section 1 with their test cases. Test: unit tests
  of the event body and validation; a Hurl file for the click route; a `db/tests` or Hurl case that a search still answers when the event write fails.
- [ ] **13. Native image run.** Build the native image; run both Hurl files on the default test stack. Test: TC-SRCH-Q4-01.
- [ ] **14. Parity.** A local tsr-web with its stack reindexed; a lane with the website's content and the full lecture file;
  `tools/search-parity.cases`; allow lines. Write the result as `docs/specs/website-port/search-parity-results.md`. Test: TC-SRCH-Q1-01, Q2-01.
- [ ] **15. Documents.** `domains/search/capabilities/library-search.md` (requirements linked to their tests), `domains/search/CLAUDE.md`,
  `lectures.md`, the capability map, `docs/status.md`, `docs/deployment.md` (the `embeddings` service, the settings and the lecture file step).
- [ ] **16. (After decision 4c)** switch the article body on, if chosen, as its own change, with the parity allowances it needs.

---

## 7. Size and risks

**Size.** About 1,800 to 2,500 lines with tests: the two slices and their helpers about 900, the feed 250, the fallback 200,
the tests and the Hurl files about 900, plus the copied Python service (163 lines). 15 sittings as listed, about 2 weeks of agent work.
One more sitting is needed if the parity run finds differences that need reading.

**Risks**
1. **The client under AOT.** The known silent failure (a type absent from the generated context reads as empty in a native build) is avoided
   by sending JSON through the transport and reading with `JsonDocument` (3.2). The transport path is already used natively by the
   writer. Remaining risk: a body or reading difference that only the native image shows. Task 13 runs Hurl on the native image before parity.
2. **The vector field.** `dense_vector` with `index_options: flat` and `knn` with a filter must behave the same on Elasticsearch 9.2.3
   with security on, as on tsr-web's unsecured 9.2.3. It is the same version, so the risk is low, and it is covered by TC-SRCH-R10-01.
   The bulk body carries 384 floats per lecture. They must be written as the file has them (pass the line through), never parsed and
   re-printed, or a float could round.
3. **The embedding container on production.** About 260 MB steady, a 1 GB limit, a 490 MB image, and a build that downloads the model
   (a Hugging Face outage fails the deploy build). The first request after start loads the model (the health check's 20 s start period
   covers it). Until it is healthy, lecture search falls back to keywords, by design. Elasticsearch already takes about 1.35 GB on
   the same server: check the headroom before the first deploy (tsr-web `DEPLOYMENT.md` §2b).
4. **Ranking equality.** Exact parity needs the same index contents, mapping, Elasticsearch version and query vectors. Any one off makes
   orders differ in ways that are hard to read. Parity runs both sides on the same Elasticsearch version and the same embedding image.
5. **The lecture data step (decision 4a, option 3)** is manual. A server without the file leaves the lecture index empty (the feed
   creates it; section 3.5), and lecture search then answers 200 with no results, not an error. `docs/deployment.md` must say so, and the
   feed logs it as a warning at every tick.
7. **The rate limit meets our own checks.** Every Hurl and timing request comes from one machine through the gateway, so it shares
   one key. The 429 Hurl case goes in its own file (`v1-search-rate-limit.hurl`), run last, because it uses up the bucket for 60 s.
   TC-SRCH-Q2-01 is paced at one request a second, or sends a distinct `X-Forwarded-For` per request. That works only if the gateway
   appends its private hop, which `ClientAddress` skips as trusted (`default.conf:18`); verify it first. Local tsr-web limits parity
   requests at 60 a minute too, so the parity tool paces itself.
6. **Model drift.** An unpinned `fastembed` or model revision could change the query vectors without any error. Pin both, and keep the
   fixture vectors committed so a test catches a change.
