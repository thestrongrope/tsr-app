# Website port, slice 5: implementer's notes (18 Nov 2026)

Issue #68 (part of #38): the home page `/`. Uncommitted on `feature/68-home-page`. No plan exists: the test names are the test cases.

## What was built
- `domains/content/site/HomePage.razor` (new): the markup and classes of `page.tsx` and `CategoryCard.tsx`. `Home.cs` (new): the rules (five newest, first category's title, short date, video checks, "1,234 views"). Registered at `/` by `ContentSite.PagesAsync`, which reads one more route, `/api/v1/youtube?limit=6`.
- `ArticleFilters.Cards` (new): the one tree and count; `Panel` is now `Cards` without the parents that hold no article. `FilterCategory` gains `Description`; `ArticleSummary` gains `PublishedDate`.
- Host: `HomePage.razor` removed; `SiteBuilder` no longer inserts a `/` page; `NavTitle` (only the sample used it) removed from `SitePage`, `ContentSite`, `PlatformSite`. A build with no content module has no `/` page (no test needed one).
- `site.js` (+~25 lines): `setUpHomeCategories`. `site.css` regenerated (+357 lines). Three photos in `hosts/site/wwwroot/uploads/` (byte for byte, checked with `cmp`), named in `SitePage.Files`. `domains/content/CLAUDE.md`: one row. `FakeApi.HealthyAnswers` gains the empty video answer (what every test stack sends).

## Decisions I had to make
1. **Parents with no article of their own are kept** on the home page (the present site shows them, with 0 and their children). `Panel` on the article list still drops them. So the cards are not `Panel`; both come from `Cards`.
2. **Scripts off**: every card's subcategories are written open and the toggle button hidden (`hidden` attribute): every link is reachable. The script closes the lists and shows the buttons (the present site's closed start).
3. **The "New" badge is not written**: it depends on today's date and the page is built once. Say so if the owner wants it.
4. **Verse**: `dir="rtl"` as the present site; no `lang="ar"` (the stylesheet's `div:has([lang="ar"])` rule would turn the whole banner, same finding as slice 3).
5. Search box: a form and an input, no button (as `SearchBar.tsx`; Enter sends it). I added `aria-label`. Lecture form is the present one; it goes to `/lectures`, not built yet.
6. Dates: the file's text read as UTC when it has no zone, `Nov 10, 2026`; unreadable or missing: no date. A video's "Invalid Date" is not shown. A video with no thumbnail shows the present site's red icon.
7. Build stops on a video id outside `[A-Za-z0-9_-]{1,32}`, no title, or a thumbnail that is not https (they go into addresses). The video route failing stops the build (it never fails by contract). Thumbnails are the addresses the route sends (`i.ytimg.com`), hot-linked as before.
8. The links use the site's own form: `/articles/?category=x`, `/articles/slug/`, `/articles/` (the issue writes `/articles?q=`).
9. **Photos carry no licence note** (owner accepted, issue 68): they are of named people and an organisation's seal. Same gap as the logos.

## Checks
| Check | Result |
|---|---|
| `dotnet build TsrApp.slnx` | 0 warnings, 0 errors |
| `dotnet test hosts/site/tests` | 611 passed, 0 failed (512 before: 19 in `HomePageTests`, the rest are stylesheet cases) |
| `node --test hosts/site/tests/js/` | 15 passed (no new function is pure: none added) |
`HomePageTests` were run first against the sample and failed on the missing sections, markup and the unread video route. Not run: `hosts/api/tests`, `db/tests`, Hurl, `flutter analyze`.

## Untested or unsure
- **`setUpHomeCategories` (DOM) never ran** (no browser): only `node --check`. Untested: lists closing at load, the buttons showing, the arrow turning, the label.
- No page generated or opened; layout rests on equal classes. Order of the five articles trusts the route's newest-first sort.
- The tests use a canned answer with six videos' worth of fields; a real feed was not seen (stacks send none, so the section cannot be compared on a lane).
- Raw `{ }` and `@` in a video title are escaped by Razor; not tested on real titles.
