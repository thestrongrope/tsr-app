# Library reads: parity with today's website (13 Nov 2026)

The run of TC-LIB-Q1-01 and TC-LIB-Q2-01 of `f1-plan-draft.md`. **Result after the review's fix pass: passed.** The tool
exits 0 on the cases and on the sweep: no difference outside `tools/website-parity.allow`, no status other than the ones
the cases file expects, and no article differs in visible text or in a link target.

## The two sides
- **tsr-web:** `~/Projects/tsr-web/web`, branch `feat/app-links-well-known`, commit `109927c60f9e1fc887789b95d064f46ae2d69f10`,
  clean tree, run in place with `npx next dev -p 3100`. It needed no environment variable and no secret to serve these routes.
- **New API:** lane 3 (`http://localhost:8103`), this checkout (`dotnet-11`, uncommitted), started with
  `TSR_STACK=3 TSR_CONTENT_SRC=~/Projects/tsr-web/web/content TSR_LANE_WORKERS=content-refresh TSR_YOUTUBE_CHANNEL_ID=<the channel id in tsr-web's youtube/route.ts:41> tools/test-stack.sh up`.
  The worker logged "copied 501 articles, 53 categories, 38 publications"; `pagination.total` is 501 on both sides.

## How to run it again
```
dotnet run tools/website-parity.cs -- http://localhost:3100 http://localhost:8103            # the cases
dotnet run tools/website-parity.cs -- http://localhost:3100 http://localhost:8103 --sweep    # every article
dotnet run tools/website-parity.cs -- http://localhost:3100 http://localhost:8103 --timing /api/v1/articles /api/v1/articles/<slug>
```
Compared: status code, `Cache-Control`, and the JSON value by value. Never compared: `meta.timestamp`, `meta.cache.expires`, `ETag`.
- An article's `content` is compared three times: as HTML after collapsing white space (allowed to differ), as the text a
  reader sees (`data.content(text)`) and as its `href` and `src` values in order (`data.content(links)`); the last two are not allowed to differ.
- A list whose items each have their own slug is compared item by item matched by slug, and its order separately (`data(order)`).
- A case line ending in `| expect <tsr-web status> <new status>` passes on exactly those statuses. A 5xx on either side
  fails any case, and no allow line can cover a status.
- The draft case runs only with `TSR_PARITY_DRAFT_SLUG=<a draft's slug>` in the environment; no draft's slug is written in this repository.

## Counts (rerun after the fix pass, lanes rebuilt)

| Run | Total | Equal | Equal but for allowed differences | The expected statuses | Failed |
|---|---|---|---|---|---|
| Cases (`tools/website-parity.cases`, draft variable set) | 68 | 54 | 11 | 3 | 0 |
| Cases, draft variable unset ("draft case skipped") | 67 | 54 | 11 | 2 | 0 |
| Sweep: every published article | 501 | 0 | 497 | 4 | 0 |

The list of slugs is the same on both sides (501, none on one side only). The 4 "expected statuses" of the sweep are the
percent-encoded slugs (tsr-web 404, new 200); the 3 of the cases are two of those and one draft (tsr-web 200, new 404).

In the sweep, on the 497 articles both sides serve:
- **Visible text:** equal on all.
- **Link targets (`data.content(links)`):** equal on all. 37 articles hold links, 54 `href` or `src` values in all, the same
  on both sides (counted with a one-off script); no link is dropped or emptied on the new side over today's content.
- `rawContent` is absent on all (intended). The HTML form differs on 173; read with a one-off script, 112 are equal once
  white space between tags is removed (`<li> <p>` against `<li><p>`), 20 more once `&quot;` is read as `"`, 18 more once
  every entity is decoded, and the last 23 first differ at `<br>` against `<br />` (12 of the 23 were looked at). 324 have the same HTML outright.

Allow lines met in the cases run: `data.rawContent` 4, `data.content` 3, video `description` 14, `data.meta.lastUpdated` 5,
flat categories `data(order)` 2, video `views` 4. Allowed but not met: video `title`, video `intro`, `data.meta.cacheHit`
(no title of the 15 newest videos holds an entity today).

## TC-LIB-Q2-01: read time (lane 3, through the gateway, sequential, 100 reads each)

| Read | 95th fastest | 50th | Slowest |
|---|---|---|---|
| `GET /api/v1/articles` | 4.9 ms | 1.9 ms | 35.4 ms |
| `GET /api/v1/articles/no-one-can-be-compared-to-the-ahl-al-bayt` | 3.7 ms | 2.3 ms | 5.4 ms |
| `GET /api/v1/articles/outcomes-of-intezaar-in-history-success-and-failure` | 2.8 ms | 2.3 ms | 4.2 ms |

Target 300 ms: met by a wide margin. One client on the same machine; nothing was tuned.

## The differences found, and how each is now held
Each was judged against a decision already agreed (the slug rule widens; drafts are never copied; the plan's Risks: equal
category orders tie by slug). None is covered by a `*` path any more.

### 1. A percent-encoded slug: the two sides answer the opposite way (4 articles; 2 are cases)
- Cases: `/api/v1/articles/what-it-means-to-be-a-true-%e1%b8%a5awari` and the Urdu slug starting `%d9%86%da%a9`. Sweep: the same
  two and two more (4 files in `content/articles` have a percent-encoded `slug`).
