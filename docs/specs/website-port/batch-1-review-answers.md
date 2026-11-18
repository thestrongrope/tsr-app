# Batch 1 review findings: answers

Reports: `batch-1-review-quality.md` (1 to 15), `batch-1-review-security.md` (L1 to L3, I1 to I3). Changes are uncommitted.
Tests are in `hosts/site/tests` (C#) and `hosts/site/tests/js/site.test.js` (Node).

| Id | Result | Proof or reason |
|---|---|---|
| L1 | fixed | `ContentSite.IsAddress`: https absolute, or `/` + a character that is not `/` or `\`; no backslash, control or white space. The build stops naming publication and field. `TC_SITE_R30_06` (12 bad forms x both fields: `/\host`, tab, `//host`, `javascript:`, `http:`...), `TC_SITE_R30_07` (good forms) |
| L2 | fixed | Category slug (and a parent) must match `^[a-z0-9]+(-[a-z0-9]+)*$`, else the build stops naming it: `TC_SITE_R45_01..03`. `site.js` builds both selectors with `CSS.escape`: `TC_SITE_R44_03` scans for an unescaped selector. See note 1 |
| L3 | fixed | Thumbnail host must be `i.ytimg.com` or `i1` to `i4.ytimg.com`, https, no user info (`Home.IsYouTubeImage`): `TC_SITE_R53_03` (other host, `@` trick, http, `javascript:`), `TC_SITE_R53_06`. See note 2 |
| 5 | fixed | A bad video is left out with one `site: warning:` line on stderr naming the reason; none left: no section. A failed route still stops the build: `TC_SITE_R53_03`, `_05`, `_04` |
| 2 | fixed | The build sequence moved from `Program.cs` into `SiteBuilder.BuildAsync`; `TC_SITE_R22_04` (a missing file stops it, output folder untouched), `_05` (writes every page), `_06` (Program.cs calls `BuildAsync`) |
| 3 | fixed | By contract the two numbers are the same (`api.yaml`: "published articles filed under this slug itself, a parent's count does not include its children's"; the route counts `published_articles` by `categories @> slug`). `Panel` and `Cards` use `articleCount`; the recount is gone: `TC_SITE_R42_01`, `_02`. Fixtures' counts now match their lists |
| 4 | fixed | The page writes every sentence: `data-article-filters` has `texts` (`ArticleFilters.cs`; the unfiltered heading and description use the same constants), the publications page has `data-count-*` and `data-less-label`. `site.js` only fills `{name}` and `{count}`. `TC_SITE_R43_05`, `TC_SITE_R33_08`, `TC_SITE_R44_02` (script holds none of nine sentences), Node `R43-03..05`, `R33-04`. Aria labels ("Expand", "Collapse subcategories") stay in the script: labels, not sentences |
| 9 | fixed | Theme and menu are set up first; each part runs in `attempt`, which reports with `console.error` and goes on. Node `R50-03`. The wiring itself is not run in a browser (see 1) |
| 11 | fixed | The four comments: `site.test.js` line 1, `ArticleFilters.cs` summary, `ContentSite.cs` summary, `site.js` header. Also `HomePage.razor` and `PublicationsPage.razor` comments |
| 12 | fixed | `A_site_module_builds_its_pages_alone` now asserts only content may and must own `/` (`Any(p => p.Path == "/") == (name == "content")`) beside `Is.Not.Empty`. The nav assertion is gone with `NavTitle` |
| 15 | fixed | The tab classes are written once (`TabClass`, `TabCountClass`); the `data-*-class` attributes use them. `TC_SITE_R32_02` (a refactor guard: it passed before as well) |
| 7 | fixed | The form has `data-article-search`; `site.js` sends the trimmed text, no `q` when empty (`searchTarget`): Node `R52-02`, `TC_SITE_R52_02`. No clear button. The extra `aria-label` on the input stays |
| 1 | not fixed | Out of scope: the browser run is yours |
| 6 | not fixed | A 0.5rem spacing difference, only for an article whose first category has no known title |
| 8 | not fixed | `?q=` search belongs to the search slice |
| 10 | not fixed, a decision for the owner | `/status/` is still built but linked from no page. Link it from the footer, or drop it |
| 13 | not fixed | The scan is a cheap guard; a browser check (finding 1) is the real one |
| 14 | not fixed | Needs real Urdu and Hindi titles compared against the present site; not available here |
| I1 | not fixed | Bounded by the 10 s call timeout and the 5 minute build limit; a build cannot publish a partial site |
| I2 | not fixed | A duplicate category slug still throws `ArgumentException` (no page is published; the message is less clear). Not one line with a test |
| I3 | not fixed | The data is in an attribute, never a script block |

## Notes
1. The API accepts any category file name that is one path segment (`ContentFiles.Slug`). The 50 real category files in the present site and the 7 synthetic ones are all lower case, digits and dashes, so the build pattern is stricter than the API on purpose. An API slug with an upper-case letter or an underscore now stops the build.
2. I could not read the real feed here. Its thumbnails are, as I know the format, on `i1` to `i4.ytimg.com`; the route's own fallback is `i.ytimg.com`. Please confirm one real answer.
3. L1 as decided allows only `https:` absolute addresses. The API contract also allows `http:`; a real `http:` publication address now stops the build.
4. `tools/site-css.sh` was not needed: no class changed (`StylesheetTests` pass).
5. The C# tests that need a new signature failed to compile first; the behaviour tests (L1, L2, video) were not run red one by one. The Node tests were run red first.

## The browser run and the comparison (18 Nov 2026, after the fixes)

Lane 5 was started from this branch with the present website's published content (501 articles, 38 publications); the
site was generated from it (507 pages) and served from `build/site`. This answers quality finding 1.

| Check | Result |
|---|---|
| Home | renders; the three photos load; a category card opens and closes; no script error. No video section: every test stack reads no feed |
| Publications | 4 tabs (English 30, Hindi 2, Multilingual 3, Urdu 3); a tab click shows only its group; typing narrows it and "No matches" shows for none; "more" opens and closes a summary |
| Article list filters | `?category=imamate` shows 82 with the heading "Beliefs (Aqaid) / Imamate" and the parent marked; `?tag=Ahle%20Bait` shows 125; an unknown category shows no card and the "No articles found" box |
| A hostile `?tag=` value (a quote, a bracket, an `<img onerror>`) | shown as text in the heading; nothing injected; no script error |
| About, Donate | render; the QR image loads; the menu opens with the three links; the theme switch works |
| `tools/site-compare.cs` against https://thestrongrope.com, 59 pages | list 501 on each side; 46 equal, 13 allowed (11 reference-comma, 2 status), 0 not allowed |
| Title and main text against the live pages, by a one-off script | `/about` and `/donate`: equal, word for word. `/tsr-publications`: equal, plus the other languages' groups, which are in the page by design (SITE-R35). `/`: equal, plus the subcategories (open with scripts off, by design), minus Latest Videos (the lane sends none) |

Not checked: the pages with scripts switched off in a real browser; narrow (phone) widths; the dark theme on the new
pages; the Latest Videos section with a real feed. `tools/site-compare.cs` does not cover the new page kinds yet.

Found on the way: the production API answers `/api/v1/youtube` with no video, because `docker-compose.yml` passes
`TSR_YOUTUBE_CHANNEL_ID` empty unless the deployment tool sets it, and empty means "read no feed". The home page in
production has no Latest Videos section until that setting names the channel.
