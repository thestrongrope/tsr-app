# Website port: recon of tsr-web (13 Nov 2026)

Read-only recon of `~/Projects/tsr-web` as input for the spec. Nothing here is decided. Paths without a
repo name are in tsr-web. Dart paths are under `~/Projects/tsr-account/mobile/lib`. The route list is
`operations.csv` beside this file.

Read at: tsr-web branch `feat/app-links-well-known` (commit `109927c`). `origin/main` (`7cfe359`, 7 Nov
2026) is ahead by two small changes only: the Apple app-link file also lists `/join/*`, and the Google
Analytics id in `layout.tsx`. tsr-account at `15d5df64`.

## 1. Surfaces

| Kind | Count | Called or opened by the app |
|---|---|---|
| page | 12 | 4 (opened in a browser or shared as a link) |
| api | 19 (10 under `/api/v1/`) | 8 of the 10 `/api/v1/` routes |
| other | 28 rows | 8 |

Points the csv cannot say in one cell:

- **No sitemap, no robots.txt, no RSS feed, no structured data.** Not found in `web/src/app` or `web/public`.
  `/feed` redirects to `/articles` (`web/next.config.ts`).
- **Redirect status codes.** `permanent: true` and `permanentRedirect()` in Next.js answer 308, `permanent: false`
  answers 307, and only two rules answer 301 (the one renamed article, and the comma repair in `web/src/middleware.ts`).
- **Two redirects need the content list.** `/{slug}` redirects to `/articles/{slug}` when no page has that slug but an
  article does (`web/src/app/[slug]/page.tsx:56-62`). A static site cannot do that without one rule per article (501 today).
- **Path collision.** tsr-web serves an HTML page at `/articles`. tsr-app's gateway serves JSON at `/articles`
  (`hosts/gateway/default.conf:34`). They can only share a host if one moves.
- **Trailing slash.** Today's URLs have none (`/articles/{slug}`). The site spike writes `/articles/{slug}/index.html`.
- **Two unauthenticated holes.** `GET /api/articles?includeUnpublished=true` lists drafts (`web/src/app/api/articles/route.ts`).
  `GET /api/v1/articles/{slug}` and `GET /api/articles/{slug}` do not check status (`article-service.ts:102-131`).
  Production is safe only because the 548 drafts are gitignored and so never reach the image.
- **`/api/v1/taxonomies/categories/{slug}/articles`** has a Dart method and no caller.
- **`/wp-json`** is not served by tsr-web. See section 2.

## 2. API contracts the app depends on

Client: `features/wordpress/services/tsr_web_service.dart`. Base URL is the constant `https://thestrongrope.com`
(line 14), not a build setting. It uses its own Dio with no auth header, 15 second timeouts, `Accept: application/json`.
Dio throws on any non-2xx, so the `success: false` branch only runs on a 2xx body.

**Envelope** (`web/src/app/api/lib/api-response.ts`, `types/api.ts`):

```
200: { success: true, data: <T>, meta: { timestamp, version: "1.0", cache: { expires, maxAge } }, pagination?: { total, limit, offset, hasMore } }
err: { success: false, error: { code, message, details? }, meta }
```

Error codes and status: `NOT_FOUND` 404, `VALIDATION_ERROR` 400, `BAD_REQUEST` 400, `RATE_LIMITED` 429,
`SERVICE_UNAVAILABLE` 503, `INTERNAL_ERROR` 500 (message "An unexpected error occurred"). The two search routes
answer 429 with a different body, `{ success: false, error: "Too many requests" }` (a string), plus `Retry-After`,
`X-RateLimit-Limit`, `X-RateLimit-Remaining`. This is not tsr-app's `{"detail": "..."}` (root rule 7).

**Caching** (`cache-utils.ts`): `Cache-Control: public, max-age=N[, stale-while-revalidate=M]`, `ETag` (MD5 of the JSON),
`Vary: Accept-Encoding`, and `Last-Modified` on the article routes. `If-None-Match` or `If-Modified-Since` gives 304 on
articles, article detail, categories, category articles, tags and publications; not on search, lectures or youtube.
The app sends no conditional headers (not found in `tsr_web_service.dart`). CORS: `Access-Control-Allow-Origin: *`.

