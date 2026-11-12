# domains/content/

Quran, recitation, articles, lectures, books. **Status: stub (2026-11-10).** Articles, built for the site spike (`docs/specs/site-spike/results.md`) and kept as the example of a domain
with `site/` pages. Lectures, books, the Quran and the content pipelines are planned
(`domains/CLAUDE.md`).

Table `holy_quran` (the 114 surahs and verse counts, PHP's table, ported in the schema phase; read by `GET /holy-quran`, `api/features/holy-quran/HolyQuran.cs`, a sign-in-only route) is in schema `content` beside `articles`.

## Dependencies

None (`ContentModule.Dependencies` is empty). `GET /articles` is a public read and `GET /holy-quran` needs only a sign-in, so it calls no `access`.

## Public reads (rule 4 of `domains/CLAUDE.md`)

`GET /articles` is a public read: no caller and no `access` check. **Its query returns only public
data**: the published rule (`spec/glossary.md`) is in the query of `ListPublishedArticles`, so no
client or the site can show a draft or a scheduled article by mistake.

## Where things are

| Need | File |
|---|---|
| Words to use (Article, Slug, Published ...) | `spec/glossary.md` |
| The HTTP contract, field shapes and limits | `spec/api.yaml` |
| Behaviour over HTTP, any implementation | `spec/tests/list-published-articles.hurl` (needs the dev stack up; command in the root `CLAUDE.md`) |
| Module: registration, routes, dependencies | `api/ContentModule.cs` |
| One use case end to end | `api/features/list-published-articles/ListPublishedArticles.cs` |
| Its pages on the static site | `site/` |
| Table | `articles` in schema `content` (`api/ContentContext.cs`, migrations in `api/Migrations/`) |

## Events

None yet.

## Placeholders

The operations not built yet (3: Quran and the like) are 501 placeholders in `api/Planned.cs`; building one deletes its line there and flips its state in `docs/specs/initial-build/operations.csv`.

## Published views (rule 2; migration `PublishedViews`, read-only to the API role)

| View | Columns | Known readers |
|---|---|---|
| `v_quran` | id, surah, arabic, verses | classes (conduction) |