- Path `$status`: tsr-web **404** (`NOT_FOUND`), new **200** with the article. The other paths of these cases follow from it.
- Held by `expect 404 200` on the two cases and by the sweep's rule for a slug holding `%`.
- Probed by hand: the slug with its `%` encoded again (`%25e1%25b8%25a5`) answers **200 on tsr-web and 404 on the new side**.
  Upper case escapes (`%E1%B8%A5`) answer as the lower case ones on each side.
- tsr-web: `web/src/lib/markdown.ts:53-54` keys its lookup by the file's `slug` text as written (still encoded), and
  `markdown.ts:75` looks up the route value, which Next.js has already decoded; they never match.
- New: `domains/content/api/features/v1-article/V1Article.cs:17` and `:72` match the decoded route value against
  `slug_decoded` (the plan's rule).
- What it means for the app: `tsr_web_service.dart:110` sends `/api/v1/articles/$slug` with the slug as listed, so today these
  four articles cannot be opened from the app (if production answers as this local run does: not checked) and on the new
  side they open. A client that encodes the slug a second time would lose them. Likely a wanted change, but it is a change.

### 2. A draft's slug (1 optional case; expected by the spec)
- One draft was checked by hand and through `TSR_PARITY_DRAFT_SLUG`; its slug is not written here. tsr-web **200** with the draft, new **404**.
- tsr-web: `getPostBySlug` (`web/src/lib/markdown.ts:64-95`) reads any file by slug and never looks at `status`.
- New: `domains/content/api/domain/ContentFiles.cs:178` keeps only `publish` and `published`, so a draft is never stored.
- LIB-Q1 in `spec-draft.md` names this as a listed difference (LIB-R11, LIB-R12). Held by the case's `expect 200 404`.

### 3. The flat category list: two categories with the same `order` swap places (2 cases)
- Cases `/api/v1/taxonomies/categories?hierarchical=false` (with and without `includeArticleCounts=false`). Paths `data[26]`
  and `data[27]`: tsr-web has `imam-hasan` then `imamate`; new has `imamate` then `imam-hasan` (both have `order: 4`).
- tsr-web: `web/src/lib/markdown.ts:175` and `:192`: a stable sort by `order` over `fs.readdirSync`, so ties keep the
  directory's order. That order belongs to the file system: on this Mac it is by byte (`-` before `a`); on the production
  host it may be another.
- New: `domains/content/api/features/v1-categories/V1Categories.cs:55`, `order by sort_order, slug`, under the database's
  `en_US.utf8` collation, which ignores the hyphen.
- Held by one allow line on `data(order)` for the flat cases; every item is still compared field by field, matched by
  slug, and no field differs.
- The default (hierarchical) answer, the one the app reads, is equal on both sides. The plan's Risks section already lists
  "equal category orders tie by slug". Matching this Mac's order would need byte order on that sort (`COLLATE "C"`).

Nothing else differs: every list case (pages, clamps, the four orders including title order over all 501 articles, the
refused orders, `q`, category, tag, language, combinations), tags, publications with each language, the hierarchical
categories and the video cases are equal or equal but for the allowed lines.

### 4. Conditional requests: `If-None-Match` wins on the new side (deliberate, found in review; not a parity case)
- Request: an article with an `If-None-Match` that does not match and an `If-Modified-Since` equal to its `Last-Modified`.
  tsr-web **304**; new **200** with the body. With the right ETag and the date both answer 304; with the date alone both answer 304.
- tsr-web: `checkConditionalRequest` (`web/src/app/api/lib/cache-utils.ts:56-73`) answers 304 when either header matches.
- New: `IsNotModified` in `domains/content/api/domain/V1.cs` reads `If-Modified-Since` only when no `If-None-Match` is sent
  (RFC 9110 section 13.1.3), so a cache that sends both does not keep an old copy of a corrected article. Capability decision LIB-D16.
- Tests: `db/tests/V1ArticleTests.cs` (`If_none_match_is_judged_alone_when_if_modified_since_comes_with_it`), `v1-article.hurl` requests 21 and 22.

## Noise seen and how it was handled
- **tsr-web's first video answer was three months old.** Next.js kept the feed in `.next/` from an earlier run and served it
  while refreshing (`markdown.ts:357`, `revalidate: 3600`), and the route then held it for 30 minutes (`youtube/route.ts:52`).
  tsr-web was restarted once; after that both sides list the same 15 videos. Nothing was added to the allow file for it.
- `data.meta.lastUpdated` and `data.meta.cacheHit` on the videos route depend on when each side last read the feed: allowed as noise.
- A video's `views` differed on the rerun (450 against 458 for one video): the two sides had read the feed about an hour
  apart. Allowed as noise, one line, added in the fix pass.

## Not verified
- Production tsr-web: only the local dev server (`next dev`) was compared, not a production build and not the live site.
- The app itself against lane 3 (its website address is a constant; the plan's Risks section).
- Conditional requests, `ETag` values, `Last-Modified`, CORS headers, `OPTIONS` and `HEAD`: the tool does not compare
  them (conditional requests were probed by hand once, difference 4 above).
- Link targets inside raw HTML or emptied as unsafe: today's content has none that differ, so that path of the tool has
  only ever reported "equal".
- Languages other than `en`: every article file is `en`, so `locale=ur` is empty on both sides.
- Video `title` decoding: no current title holds an entity, so that allow line was not exercised.
- Timing under more than one client, or from another machine.
- The tool has no unit tests of its own; its checks were the runs above, the usage exit (2) and a side that is down (2).
