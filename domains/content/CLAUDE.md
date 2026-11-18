# domains/content/

Quran, recitation, articles, lectures, books. **Status: partial (2026-11-13).** Built: the app's Library reads (six public
routes under `/api/v1/`, the `content-refresh` worker; capability `capabilities/library-reads.md`), `GET /holy-quran`,
and the stub `GET /articles`, which nothing reads any more (the static site reads the `/api/v1/` routes; removing the stub is a separate change). Lectures, books and search of the
content are planned (`domains/CLAUDE.md`).

## Status

| Slice | Route | State |
|---|---|---|
| `v1-articles` | `GET /api/v1/articles` | built; public; the list of published articles |
| `v1-article` | `GET /api/v1/articles/{slug}` | built; public; one article as HTML with five related |
| `v1-categories` | `GET /api/v1/taxonomies/categories` | built; public; the tree with counts |
| `v1-tags` | `GET /api/v1/taxonomies/tags` | built; public; tags by use |
| `v1-publications` | `GET /api/v1/publications` | built; public; the publications with their links |
| `v1-videos` | `GET /api/v1/youtube` | built; public; the channel's latest videos, kept in memory |
| `holy-quran` | `GET /holy-quran` | built; sign-in only |
| `list-published-articles` | `GET /articles` | stub (site spike); public; reads `content.articles` |

**The stub is separate from the Library reads.** `GET /articles` and its table `content.articles` (seeded rows, the
published rule of `spec/glossary.md` by `published_at`) still exist and share nothing with the `/api/v1/` routes, which
read `published_articles`, `categories` and `publications`. Do not join the two or move rows between them.

## Dependencies

None (`ContentModule.Dependencies` is empty). The public reads have no caller, and `GET /holy-quran` needs only a
sign-in, so nothing calls `access`.

## Public reads (rule 4 of `domains/CLAUDE.md`)

Each is marked `security: []` in `spec/api.yaml`. Why each is public, and why its query returns only public data:

| Route | Why public | Only published data because |
|---|---|---|
| `GET /api/v1/articles` | guests browse the Library; the app sends no sign-in | it reads `content.published_articles`, where the refresh never copies a draft |
| `GET /api/v1/articles/{slug}` | the same; article links are shared | the same table, the related articles too; a draft's slug is an unknown slug (404) |
| `GET /api/v1/taxonomies/categories` | the same | categories are public; the counts are over `published_articles` |
| `GET /api/v1/taxonomies/tags` | the same | tags and counts come from `published_articles` only |
| `GET /api/v1/publications` | the same | it reads `content.publications`, the entries of the public publications page that have a link |
| `GET /api/v1/youtube` | the same; the home screen shows it to guests | it sends what the channel's public feed lists; no database |
| `GET /articles` (stub) | it was the site spike's list; no reader today | the published rule is in the query of `ListPublishedArticles` |

The six `/api/v1/` routes answer in the website's shape, `{success, data, meta, pagination}`, and fail as
`{success: false, error: {code, message}, meta}` (`api/domain/V1.cs`): the named exception to the `{"detail"}` rule
(root `CLAUDE.md` rule 7). Map a new one with `V1.MapGet`, so an unexpected failure is answered in that shape too.

## The worker: `content-refresh`

`api/workers/ContentRefreshWorker.cs`, run only in the mode `--workers` with `content-refresh` in `TSR_WORKERS`: one
refresh at start, then every 5 minutes. A tick (`api/domain/ContentRefresh.cs`) reads the directory `TSR_CONTENT_DIR`
(`articles/*.md`, `categories/*.md`, `pages/tsr-publications.md`), keeps only articles whose `status` is `publish` or
`published`, and replaces `published_articles`, `categories` and `publications` in one transaction. Nothing is written
when the set's hash equals the last one. A read that fails, finds no published article, or finds fewer than half of the
last count keeps the last set, writes the cause to `content.refresh_state` and logs one warning. It sends nothing
outward. One worker instance is the supported setup.

## Settings (as the code reads them)

| Setting | Read by | Meaning |
|---|---|---|
| `TSR_CONTENT_DIR` | the worker, each tick | The content directory inside the container. Unset, empty or missing: every tick keeps the last set with cause `no content directory`. The compose files mount the files read-only at `/var/tsr/content`; the default test stack sets this to that path, the dev stack leaves it empty |
| `TSR_CONTENT_SRC` | `docker-compose.dev.yml` only, never the code | The host directory mounted at `/var/tsr/content`. Default `./db/synthetic/content`; a parity run names the website's own content files |
| `TSR_YOUTUBE_CHANNEL_ID` | `YouTubeFeed`, and `V1Videos` for `data.meta.channelId` | Absent (dev and production): the channel in the code, `YouTubeFeed.DefaultChannel`, a public id. Present: the channel named. Set to nothing (every test stack and the test host of `db/tests`): no outside call, an empty list |
| `TSR_YOUTUBE_FEED_URL` | `YouTubeFeed` | The feed's address; `http` or `https` only. Empty: YouTube's own. In no compose file |