| Route | Query | max-age / swr (s) | `data` |
|---|---|---|---|
| `GET /api/v1/articles` | `limit` 1-100 (20), `offset` (0), `sort` one of `publishedDate:asc|desc`, `title:asc|desc` (else 400), `q` (substring of title, excerpt, tags), `category` (one slug, exact), `tag` (one tag NAME, exact), `locale` | 300 / 600 | array of article list items; `pagination` set |
| `GET /api/v1/articles/{slug}` | none | 3600 / 86400 | article detail; 404 `NOT_FOUND` |
| `GET /api/v1/search` | `q` required (else 400), `limit` 1-100 (20), `offset`, `category`, `fields` (ignored) | 60 | `{ results[], query, searchEngine, took }` |
| `GET /api/v1/lectures/search` | `q` optional (empty browses newest first), `limit`, `offset`, `language` | 60 | `{ results[], query, searchEngine, total, took }` |
| `GET /api/v1/taxonomies/categories` | `hierarchical` (true), `includeArticleCounts` (true) | 3600 / 86400 | array of categories |
| `GET /api/v1/taxonomies/tags` | none | 3600 / 86400 | array of `{ name, slug, articleCount }`, most used first |
| `GET /api/v1/youtube` | `limit` 1-50 (10), `offset` | 3600 / 7200 | `{ videos[], meta }` |
| `GET /api/v1/publications` | `language` (not sent by the app) | 3600 / 86400 | array of publications |

**Fields, and which the Dart models read** (`features/wordpress/models/tsr_article.dart`, `tsr_lecture.dart`, `publication.dart`):

| Shape | Server sends | Dart reads |
|---|---|---|
| Article list item | `id` int (0 when missing), `slug`, `title`, `excerpt?`, `publishedDate` string, `modifiedDate?`, `featuredImage?`, `author` (default `admin`), `categories` string[], `tags` string[], `language` (default `en`), `readingTime` int minutes | `id`, `slug` (required), `title` (required, HTML entities decoded), `excerpt`, `publishedDate`, `modifiedDate`, `categories`, `tags`, `author`, `language`, `readingTime`. Also `featured`, which the server never sends. Ignores `featuredImage`. |
| Article detail | list item plus `content` (HTML from remark), `rawContent` (Markdown), `videoUrl?`, `relatedArticles` (5 list items) | adds `content` only. The app renders HTML. |
| Article search result | list item plus `score`, `highlights? { title[], excerpt[], content[] }` with `<em>` marks. From Elasticsearch `id` is always 0 and `readingTime` always 1 (`search-service.ts:423-435`). | list item fields. `TsrSearchResult` needs `results` and `query`, and reads `data.total`, which this route does not send, so it is 0. |
| Lecture result | `slug` (YouTube video id), `title`, `url`, `excerpt?`, `tags[]`, `language`, `publishedDate?`, `durationSec?`, `chapters[] { start_sec, title, summary?, url }`, `matchedChapters[]` (same plus `highlight`), `key_points[]`, `thumbnail`, `score`, `highlights?` | `slug`, `title`, `url`, `thumbnail`, `chapters` and `matchedChapters` (`title`, `start_sec`, `url`); `data.total`. Throws if `data.results` is not a list. |
| Category | `slug`, `title`, `description?`, `order`, `parent?`, `articleCount`, `subcategories?[]` | `slug`, `title`, `description`, `articleCount`, `subcategories` |
| YouTube video | `id`, `videoId`, `title`, `youtubeLink`, `publishedDate`, `publishedDateFormatted`, `views` (int or null), `intro` (200 chars), `description`, `thumbnail { url, width, height }` | all of them. `meta`: `total`, `channelId`, `channelName`, `channelUrl`, `lastUpdated`, `cacheHit`. |
| Publication | `title`, `summary?`, `type?`, `size?`, `updated?` (display string), `language?`, `file?`, `readOnlineUrl?`, `downloadOnly` bool | all but `downloadOnly`. `file` and `readOnlineUrl` are site-relative; the app resolves them against the base URL. |

Pagination quirks the app lives with today:

- Article search: `pagination.total` is the number of results on this page, `hasMore` is `results == limit` (`search/route.ts:113-118`).
- YouTube: `meta.total` and `pagination.total` are the size of the slice fetched (`limit + offset`), not the channel total
  (`youtube/route.ts:126-158`). The app pages by "got a full page".
- Multi-select: `all_articles_screen.dart:57-70` joins selected categories and tags with commas; the server matches one exact
  value, so two selections return an empty list. A port that keeps the contract keeps this bug unless it is decided otherwise.

**`wordpress_service.dart` (`wp-json`).** It calls `https://thestrongrope.com/wp-json/wp/v2/posts`, `/posts/{id}` and
`/categories`. tsr-web has no route, rewrite or redirect for `/wp-json` (`web/next.config.ts`, `web/src/app`), so it gets a
404. In the app it is wired to `ArticleDetailScreen`, reachable only when the slug in `/home/articles/detail/{slug}` is
all digits (`core/router/app_router.dart:783-787`); `ArticlesListScreen` has no route. It is dead code. Nothing to port.

**Other things the app takes from the site:** four images under `/uploads/` by fixed URL
(`about/screens/accreditation_screen.dart`), `/donate` and `/` opened in a browser, the share link
`https://thestrongrope.com/articles/{slug}`, the PDFs and reading pages named by publications, and the two app-link files.

## 3. Content model

All under `web/content/`, read from disk at request time by `web/src/lib/markdown.ts` (gray-matter + remark). No database.

| Folder | Files | In git | Format | Read by |
|---|---|---|---|---|
| `articles/` | 1,049 | 501 | Markdown + YAML frontmatter | pages, API, both search builders |
| `categories/` | 53 | 53 | frontmatter only | pages, API |
| `pages/` | 35 | 35 | Markdown + frontmatter | `/[slug]`, `/pages`, `/tsr-publications`, publications API |
| `authors/` | 1 | 1 | frontmatter only | no reader found in `web/src` |
| `lectures/` | 1 (`lectures.ndjson`, 22.7 MB, 917 lines) | 1 | one JSON document per line | lecture reindex only |
| `youtube-videos/` | 250 | 0 (gitignored) | Markdown + frontmatter | no reader found in `web/src` |
| `settings/` | 0 | 0 | empty | `getSettings` returns `{}` always |

**Articles.** 501 published (499 `status: publish`, 2 `published`) and 548 `draft`. The drafts are the `2026-01-28-*` files,
gitignored (`.gitignore`), machine-written from lecture transcripts (they carry `sourceVideo`), "pending review" per `CLAUDE.md`.

| Field | Present in | Notes |
|---|---|---|
| `title`, `slug`, `publishedDate`, `modifiedDate`, `excerpt`, `author`, `status`, `language` | all 1,049 | `author` is always `admin`. `language` is always `en`, even on Urdu-script articles, so the `locale` filter does nothing. |
| `tags` | 1,045 | free text names; 575 distinct across published. A tag's slug is computed (`article-service.ts:184`). |
| `categories` | 1,029 | list of category slugs; every reference in a published article exists in `categories/`. |
| `id` | 495 | integers 1 to 495, unique. 6 published articles have none; the API then sends 0. |
| `sourceVideo` | 548 | drafts only |
| `canonicalUrl` | 2 | sets `rel=canonical` to the original publisher |
| `featuredImage`, `videoUrl`, `metaDescription` | 0 | in the CMS form and the code, never used in a file |

