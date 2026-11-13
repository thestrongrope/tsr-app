# Feature 1 plan: the app's Library reads (draft, 13 Nov 2026)

**Status: draft for Asif's approval. No code is written.** This becomes the description of the draft pull request.
Spec: Part 2 of `spec-draft.md` (requirements `LIB-R1` to `LIB-R26`, `LIB-Q1` to `LIB-Q3`). Facts about today's website:
`recon.md` section 2 (the contract) and section 3 (the content files). The reference implementation is `~/Projects/tsr-web`
at commit `109927c`; where this plan says "as tsr-web", port the named file's rule and keep its quirks.

## Approach
`content` keeps a copy of the published content in NEW tables of its own (the stub table `content.articles` and its route `GET /articles` are not touched: that table is seeded with draft rows for the stub's own tests), made from the content files by a worker, and six
public slices under `/api/v1/` answer from that copy in today's answer shape. The files stay the source (agreed answer 1),
so nothing in the API writes content. The copy is replaced in one database transaction, so a reader sees the last complete
set or the new one, never a mix. Only published articles are read from the files, so a draft is never in the database.
The latest videos have no table: they are read from the channel's public feed and kept in memory.

## Needs Asif's yes before code
1. **Two new packages** in `Directory.Packages.props`: `Markdig` (Markdown to HTML) and `YamlDotNet` (frontmatter).
   `docs/specs/dotnet-stack.md` names no library for either.
2. **A reference copy of the content files** for local work: the plan reads them from a directory named by a setting, and
   locally that directory is `~/Projects/tsr-web/web/content` (read-only). Where the files live after cutover is the
   epic's question, not this feature's.
3. **Running tsr-web locally** (its own compose project, synthetic nothing: it serves its real, public content) for the
   parity run of TC-LIB-Q1-01. Without it, parity is not proven and the plan says so.
4. **A second answer shape in the API.** `/api/v1/*` answers `{success, data, meta, pagination}` and errors
   `{success: false, error: {code, message}}`, not `{"detail"}` (agreed answer 2). Root rule 7 gains this named exception
   in the same pull request.

## Changes

### `domains/content/api`
| File | What |
|---|---|
| `ContentContext.cs` | Entities and mapping for the columns and tables under "Data and migrations". |
| `domain/ContentFiles.cs` (new) | Reads one content directory into memory: articles, categories, publications. Frontmatter is read from YamlDotNet's EVENT stream (`Parser`) into a small structure of our own (text, list, map with text keys); the library's document tree (`YamlStream`) is not used, because it overflows the stack or never ends on aliases. An alias, an anchor, a tag, a key that is not plain text, or a second document is a failure. No reflection over our types, as `dotnet-stack.md` asks (AOT-ready). Also failures: a slug over 255 characters, a tag or category over 200 characters or more than 50 of either on one article, a NUL in any stored text after decoding, and a publication link that is neither site-relative (one leading `/`) nor `http` or `https`. If the AOT or trim analyzers warn on either new package, stop and report. Keeps an article only when `status` is `publish` or `published`. Fields and their optional ones: `recon.md` section 3. A date is parsed in any of the three shapes found there; one without a zone is UTC. (tsr-web reads such a date in the server's local time, and its container runs in UTC.) A category's slug is its FILE NAME without the extension, as tsr-web takes it, not the frontmatter `slug`. Bounds, each a failure and never a truncation: at most 20,000 files, 5 MB a file, 200 MB in all, 64 KB of frontmatter, YAML nesting 16 deep, an article body of 100,000 characters (the longest real one is 16,808), and 2 minutes for one whole read. A symbolic link is refused, not followed. The read takes a cancellation token. Any exception, expected or not, ends in `Kept(cause)` with the exception's type name at most. |
| `domain/ArticleHtml.cs` (new) | `ToHtml(markdown)` with Markdig as plain CommonMark: NO GitHub extensions and raw HTML NOT passed through, because tsr-web's API renders with `remark().use(html)` (`web/src/lib/markdown.ts:87-89`), which has no GFM and sanitises by default. A link or image whose address is not `http`, `https`, `mailto`, site-relative or a fragment gets an empty address. (The website's PAGES render differently, with GFM and raw HTML; that is F4's concern.) `ReadingMinutes(markdown)` = `max(1, ceil(words / 200))` (`article-service.ts:20-22`). |
| `domain/ContentRefresh.cs` (new) | `TickAsync(ContentContext db, string? directory, TimeProvider clock, ILogger log, CancellationToken ct)`: one refresh, rules below; it calls `ContentFiles.Read(directory)`, which returns the parsed `ContentSet` or a failure cause. Returns `Refreshed`, `Unchanged` or `Kept(cause)`. The worker passes the setting `TSR_CONTENT_DIR`. An internal overload takes `Func<CancellationToken, Task>? beforeCommit`, awaited inside the transaction just before the commit: the one seam, used only by TC-LIB-R23-01. |
| `workers/ContentRefreshWorker.cs` (new) | `PeriodicWorker`, name `content-refresh`, interval 5 minutes; calls `ContentRefresh.TickAsync`. Registered through `ContentModule.WorkerNames` and `AddContentWorkers`, added to the list in `hosts/api/WorkerMode.cs`. |
| `domain/V1.cs` (new) | The answer shape: `V1.Ok(data, maxAge, swr, pagination?, lastModified?)` and `V1.Error(status, code, message)` (the error body carries `meta` too, with `cache.maxAge` 0, and no cache headers). Sets `Cache-Control`, `ETag` (MD5 of the JSON of `data` and `pagination` only, never `meta`, whose timestamp changes on every answer; tsr-web hashes route-specific values instead), `Vary: Accept-Encoding`, the three `Access-Control-Allow-*` headers of tsr-web's `middleware.ts` on every answer (the 304 and errors too), and answers 304 for a matching `If-None-Match`, or, where the route has a `Last-Modified`, for an `If-Modified-Since` that is not older (tsr-web `api/lib/api-response.ts`, `cache-utils.ts`). `V1.Int(raw, fallback, min, max)` clamps as tsr-web `parseIntParam`. |
| `domain/LatestVideos.cs` (new) | Interface `IVideoFeed` (the one external boundary) with `YouTubeFeed` (typed `HttpClient`, one attempt with a 10 second timeout and no retry, no redirect followed, at most 2 MB and 32 levels of XML, channel id from setting `TSR_YOUTUBE_CHANNEL_ID`, the 50 newest entries of the public feed, parsed with `System.Xml.Linq`) and the singleton `LatestVideos` cache: 30 minutes fresh, the last good list kept for ever, an empty list when nothing was ever read (tsr-web `lib/markdown.ts:349-426`, `api/v1/youtube/route.ts`). |
| `features/v1-articles/V1Articles.cs` (new) | `GET /api/v1/articles` |
| `features/v1-article/V1Article.cs` (new) | `GET /api/v1/articles/{slug}` |
| `features/v1-categories/V1Categories.cs` (new) | `GET /api/v1/taxonomies/categories` |
| `features/v1-tags/V1Tags.cs` (new) | `GET /api/v1/taxonomies/tags` |
| `features/v1-publications/V1Publications.cs` (new) | `GET /api/v1/publications` |
| `features/v1-videos/V1Videos.cs` (new) | `GET /api/v1/youtube` |
| `ContentModule.cs` | Maps the six routes (no `RequireMember`: public reads, rule 4 of `domains/CLAUDE.md`), registers `LatestVideos`, `IVideoFeed`, the worker. `Dependencies` stays empty. |

The spec's fourteen stories map to these six routes and the worker: the list route carries stories 1 to 5.

**Refresh rules** (`ContentRefresh.TickAsync`), in this order:
1. Setting `TSR_CONTENT_DIR` unset or the directory missing: `Kept("no content directory")`.
2. Read the directory. Any file that cannot be parsed, a duplicate slug, or a bound exceeded: `Kept(<cause>)`.
3. Zero published articles, or fewer than half of `refresh_state.article_count` (a missing row counts as 0, which switches the half rule off): `Kept("too few articles")`.
4. Hash the parsed set: SHA-256 of its canonical JSON (EVERY stored field of every article, category and publication, articles ordered by slug), so a change to any field is a change. Equal to `refresh_state.content_hash`: `Unchanged`.
5. In ONE transaction make the three tables equal to the parsed set: delete every `published_articles` row and insert the parsed ones, the same for `categories` and `publications`, then write `refresh_state`. Commit. (About 500 rows; a full replace is simpler than a row-by-row compare and readers do not see it until the commit.)
6. Every `Kept` writes `refresh_state.last_failure_at` and `last_failure_cause` (its own small transaction; it inserts row 1 when there is none, with an empty hash and count 0) and logs one warning with the cause. A cause is a fixed phrase and a file NAME at most, never file content.

**Read rules.** Each route is a port of tsr-web's file of the same path under `web/src/app/api/v1/` and the helpers it calls. **That code is the rule; the lines below only point at what is easy to miss, and where they and the code disagree the code wins and the plan is corrected.** The parity run (TC-LIB-Q1-01) is the judge.
- Articles list: `limit` 1 to 100 (20), `offset` from 0 (0), `sort` one of `publishedDate:desc` (default), `publishedDate:asc`, `title:asc`, `title:desc`, anything else 400 `VALIDATION_ERROR`; `q` substring of title, excerpt or a tag, case-insensitive; `category` one slug, exact; `tag` one tag NAME, exact; `locale` one language code, exact (`article-service.ts:59-61`; every article is `en` today, so `locale=ur` returns none); unknown parameters ignored. In the list every item's `readingTime` is 1 (tsr-web computes it from a body the list does not load); only the article route computes it. `pagination` = `{total, limit, offset, hasMore}`. Title order is ICU's (`en-x-icu`, the collation behind tsr-web's `localeCompare`), equal titles newest first in both directions (tsr-web's sort is stable over its newest-first list); a difference the parity run shows is listed. Date order uses `published_at`, ties by slug. `Last-Modified` is the newest `modified_at` (else `published_at`) of ALL published articles. max-age 300, swr 600.
- Article: the route value (already percent-decoded by the framework) is matched against `slug_decoded`; 404 `NOT_FOUND` when no row. `Last-Modified` is `modified_at`, else `published_at`. `content` = stored HTML; `rawContent` (tsr-web sends the Markdown) is NOT sent (Asif, 13 Nov 2026: the app does not read it and it carries the file's raw HTML); `relatedArticles` = the 5 other published articles with the highest score (2 a shared category, 1 a shared tag), zero scores included, ties in newest-first order (`markdown.ts:442-478`: a stable sort over the newest-first list, so an article with nothing shared can appear; a kept quirk). The 404 message is `Article not found: <the slug as asked>`. max-age 3600, swr 86400.
- Categories: `hierarchical` (default true: 7 parents each with `subcategories`; false: flat), `includeArticleCounts` (default true). A category's count is the articles filed directly under its own slug; a parent's count does not include its children's (`markdown.ts:202-226`). Order by `order`, a missing one as 999, ties by slug. max-age 3600, swr 86400.
- Tags: `{name, slug, articleCount}`, most used first, ties in the order a tag is first met walking the articles newest first and each article's tags in file order (tsr-web's map order); `slug` = lower case, whitespace runs to `-`, then drop every character that is not a Latin letter (a to z), a digit, `_` or `-`: JavaScript's `\w` knows no other script, so a tag named in one has an empty slug (`article-service.ts:184`). A tag written twice on one article counts twice.
- Publications: an entry with neither `file` nor `readOnlineUrl` is dropped at refresh; `language` filter, case-insensitive; `pagination` as `publications/route.ts:91`; `file` and `readOnlineUrl` exactly as stored (site-relative). max-age 3600, swr 86400.
- Videos: `limit` 1 to 50 (10), `offset`; `data` = `{videos, meta}`. Port `getCachedVideos` (`youtube/route.ts:92-135`) and `getYouTubeVideos` (`markdown.ts:349-426`) as written, including where each keeps a last-good list and what `meta.cacheHit` says in each branch; the totals are the size of the slice fetched (a kept quirk). `meta.channelName` and `meta.channelUrl` are the constants of `youtube/route.ts`, copied. An empty channel id reads nothing and gives the empty list. max-age 3600, swr 7200. No 304.
- Field names and kinds of every answer: the "Server sends" column of the table in `recon.md` section 2. `id` is `legacy_id` or 0. `publishedDate` and `modifiedDate` are the stored `*_date_text` strings (tsr-web passes the file's string through, `article-service.ts:31`).

### `hosts/gateway/default.conf`
One block a route, as the file does for every slice: `location = /api/v1/articles`, `location ~ ^/api/v1/articles/[^/]+$`, `location = /api/v1/taxonomies/categories`, `location = /api/v1/taxonomies/tags`, `location = /api/v1/publications`, `location = /api/v1/youtube`. The search and events paths are not routed (F2, F3).

### `hosts/api`
`WorkerMode.cs`: the content module's worker names in the list. `tests/RouteCatalog.cs`: the six routes added to `NotInPhp`.

### Compose and tools
- `docker-compose.dev.yml`: `TSR_CONTENT_DIR` and `TSR_YOUTUBE_CHANNEL_ID` pass through to `api` and `workers`, both empty by default; a read-only bind mount of `${TSR_CONTENT_SRC:-./db/synthetic/content}` at `/var/tsr/content` on the `api` and the `workers` services.
- `docker-compose.test.yml`: the default test stack sets `TSR_CONTENT_DIR=/var/tsr/content`, adds `content-refresh` to `TSR_WORKERS`, and leaves `TSR_YOUTUBE_CHANNEL_ID` empty (an empty id means `IVideoFeed` reads nothing: no outside call from a test stack).
- `db/synthetic/content/` (new): a small invented set: 12 published articles (seven sharing one tag, two of those also sharing a category, one with a 199 character slug, one with a percent-encoded slug, one with raw HTML, one right-to-left, one dated in the future), 2 drafts, 3 parent and 4 child categories, a `tsr-publications.md` page with 3 publications. No text taken from the real site.
- `tools/website-parity.cs` (new, a C# file-based app: `dotnet run tools/website-parity.cs -- <tsr-web base URL> <new API base URL>`, also `--sweep` and `--timing`): for each line of `tools/website-parity.cases` (a path and query), fetch it from two base URLs and compare the JSON, ignoring `meta.timestamp`, `meta.cache.expires` and the `ETag` header, comparing `content` after collapsing whitespace, for the videos route comparing key names only, and skipping the differences listed in `tools/website-parity.allow`. Exit 1 on any other difference. Standard library only, as `tools/export-parity.sh`.
- `tools/contract-website.sh test [--prepare]` (new, as the other lane scripts): waits until `GET /api/v1/articles?limit=1` reports `pagination.total` 12 (the worker ticks at start; give up after 60 seconds with an error), then runs the six Hurl files.
- `tools/test-stack.sh`: a lane stack runs no workers today. With `TSR_LANE_WORKERS=content-refresh` set, `up` also starts the `workers` service on the lane with exactly that list and without Elasticsearch, and its override sets `TSR_CONTENT_DIR=/var/tsr/content` on `api` and `workers`. Used for the parity and timing runs over the real content.
- `docs/specs/website-port/operations.csv`: a `state` column (`today`, `built`, `dropped`); the six rows become `built`.

### Docs in the same pull request
`domains/content/capabilities/library-reads.md` (new, from the template, `LIB-` IDs), `domains/content/spec/api.yaml`,
`domains/content/CLAUDE.md`, the root `CLAUDE.md` (rule 7 exception, the worker, the two settings, the parity tool).

## Data and migrations
One additive migration in `domains/content/api/Migrations` (new tables only):

| Table | Change |
|---|---|
| `content.published_articles` (new) | `slug text` primary key (as written in the file); `slug_decoded text` unique (the slug after percent-decoding, what a request path is matched against); `legacy_id int null`; `title` 500; `excerpt text null`; `body_markdown text`; `body_html text`; `published_at timestamptz` and `published_date_text` 40 (the file's own string, sent back unchanged); `modified_at timestamptz null` and `modified_date_text` 40 null; `author` 100; `language` 10; `reading_minutes int`; `categories text[]`; `tags text[]`. Indexes: `published_at`, GIN on `categories` and on `tags`. |
| `content.categories` (new) | `slug` 255 primary key, `title` 255, `description text null`, `sort_order int`, `parent_slug` 255 null. |
| `content.publications` (new) | `position int` primary key, `title` 500, `summary text null`, `type` 50 null, `size` 50 null, `updated` 50 null, `language` 50 null, `file` 500 null, `read_online_url` 500 null, `download_only bool`. |
| `content.refresh_state` (new) | one row (`id` 1): `content_hash` 64, `article_count int`, `refreshed_at` null, `last_failure_at` null, `last_failure_cause` 200 null. |

`slug`, `slug_decoded`, `categories`, `tags`, `categories.slug` and `parent_slug` are plain case-sensitive `text`, the
written reason being LIB-R3, LIB-R4 and LIB-R11: a category, a tag and an address match exactly today. Every other text
column follows the schema's rule (`citext`). The stub `content.articles`, its seed rows and `GET /articles` stay as they
are; retiring them belongs to the pages feature (F4), which replaces what reads them.

## API and event changes
Additive: six new public routes. No event. No change to any route a store build calls on the member API. Supported app
builds reach these routes only after the live domain hands the paths over, which is the cutover plan's step, not this one.

## Risks and rollback
- **The app's own Library journeys cannot run against a lane.** The app's website address is a constant, so they run only at the cutover rehearsal. Until then LIB-R19 rests on the field assertions and the parity run.
- **HTML differs from tsr-web's renderer.** Markdig and remark-html will not match byte for byte. The parity tool compares
  after collapsing whitespace and will still show differences; each is judged by eye and listed in the pull request.
- **The future-dated article** (open question 6): the v1 routes show it, as today; `GET /articles` hides it. Stated, not solved.
- **A content directory on a network mount** could read slowly; the worker's tick is bounded by the file bounds only.
- **Rollback:** remove the gateway block; the tables and the worker are inert without it. The migration is additive.
- **A named pipe or device in the content directory would block a refresh.** Not detected: .NET has no public way to ask a path's kind without opening it, and the directory is a read-only mount of files from git.
- **`OPTIONS` and `HEAD` answer 405 here; today's website answers both.** `OPTIONS` is the check a browser sends before a request from another site (the preflight). The app sends neither. The public pages (Feature 4) will need the preflight.
- **Nothing stands in front of these routes: no rate limit and no shared cache, and each request reads its whole table.** A limit per address and a cache are required before the live domain hands these paths over. The cutover plan owns it.
- **Small differences from the website that the app's reader does not see:** the names of query options are matched without regard to case; numbers are read with .NET's rule for white space; `If-Modified-Since` accepts fewer date forms; equal dates, and equal category orders, tie by slug.

## Verification plan
Levels: **db** = NUnit in `db/tests` (Testcontainers PostgreSQL, the API in process); **contract** = Hurl in
`domains/content/spec/tests` against the default test stack, loaded from `db/synthetic/content`. Preconditions for every
contract case: `tools/test-stack.sh up` and `tools/contract-website.sh test --prepare`.

### TC-LIB-R1-01: reads need no sign-in
Covers: LIB-R1 · Method: Test · Level: contract · Automated in: `v1-articles.hurl`, `v1-article.hurl`, `v1-categories.hurl`, `v1-tags.hurl`, `v1-publications.hurl`, `v1-videos.hurl` (first request of each)
```gherkin
Given no Authorization header
When each of the six routes is requested
Then each answers 200 with "success": true
```
Result: ☐ pass

### TC-LIB-R2-01: the list pages newest first
Covers: LIB-R2 · Method: Test · Level: contract · Automated in: `v1-articles.hurl`
```gherkin
Given 12 published articles in the fixture
When the list is asked with no options, then limit=5, then limit=5&offset=10, then offset=-3, then offset=abc
Then it returns 12 newest first with pagination total 12, limit 20, offset 0, hasMore false
And then 5 with hasMore true
And then 2 articles with offset 10 and hasMore false
And then the same answer as offset 0, twice
```
Result: ☐ pass

### TC-LIB-R3-01: one category
Covers: LIB-R3 · Method: Test · Level: contract · Automated in: `v1-articles.hurl`
```gherkin
When the list is asked with category=<a fixture child slug>
Then only the articles filed under exactly that slug return, and a slug that is a prefix of it returns none
```
Result: ☐ pass

### TC-LIB-R4-01: one tag
Covers: LIB-R4 · Method: Test · Level: contract · Automated in: `v1-articles.hurl`
```gherkin
When the list is asked with tag=<a fixture tag name>
Then only the articles carrying exactly that tag return, and the tag's first word alone returns none
```
Result: ☐ pass

### TC-LIB-R5-01: a word
Covers: LIB-R5 · Method: Test · Level: contract · Automated in: `v1-articles.hurl`
```gherkin
When the list is asked with q=<a word found in one title, one excerpt and one tag of three different articles>
Then exactly those three return, and a word found only in a body returns none
```
Result: ☐ pass

### TC-LIB-R6-01: the four orders
Covers: LIB-R6 · Method: Test · Level: contract · Automated in: `v1-articles.hurl`
```gherkin
When the list is asked with each of the four sort values
Then the first and last slugs are the fixture's oldest, newest, first and last by title, as the value asks
```
Result: ☐ pass

### TC-LIB-R7-01: an unknown order is refused
Covers: LIB-R7 · Method: Test · Level: contract · Automated in: `v1-articles.hurl`
```gherkin
When the list is asked with sort=views:desc
Then it answers 400 with "success": false and error.code "VALIDATION_ERROR" and a non-empty error.message
```
Result: ☐ pass

### TC-LIB-R8-01: a page size out of range is clamped
Covers: LIB-R8 · Method: Test · Level: contract · Automated in: `v1-articles.hurl`
```gherkin
When the list is asked with limit=0, then limit=500, then limit=abc
Then it answers 200 with pagination.limit 1, then 100, then 20
```
Result: ☐ pass

### TC-LIB-R9-01: unused options are ignored
Covers: LIB-R9 · Method: Test · Level: contract · Automated in: `v1-articles.hurl`
```gherkin
When the list is asked with fields=title&nonsense=1
Then the answer equals the answer with no options
```
Result: ☐ pass

### TC-LIB-R26-01: one language
Covers: LIB-R26 · Method: Test · Level: contract · Automated in: `v1-articles.hurl`
```gherkin
Given the fixture's right-to-left article has language "ur" and the others "en"
When the list is asked with locale=ur, then locale=u
Then one article returns, then none
```
Result: ☐ pass

### TC-LIB-R10-01: one article with related
Covers: LIB-R10 · Method: Test · Level: contract · Automated in: `v1-article.hurl`
```gherkin
Given a fixture article that shares one tag with six others and also a category with one of them, A
When it is asked by slug
Then content contains its heading as an HTML element, and rawContent is absent
And relatedArticles has exactly five, A first, then the others sharing the tag newest first
```
Result: ☐ pass

### TC-LIB-R10-02: long, encoded and raw-HTML articles open
Covers: LIB-R10 · Method: Test · Level: contract · Automated in: `v1-article.hurl`
```gherkin
When the 199 character slug, the percent-encoded slug and the raw-HTML article are each asked
Then each answers 200 with its own slug, and content holds no `<script`, no `onerror=` and no `javascript:` from the raw-HTML article
```
Result: ☐ pass

### TC-LIB-R11-01: unknown and unpublished are not found
Covers: LIB-R11 · Method: Test · Level: contract · Automated in: `v1-article.hurl`
```gherkin
When a slug that does not exist and the slug of a fixture draft are each asked
Then both answer 404 with error.code "NOT_FOUND" and error.message "Article not found: " followed by the slug asked, and nothing else
```
Result: ☐ pass

### TC-LIB-R12-01: a draft is in no answer
Covers: LIB-R12, LIB-Q3 · Method: Test · Level: db · Automated in: `db/tests/ContentRefreshTests.cs` `A_draft_is_never_copied_and_appears_in_no_read`
```gherkin
Given a content directory with two published articles and one draft sharing their category and a tag
When one refresh tick runs
Then content.published_articles has two rows and none with the draft's slug
And the list, the category count, the tag count and both related lists do not include it
```
Result: ☐ pass

### TC-LIB-R13-01: the category tree with counts
Covers: LIB-R13 · Method: Test · Level: contract · Automated in: `v1-categories.hurl`
```gherkin
When the categories are asked, then with hierarchical=false
Then 3 parents return in order, each with its subcategories and its count of published articles
And then 7 categories return flat
```
Result: ☐ pass

### TC-LIB-R14-01: tags by use
Covers: LIB-R14 · Method: Test · Level: contract · Automated in: `v1-tags.hurl`
```gherkin
When the tags are asked
Then each has name, slug and articleCount, counts never rise down the list, and "Imam Ali (a.s.)" has slug "imam-ali-as"
```
Result: ☐ pass

### TC-LIB-R15-01: publications with relative links
Covers: LIB-R15 · Method: Test · Level: contract · Automated in: `v1-publications.hurl`
```gherkin
When the publications are asked
Then 3 return in file order with title, summary, type, size, updated and language
And file and readOnlineUrl start with "/" and name no host
```
Result: ☐ pass

### TC-LIB-R16-01: latest videos page
Covers: LIB-R16, LIB-R19 (the videos fields) · Method: Test · Level: db · Automated in: `db/tests/LatestVideosTests.cs` `Videos_page_newest_first`
```gherkin
Given a fake feed of 60 videos
When the videos are asked with no options, then limit=5&offset=8, then limit=99, then limit=0
Then 10 return newest first, then the 9th to 13th, then 50, then 1
And each video has every field of the "YouTube video" row of recon.md section 2, and meta has its six fields
```
Result: ☐ pass

### TC-LIB-R17-01: the feed fails after a good read
Covers: LIB-R17 · Method: Test · Level: db · Automated in: `LatestVideosTests.cs` `A_failed_feed_serves_the_kept_list` (as tsr-web, the answer does not say it is a kept list)
```gherkin
Given one good read, then the fake feed failing, then 31 minutes passing on the test clock
When the videos are asked
Then the same videos return with status 200
```
Result: ☐ pass

### TC-LIB-R18-01: the feed fails before any read
Covers: LIB-R18 · Method: Test · Level: db · Automated in: `LatestVideosTests.cs` `A_feed_never_read_gives_an_empty_list`
```gherkin
Given a fake feed that has always failed
When the videos are asked
Then it answers 200 with an empty videos list
```
Result: ☐ pass

### TC-LIB-R19-01: every field a supported build reads
Covers: LIB-R19 · Method: Test · Level: contract · Automated in: the five `v1-*.hurl` files other than videos (field assertions; the test stack's video list is empty, so its fields are checked in TC-LIB-R16-01)
```gherkin
When each route answers
Then every field in the "Dart reads" column of recon.md section 2 that the server sends (so not `featured`) is present under that name with that kind
And the body has success, data and meta.timestamp, meta.version "1.0", meta.cache.maxAge
```
Result: ☐ pass

### TC-LIB-R20-01: a published article arrives
Covers: LIB-R20 · Method: Test · Level: db · Automated in: `ContentRefreshTests.cs` `A_new_published_file_is_read_on_the_next_tick`
```gherkin
Given one refresh done, then a new published file added
When the next tick runs
Then the list includes it
```
Result: ☐ pass

### TC-LIB-R20-02: the delay is within 10 minutes
Covers: LIB-R20, LIB-R21, LIB-R22 · Method: Inspection · Manual: `ContentRefreshWorker.Interval` is 5 minutes and one tick over the real content finishes within 5 minutes (time one tick on the lane and record it).
Result: ☐ pass

### TC-LIB-R21-01: a changed article
Covers: LIB-R21 · Method: Test · Level: db · Automated in: `ContentRefreshTests.cs` `A_changed_file_replaces_the_article`
```gherkin
Given one refresh done, then the title and body of one file changed
When the next tick runs
Then the article answers with the new title and body, and the other articles are unchanged
```
Result: ☐ pass

### TC-LIB-R22-01: a withdrawn article
Covers: LIB-R22 · Method: Test · Level: db · Automated in: `ContentRefreshTests.cs` `A_file_removed_or_set_to_draft_is_no_longer_returned`
```gherkin
Given one refresh done over four articles, then one file deleted and one set to draft
When the next tick runs
Then both answer 404 and the list has two
```
Result: ☐ pass

### TC-LIB-R23-01: reads during a refresh
Covers: LIB-R23 · Method: Test · Level: db · Automated in: `ContentRefreshTests.cs` `A_reader_sees_the_last_complete_set_until_the_refresh_commits`
```gherkin
Given one refresh done over two articles, and a second refresh over three held open before its commit
When the list is read on another connection
Then it returns the two; after the commit it returns the three
```
Result: ☐ pass

### TC-LIB-R24-01: a failed, empty or halved refresh keeps the last set
Covers: LIB-R24 · Method: Test · Level: db · Automated in: `ContentRefreshTests.cs` `A_refresh_that_fails_or_shrinks_keeps_the_last_set_and_records_why` (four cases: unparsable file, no directory, no published article, 4 articles down to 1)
```gherkin
Given one refresh done over four articles
When the next tick meets the case
Then the list still returns the four
And refresh_state has last_failure_at and the case's cause, and one warning is logged with that cause
```
Result: ☐ pass

### TC-LIB-R25-01: not changed
Covers: LIB-R25 · Method: Test · Level: contract · Automated in: `v1-articles.hurl`, `v1-article.hurl`
```gherkin
Given the ETag of an earlier answer
When the same request is sent with If-None-Match set to it
Then it answers 304 with no body; with another value it answers 200
```
Result: ☐ pass

### TC-LIB-Q1-01: the same answers as today's website
Covers: LIB-Q1 · Method: Test · Level: API parity · Automated in: `tools/website-parity.cs` over `tools/website-parity.cases` (about 40 requests across the six routes)
Preconditions: tsr-web running locally; a lane stack started with `TSR_CONTENT_SRC` set to tsr-web's content directory and `TSR_LANE_WORKERS=content-refresh`, and `pagination.total` equal on both sides.
```gherkin
When each case is fetched from both
Then the tool exits 0: the JSON is equal apart from the ignored fields and the entries of `tools/website-parity.allow`
```
`tools/website-parity.allow` holds one line a known difference (case, JSON path, reason) and is reviewed with the pull request; a difference not in it fails the run. LIB-Q1 is a Must: without Asif's yes to start tsr-web this case cannot run and the feature is not verified.
Result: ☐ pass

### TC-LIB-Q2-01: read time
Covers: LIB-Q2 · Method: Test · Level: API · Manual: 100 requests each of the list and one article against the lane loaded with the real content; record the 95th fastest of each 100 (the time 95 of the 100 are within).
Result: ☐ pass (target 300 ms)

### Standard gates
- [x] `dotnet build TsrApp.slnx`: 0 warnings
- [x] `dotnet test db/tests` (1342), `hosts/api/tests` (97); `domains/content` has no test project of its own
- [x] Every Hurl file on the default test stack (the full run of the root `CLAUDE.md`), with the six new files: 250 files, 3343 requests, 13 Nov 2026
- [ ] `flutter analyze`: not applicable (no app change)
- [ ] AOT publish: the root `CLAUDE.md` lists no such command today; the AOT and trim analyzers run in the build gate

## Living document update
`domains/content/capabilities/library-reads.md`: new, `LIB-R1` to `LIB-R26`, `LIB-Q1` to `LIB-Q3`.
- [x] Written in this pull request

## Tasks
- [x] 1. Packages, the migration and the entities (`ContentContext.cs`); db test that the schema applies.
- [x] 2. `db/synthetic/content/` fixture set.
- [x] 3. `ContentFiles`, `ArticleHtml`, `ContentRefresh` and the worker, test first (`ContentRefreshTests.cs`).
- [x] 4. `V1` answer shape and `GET /api/v1/articles` with its Hurl file; gateway block; compose settings.
- [x] 5. `GET /api/v1/articles/{slug}` with related articles.
- [x] 6. Categories and tags.
- [x] 7. Publications.
- [x] 8. Latest videos with the fake feed tests.
- [x] 9. `tools/website-parity.cs`, its cases, and the parity run (if tsr-web may be started).
- [x] 10a. Capability document, `api.yaml`, the `CLAUDE.md` files, the glossary, `operations.csv` state column.
- [x] 10b. Full gates (the "Standard gates" above) run on 13 Nov 2026. The per-test-case result boxes above are not ticked one by one: the automated ones pass in these runs; TC-LIB-Q1-01 is `parity-results.md`; the app itself (LIB-R19) is not verified.