None is required: the API starts without them.

## Where things are

| Need | File |
|---|---|
| What the Library reads do today (requirements, decisions) | `capabilities/library-reads.md` |
| Words to use (Article, Slug, Published, Category, Tag ...) | `spec/glossary.md` |
| The HTTP contract, field shapes and limits | `spec/api.yaml` |
| Behaviour over HTTP | `spec/tests/v1-*.hurl` (test stack; `tools/contract-website.sh test`), `list-published-articles.hurl`, `holy-quran.hurl` |
| Module: registration, routes, workers, dependencies | `api/ContentModule.cs` |
| One Library slice end to end | `api/features/v1-articles/V1Articles.cs` (the others: `v1-article`, `v1-categories`, `v1-tags`, `v1-publications`, `v1-videos`) |
| The `/api/v1/` answer shape, ETag, 304, number clamps | `api/domain/V1.cs` |
| The fields of an article in a list | `api/domain/ArticleListItem.cs` |
| Reading the content files, their bounds and failures | `api/domain/ContentFiles.cs`, `FrontMatter.cs` |
| Markdown to safe HTML (CommonMark with footnotes, pipe tables and bare web addresses as links, LIB-D18), reading time | `api/domain/ArticleHtml.cs` |
| One refresh, the half rule, the hash | `api/domain/ContentRefresh.cs` |
| The feed reader and the 30 minute copy | `api/domain/LatestVideos.cs` |
| Database-backed tests | `db/tests/V1*Tests.cs`, `ContentRefreshTests.cs`, `ContentFilesTests.cs`, `LatestVideosTests.cs`, `YouTubeFeedTests.cs`, `LibraryReadsSchemaTests.cs` |
| The synthetic content files (12 published, 2 drafts) | `db/synthetic/content/` (its `README.md` maps files to cases) |
| The article list and article pages of the static site (read from the `/api/v1/` routes, in the present website's markup; the body's rules are `site/ArticleBody.cs`) | `site/` |
| The publications page of the static site (`/tsr-publications/`; the tabs, their order and the sort are `site/Publication.cs`, the script's part is in `hosts/site/wwwroot/site.js`) | `site/PublicationsPage.razor` |
| Tables | schema `content` in `api/ContentContext.cs`, migrations in `api/Migrations/`: `published_articles`, `categories`, `publications`, `refresh_state` (the Library copy); `articles` (the stub); `holy_quran` |

Slugs, categories and tags of the Library copy are case-sensitive `text`, the written exception to "every text column
is citext" (`db/tests/SchemaGuardTests.cs`).

## Checks

```
tools/test-stack.sh up                             # the default test stack runs content-refresh over db/synthetic/content
tools/contract-website.sh test                     # waits for 12 published articles, then runs spec/tests/v1-*.hurl
TSR_STACK=n TSR_LANE_WORKERS=content-refresh tools/test-stack.sh up && TSR_STACK=n tools/contract-website.sh test   # on a lane
dotnet test db/tests                               # the refresh, the reader, the routes in process, the fake feed (Docker)
```

Parity with today's website (by hand; the website runs locally, a lane is loaded with its content files; steps and the
last result in `docs/specs/website-port/parity-results.md`):

```
TSR_STACK=n TSR_CONTENT_SRC=<the website's content directory> TSR_LANE_WORKERS=content-refresh tools/test-stack.sh up
dotnet run tools/website-parity.cs -- <website base URL> http://localhost:810n            # tools/website-parity.cases
dotnet run tools/website-parity.cs -- <website base URL> http://localhost:810n --sweep    # every published article
```

A difference not listed in `tools/website-parity.allow` fails the run. A case may state its two expected statuses (`| expect 404 200`); the draft case runs only with `TSR_PARITY_DRAFT_SLUG` set (a draft's slug is never written in this repository). `contract-website.sh` has no `parity` side.

## Events

None yet.

## Placeholders

None left (`api/Planned.cs` is gone). The two recitation leaderboard routes the catalog first listed here are built in `classes`: they read class attendance (`domains/classes/CLAUDE.md`).

## Published views (rule 2; migration `PublishedViews`, read-only to the API role)

| View | Columns | Known readers |
|---|---|---|
| `v_quran` | id, surah, arabic, verses | classes (conduction) |

`GET /holy-quran` reads `content.holy_quran` itself (this domain's table: the 114 surahs and verse counts); classes' conduction screens read the same rows through `v_quran`.
