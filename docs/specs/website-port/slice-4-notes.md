# Website port, slice 4: implementer's notes (18 Nov 2026)

Issue #67 (part of #38): the article list's category and tag filters. Uncommitted on `feature/67-article-list-filters`. No plan exists: the test names are the test cases.

## What was built
- `domains/content/site/ArticleFilters.cs` (new): `Slugify`, `Tokens` ("|a|b|" lists), `Panel` (tree and counts), `DataJson` (heading data).
- `Article.cs`: `ArticleSummary` gains `Tags`, `Category` gains `Description` (both from `api.yaml`). `ContentSite` stops the build on a list article without categories or tags, and hands the page `Panel` and `FilterData`.
- `ArticleIndexPage.razor`: the filter panel (markup and classes of `CategoryFilter.tsx`), heading, reset link and nothing-found box; each card has `data-categories` and `data-tags`.
- `site.js` (+ about 150 lines): pure functions `slugify`, `readFilter`, `matchesFilter`, `headingFor`, `chipTitle`, `noMatchText`, `linkState` (exported for Node) and `setUpArticleFilters` (DOM). No request: R44 has a test that `site.js` has no `fetch(` and the page no `search-index`.
- `site.css` regenerated (+134 lines). `domains/content/CLAUDE.md`: one row.

## The present site's rules, as found (`ArticlesList.tsx`)
- Category: `article.categories.includes(slug)`, exact and case-sensitive. Counts are recomputed over the articles by the slug itself: a parent does not count its children's articles; a parent or child with 0 is left out (so a parent with only children's articles disappears with them). The API's `articleCount` is not used.
- Tag, three rules: `t === tag`, `t.toLowerCase() === tag.toLowerCase()`, `slugify(t) === slugify(tag)` with `slugify = lower, /[^a-z0-9]+/g -> '-', trim one dash each end`. The third holds whenever the first two do, so each card carries only its slugified tags and the script slugifies the query (same function). Quirk kept: a tag with no Latin letter or digit slugifies to "" and matches every card holding such a tag. U+0130 is lower-cased as JavaScript does, in C# too (tested).
- Heading: tag wins over category; `Articles tagged "X"` with X the first spelling found for it walking articles in list order; category heading has the parent title as a smaller prefix.
- Panel starts closed when a filter is active, open otherwise; every parent's subcategories start closed; both filters apply together (AND).

## Unknown filter (SITE-R43)
Present site: no card, heading shows the raw slug (category) or the typed tag, and a box "No articles found in this category / with tag "x"" with "Try selecting a different category/tag". Done the same. Scripts off: the whole list under "All Articles" with the panel open and every link working.

## Decisions I had to make
1. The present box also shows a "Go to Admin Panel" link when no category is set. **Left out**: the static site has no `/admin`.
2. `animate-in slide-in-from-top-2` (a plugin class the stylesheet lacks, and an animation) dropped from the panel body and subcategory lists.
3. The chip beside "Filter by Category" shows the title only for a category the panel lists; otherwise the slug, as on the present site (`chip` in the data).
4. Without scripts the header button and nothing else is dead; the subcategory arrows are written hidden. Subcategories are written open then.
5. `hidden` attribute where the element has no display class; for the cards and the reset link (`block`, `inline-flex`) the class `hidden` (cards) or a hidden wrapper (reset link), because `inline-flex` is later in the stylesheet than `hidden`.
6. A category slug holding "|" stops the build (it would break the token match).
7. Titles and descriptions are entity-decoded as the rest of the site does; the present site would show them raw.

## Page size (100 synthetic cards, 2 tags each, one category)
Generated `/articles/`: 74,499 bytes before, 82,997 after (+8,498): about 66 bytes per card, the rest is the panel and the data (447 bytes here). The panel's classes are long (about 1.6 KB per parent, 1 KB per child), so the real tree with 501 cards may add roughly 80 KB uncompressed; not measured on real data.

## Checks
| Check | Result |
|---|---|
| `dotnet build TsrApp.slnx` | 0 warnings, 0 errors |
| `dotnet test hosts/site/tests` | 512 passed (472 before): 24 new in `ArticleFilterTests`, 16 new stylesheet cases |
| `node --test hosts/site/tests/js/` | 15 passed (3 before) |
Each new test was run against stubs first and failed for the missing behaviour (empty attributes, `NotImplementedException`, `is not a function`).

## Not done or untested
- **`setUpArticleFilters` (DOM) never ran**: no browser. Only `node --check` passed. Untested: hiding cards, setting the heading, active link classes, panel and subcategory toggles. It needs one look in a browser with `?category=`, `?tag=` and an unknown value.
- Not compared with the present site on real content; the order of tags/categories is assumed to follow the list route.
- Not run: `hosts/api/tests`, `db/tests`, Hurl, `flutter analyze`. The search box (`?q=`) and old addresses are out of scope.