- **Slug** is the frontmatter `slug`, not the filename. Files are named `YYYY-MM-DD-<slug>.md`; the date prefix is the import
  or creation date (486 files are `2025-10-20-*`, the WordPress import), not the publish date. No duplicate slugs.
  Longest published slug is 199 characters; 13 are over 120 (tsr-app's `content.articles.slug` limit); 4 are percent-encoded
  Urdu and fail tsr-app's `SafeSlug` pattern (`domains/content/site/ContentSite.cs:10`).
- **Dates** are ISO strings in three shapes: with `Z` and milliseconds (496), with microseconds and no zone (550), plain seconds (3).
- **Drafts and scheduling.** Only `status` decides. There is no scheduling: a future `publishedDate` is not checked
  (`markdown.ts:136-139`). tsr-app's stub uses `published_at` null, past or future instead.
- **Body.** Markdown, 1.34 million characters across published articles (longest 16,808). One published body has raw HTML.
  The site renders with react-markdown, remark-gfm and rehype-raw (`components/MarkdownRenderer.tsx`); the API renders HTML
  with remark-html. Right-to-left text is detected by script, not by `language`. No published article embeds an image.
- **Related articles** are scored at request time: 2 per shared category, 1 per shared tag (`markdown.ts:442-478`).

**Categories.** 7 parents and 46 children. Fields: `title`, `slug`, `order` (all), `parent` (46), `description` (7). The CMS
form has `color`; no file uses it. Slugs are frozen because they are in live URLs (`CLAUDE.md`).

**Pages.** Fields: `title`, `slug`, `metaTitle`, `metaDescription`, `language` (all 35); `status` (25); `parent` (16);
`prevPage`, `nextPage` (14); `order`, `pageType` `book|about|resource` (9); `publications` (1). `/[slug]` renders a page
whatever its status. Book chapters are pages linked by `parent`, `prevPage`, `nextPage`.

**Files.** `web/public/downloads/` 196 MB (36 PDFs: `books/` 163 MB, `tsr-publications/` 34 MB), in plain git, no LFS.
`web/public/uploads/` 2.8 MB (14 images). `web/public/duas/` 2 HTML files. `web/public/images/` 140 KB. `web/content/` 31 MB.
`web/public/search-index.json` 1.8 MB (generated, committed).

## 4. Search

Three Elasticsearch indexes on one single-node 9.2.3 cluster with security off (`docker-compose.yml`). All three are
derived data: losing the volume costs a reindex, and the analytics history.

| Index (setting that renames it) | Holds | Built by |
|---|---|---|
| `tsr-articles` (`ELASTICSEARCH_INDEX`) | published articles | `POST /api/admin/reindex`; also `web/scripts/index-to-elasticsearch.ts` in `npm run build` |
| `tsr-lectures` (`ELASTICSEARCH_LECTURES_INDEX`) | 917 lectures, 898 with a vector | `POST /api/admin/reindex-lectures` from `lectures.ndjson` |
| `tsr-analytics` (`ANALYTICS_INDEX`) | search and click events | created on first write (`analytics-service.ts`) |

**Analyzer** (both content indexes): `multilingual_analyzer` = standard tokenizer, `html_strip`, `lowercase`, `asciifolding`.
No stemmer, no Arabic or Urdu analyzer, no synonym filter. Synonyms and transliteration are done in application code.

**`tsr-articles` mapping** (`reindex-service.ts:13-54`): `slug` keyword (also the id); `title` text + keyword; `excerpt`,
`content` text; `categories`, `tags`, `author`, `language`, `status` keyword; `publishedDate`, `modifiedDate`, `indexed_at` date.
No vectors. Semantic search for articles is disabled (`search-service.ts:284`).

**`tsr-lectures` mapping** (`lectures-index.ts`): `slug` keyword (YouTube id); `title`, `excerpt`, `content` (transcript),
`search_phrases`, `key_points` text; `tags`, `language`, `url` keyword; `publishedDate` date; `durationSec` integer;
`chapters` nested (`start_sec`, `title`, `summary`, `url`); `embedding` dense_vector, 384 dims, cosine, `flat`.

**When the indexes are built.** The build runs the article indexer but tolerates failure, and Elasticsearch is not reachable
during the image build (`DEPLOYMENT.md` section 5), so in production both indexes are filled by calling the reindex routes
by hand after a deploy. Nothing does it automatically. Both routes upsert by slug, delete what is gone, and refuse an empty source.

**Likely defect, from reading the code.** The runtime article reindex takes its documents from `getPublishedPosts`, which
returns frontmatter only (`markdown.ts:104-134`), so `content` is indexed as an empty string (`reindex-service.ts:113`). The
build-time script reads the body. If production was filled by the route, article body text is not searchable there.

**Article query** (`search-service.ts:286-446`): filter `status = publish` (so the 2 `published` articles are filtered out)
and optional one category. A `should` list: phrase on title (boost 15) and on content (5); every extracted term must match
title or excerpt with its synonyms (30); cross-field match over title, excerpt, content, tags; a fuzzy match of the query
expanded with a transliteration-normalised copy and synonyms. Synonyms and name expansions are a hard-coded table
(Imam Ali / Ameerul Momineen, Husain / Hussain, and so on). Highlights use `<em>`.

**Lecture query** (`lectures-search-service.ts`): the same idea plus `search_phrases` and `key_points`, a nested chapter match
(boost 8) that returns up to 3 matched chapters, and a strict pass first with a fuzzy second pass only when fewer than 3 hits.
The helpers are copied, not shared. Optional semantic layer: when `LECTURES_SEMANTIC_WEIGHT > 0` the query is embedded, a kNN
search (k 50) runs, and the two rankings are fused in code by reciprocal rank (k 60). Default weight is 0 (off); 0.25 is the
evaluated value. Whether production has it on is a Dokploy setting, not in the repo.

**Embeddings service** (`embeddings/app.py`, `Dockerfile`): FastAPI + fastembed, model `BAAI/bge-small-en-v1.5` (ONNX, 384
dims), baked into the image at build. Routes `/health`, `/embed`, `/tokens`. Internal only. Callers: the web service for one
query at a time (1.5 s timeout), and `web/scripts/embed-lectures-data.ts` on a laptop to make document vectors, which are
then committed inside `lectures.ndjson`. About 258 MB resident when serving. Some comments still say MiniLM.

**When Elasticsearch is down.** Article search falls back to Fuse.js over all published articles in memory and answers
`searchEngine: "fuse"`. Lecture search has no fallback: 500 `INTERNAL_ERROR`, and `/lectures` is empty. Analytics becomes a
no-op. The `/articles` page still browses and filters from `search-index.json` in the browser.

**Rate limits** are in memory, per process, keyed on the first `x-forwarded-for` entry (`rate-limit.ts`): search 60, lectures 60,
events 120, admin analytics 30 a minute.

## 5. Lectures and YouTube

Two unrelated sources.

1. **Lecture corpus** (`/lectures`, `/api/v1/lectures/search`). `lecture-pipeline/` is a Python pipeline run **by hand on a
   laptop** (`update_lectures.py`): refresh the channel inventory and privacy status with the YouTube Data API as the channel
   owner (OAuth), download captions, parse to chunks, translate Hindi to English and enrich each video with Gemini (summary,
   chapters, key points, tags, search phrases), merge into `lecture-pipeline/data/videos.ndjson`, then
   `web/scripts/build-lectures-data.ts` and `embed-lectures-data.ts` write `web/content/lectures/lectures.ndjson` with vectors.
   It does not commit, deploy or reindex. Only public videos are published; two hard-coded id lists are a backstop.
   `npm run check:lectures` checks that videos are still public. Languages in the corpus: hi 846, en 41, ur 27, ar 3.
   The folder is 5 GB locally (audio and caches, gitignored). `DEPLOYMENT.md` still says 589 lectures and 13 MB.
2. **Latest videos** (home page, `/api/v1/youtube`). Read live from the channel's public RSS feed (`markdown.ts:349-426`),
   cached in memory for 30 minutes, with a last-good copy when YouTube refuses the server. No API key.

Nothing runs on a schedule. No cron, no CI workflow (`.github` not found).

## 6. Publications and events

- **Publications**: the `publications` list in the frontmatter of `web/content/pages/tsr-publications.md` (38 entries; 9 with
  `readOnlineUrl`, 1 `downloadOnly`). Files are the PDFs under `/downloads/`. Page and API parse it the same way.
- **Events**: `/api/v1/events` is not a calendar. It is the search click beacon (section 7). tsr-web has no events content.

## 7. Admin, auth and analytics routes

- **`/api/admin/reindex`, `/api/admin/reindex-lectures`, `/api/admin/analytics`**: guarded by one shared secret
  (`REINDEX_SECRET`) sent as `Authorization: Bearer` or `x-reindex-secret`, compared in constant time; 503 when the setting is
  missing, 401 on mismatch. Used with curl by the owner. No admin UI.
- **`/api/auth`, `/api/callback`**: GitHub OAuth for **Decap CMS** at `/admin` (`web/public/admin/index.html`, script from
  unpkg). Scope `repo,user`; the callback hands the GitHub token to the CMS window. Needs `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET`.
- **Analytics stored**: Google Analytics 4 loads on every page with no consent banner (`layout.tsx`, `CLAUDE.md`). First-party:
  `tsr-analytics` holds search events (`ts`, `type`, `surface`, `query`, `query_norm`, `result_count`, `zero_results`, `engine`,
  `took_ms`, `language?`, `category?`) and click events (`query`, `slug`, `rank`). No IP, cookie or user agent. Searches from the
  app are logged too, since they hit the same routes. The privacy policy describes this, so a change is a policy edit.

## 8. Editorial workflow

- **In practice: git.** An article is a Markdown file added under `web/content/articles/` on a branch, merged by pull request
  (`develop` and feature branches into `main`), then deployed. Recent history shows hand or agent written commits.
- **House style and checklist**: `EDITORIAL_STANDARDS.md` and `CLAUDE.md` (naming register, honorifics, `id` one past the highest).
- **Helpers**: `scripts/docx_to_article.py` turns a Word file from `reference/` into an article with Gemini.
  `scripts/generate_articles.py` and its siblings made the 548 drafts. `sync-wp-articles.js` and `update-articles.js` are
  one-off WordPress import tools from December 2025 that read a JSON dump from `/tmp`; they are not part of a workflow.
- **Decap CMS** is configured (collections for articles, pages, categories, authors, videos, settings; `editorial_workflow`
  against `thestrongrope/tsr-web` `main`), but no commit in the history carries a Decap commit message. It looks unused.
- **After merge**: deploy, then call the reindex routes by hand. An article shows on the site without a reindex (files are read
  from disk) but is not in Elasticsearch search until one runs.

## 9. Deployment and operations

- **Dokploy, Docker Swarm stack, Traefik in front** (`docker-compose.yml`). Services: `web` (Next.js standalone, node:20-alpine,
  512 MB limit), `embeddings` (python:3.12-slim, 1 GB limit), `elasticsearch` (9.2.3, 512 MB heap, 2 GB limit). No published ports.
- **Volume**: `elasticsearch_data` only. Content and PDFs are inside the web image.
- **Build steps** (`web/package.json` `build`): build `search-index.json`, try to index articles (failure tolerated), generate
  `swagger.json`, `next build`. The embeddings image downloads its model during the build.
- **After a deploy, by hand**: both reindex routes. **Before a lecture refresh**: `npm run check:lectures`.
- **Deploy trigger**: the two documents disagree. `CLAUDE.md` says a merge to `main` deploys; `DEPLOYMENT.md` section 4 says
  deploys are manual. Not resolved here.
- **Settings (names only).** Web: `ELASTICSEARCH_URL`, `ELASTICSEARCH_INDEX`, `ELASTICSEARCH_LECTURES_INDEX`, `ANALYTICS_INDEX`,
  `EMBEDDINGS_URL`, `EMBED_TIMEOUT_MS`, `LECTURES_SEMANTIC_WEIGHT`, `LECTURES_BM25_WEIGHT`, `LECTURES_SEARCH_RATE_LIMIT`,
  `SEARCH_RATE_LIMIT`, `EVENTS_RATE_LIMIT`, `ADMIN_ANALYTICS_RATE_LIMIT`, `REINDEX_SECRET`, `GITHUB_CLIENT_ID`,
  `GITHUB_CLIENT_SECRET`, `NEXT_PUBLIC_GA_ID` (build time), `NODE_ENV`, `WEB_PORT`, `WEB_IMAGE`, `EMBEDDINGS_IMAGE`.
  Embeddings: `EMBEDDING_MODEL`, `FASTEMBED_CACHE_PATH`, `MAX_TEXTS_PER_REQUEST`. Pipeline (laptop): `GEMINI_API_KEY`, plus the
  OAuth files under `lecture-pipeline/.secrets/`. `.env.example` is stale (Payload and Postgres names from the archived stack).

## 10. SEO and links that must not break

- **Live URL patterns**: `/`, `/articles`, `/articles?category=<slug>`, `/articles?tag=<slug>`, `/articles?q=`,
  `/articles/<slug>` (501), `/<page-slug>` (35, including `/privacy-policy`, `/accreditation` and the book chapters),
  `/about`, `/donate`, `/lectures`, `/lectures?q=`, `/pages`, `/tsr-publications`, `/self-reflection/<en|ur|gu>`,
  `/downloads/**/*.pdf`, `/uploads/*`, `/duas/*.html`.
- **Redirects to keep**: every `other` row from `web/next.config.ts` and `web/src/middleware.ts` in the csv, plus the two from `/[slug]`.
- **Metadata today**: site default title and description (`layout.tsx`). Articles: `<title> | The Strong Rope`, description from
  the excerpt, Open Graph `title`, `description`, `type=article` (image only from `featuredImage`, which no article has),
  canonical only for the 2 articles with `canonicalUrl`. Pages: `metaTitle`, `metaDescription`. No Twitter card, no JSON-LD.
- **App links**: `/.well-known/assetlinks.json` (Android, package `com.thestrongrope`) and `/.well-known/apple-app-site-association`
  (iOS; `/mcq/*`, and `/join/*` on `origin/main`). Android claims `/join/`, `/mcq/`, `/articles/` on `thestrongrope.com` and
  `www` (`android/app/src/main/AndroidManifest.xml:93-123`); iOS entitlements list both hosts. `/join/*` and `/mcq/*` redirect to
  `account.thestrongrope.com` for visitors without the app. Whoever serves the domain must serve both files, unredirected, on both hosts.
- **Privacy policy**: `/privacy-policy` is what the store listings point at and must match `tsr-app/docs/privacy-policy.md`.

## 11. Open decisions for the owner

1. **Where the article source of truth lives.** (a) Markdown files in git, as now, loaded into `content.articles` by an import
   step; (b) rows in `content.articles` edited through an admin screen. Today: files, 31 MB, with an editorial flow built on
   pull requests. Recommendation: keep files as the source and make the database a derived copy.
2. **Static generation or server rendering.** Article, page and index pages fit `hosts/site`. `/articles?q=`, `/lectures` and the
   root-slug redirect need a live answer. Recommendation: static pages, with search as small browser calls to the API.
3. **Who answers `/api/v1/*`.** (a) the domain keeps serving the same paths through the gateway to new slices; (b) the app
   moves to the member API host and new paths. The base URL is a constant in store-live builds. Recommendation: (a), keep paths and envelope.
4. **Envelope and errors.** Keep `{success, data, meta, pagination}` on these routes, or move to tsr-app's `{"detail"}`. Store
   builds parse the old one. Recommendation: keep it on `/api/v1/*` as a named exception.
5. **Keep known bugs or fix them** (comma-joined filters, search `total`, YouTube `total`, `id` 0 from Elasticsearch).
   Recommendation: decide each one; fixes that only add or correct fields are safe for old builds.
6. **Public search index.** `repo-structure.md` 2.5 wants a physically separate public index. Options: separate index names on
   the same cluster, or a second cluster. Recommendation: separate indexes on the one cluster the stack already runs.
7. **Semantic lecture search.** Keep the Python embeddings container, replace it with an in-process .NET ONNX model, or drop
   the semantic layer (default is off). Recommendation: port BM25 first and find out whether production has it on.
8. **Lecture pipeline.** Leave it in tsr-web as a laptop tool that produces `lectures.ndjson`, or move it. Recommendation:
   leave it; the port consumes the file.
9. **Reindexing.** Hand-called admin routes, or a worker like `search-feed`. Recommendation: a worker; drop the routes.
10. **Editorial workflow and Decap CMS.** Drop Decap and its two OAuth routes, or keep an editor UI. Recommendation: confirm it
    is unused, then drop it.
11. **The 196 MB of PDFs.** In the monorepo, in object storage behind the same URLs, or left on the old host. Recommendation:
    not in the monorepo's git; keep the URLs.
12. **Search analytics.** Keep in Elasticsearch, move to PostgreSQL, or drop. Recommendation: keep the events, store them in PostgreSQL.
13. **Slugs.** 4 percent-encoded and 13 long slugs break tsr-app's current slug rule and column size. Widen the rule, or give
    them new slugs with redirects. Recommendation: widen; the URLs are live.
14. **The 548 drafts and the `status` model** versus tsr-app's `published_at`. Recommendation: import published only; map
    `publish` and `published` to a publish time.
15. **Small pages**: `/self-reflection`, `/donate`, `/docs`, `/pages`. Port, redirect or drop each. Recommendation: owner picks.
16. **Add what is missing** (sitemap, robots.txt, JSON-LD, iOS article links) in the port or later. Recommendation: sitemap and robots in the port.
17. **Google Analytics with no consent gate.** Carry over as is or change. Tied to the privacy policy.

## 12. Size estimate

Rough, 22 stories. Groups A to E are largely independent of each other once A1 exists.

| # | Story | Depends on |
|---|---|---|
| A1 | Content schema: articles (all fields), categories, tags, pages, publications | decisions 1, 13, 14 |
| A2 | Importer from Markdown files into `content`, repeatable, with a parity check of counts and slugs | A1 |
| A3 | Markdown to HTML rendering that matches today's output (GFM, raw HTML, right-to-left) | none |
| B1 | `GET /api/v1/articles` (filters, sort, envelope, cache headers, 304) | A2 |
| B2 | `GET /api/v1/articles/{slug}` with related articles | A2, A3 |
| B3 | Categories and category articles | A2 |
| B4 | Tags | A2 |
| B5 | Publications | A2 |
| B6 | YouTube latest videos (RSS reader with cache) | none |
| C1 | Public article index and feed worker | A2, decision 6 |
| C2 | `GET /api/v1/search` (query composition, synonyms, highlights, fallback decision) | C1 |
| C3 | Lecture index and feed from `lectures.ndjson` | decision 8 |
| C4 | `GET /api/v1/lectures/search` BM25 with chapter hits | C3 |
| C5 | Semantic layer (embeddings service or replacement, rank fusion) | C4, decision 7 |
| C6 | Search events: beacon route, storage, report | decision 12 |
| D1 | Site: layout, navigation, theme, fonts, home page | A2, B6 |
| D2 | Site: article list with category and tag filters, article page with metadata | A2, A3 |
| D3 | Site: content pages, book chapters, publications page | A2, A3 |
| D4 | Site: search and lectures pages (browser calls to the API) | C2, C4 |
| D5 | Site: about, donate, self-reflection | decision 15 |
| E1 | Gateway: redirects, comma repair, CORS, app-link files, `/join` and `/mcq`, static files and PDFs | decisions 3, 11 |
| E2 | Compose and Dokploy wiring, cutover plan, parity run against the live contract | all |

Contract tests can be written first against a local tsr-web, as the PHP parity runs were. Could not determine: how much of the
visual design must match exactly, production traffic and cache behaviour, and whether production runs the semantic layer.

## 13. Not verified

- Nothing was run and no live request was made. Every status code and behaviour above is from reading code.
- The Next.js redirect codes (307, 308) and that remark-html sanitises by default are from knowledge of the libraries, not from a test.
- The article reindex defect (empty `content`) was not confirmed against a running index.
- Dart JSON key names are taken from the model source (`tsr_article.dart`, `publication.dart`); the generated `.g.dart` files were not read.
- "No caller" claims come from grep over `mobile/lib` and `web/src` only. Older store builds were not checked.
- That Decap CMS is unused is inferred from commit messages. That the 548 drafts came from `scripts/generate_articles.py` is inferred from names and the `sourceVideo` field.
- Dokploy settings (deploy trigger, `LECTURES_SEMANTIC_WEIGHT`, replicas) are not in the repo.
- `self-reflection/[lang]/page.tsx`, `about/page.tsx`, `donate/page.tsx`, `PublicationsTabs.tsx`, `generate-swagger.ts`, `check-lecture-availability.ts` and the pipeline scripts other than the README were not read in full.
- How many entries the YouTube RSS feed returns (which caps `/api/v1/youtube`) was not measured.
- Whether `www.thestrongrope.com` is served by the same stack is not in the repo.
- `archive/` (988 MB, the old Payload and Postgres stack) was not read.
