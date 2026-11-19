# Website port batch 1 (issues 65 to 68): independent quality review

Reviewer: QA sub-agent, 18 Nov 2026. Read-only. Diff `origin/develop...HEAD` (4 commits, 37 files). The present website's
code (`tsr-web/web/src`) was used as the source of truth. Rule followed where they conflict: the project's `CLAUDE.md` and
`domains/CLAUDE.md` (rule 9) over the generic checklist.

**Verdict: no serious findings; 5 moderate, 10 minor. The main gap is verification: the browser half of every interactive
requirement has never run, and no test would fail if it broke.**

## Checks run (this session)

| Command | Result |
|---|---|
| `dotnet build TsrApp.slnx` | Build succeeded, 0 warnings, 0 errors |
| `dotnet test hosts/site/tests` | 611 passed, 0 failed, 0 skipped |
| `node --test hosts/site/tests/js/` | 15 passed, 0 failed |
| `node --check hosts/site/wwwroot/site.js` | ok |
| Text of `<main>`, tags stripped: About and Donate against `app/about`, `app/donate` | identical |
| `class=` lists in order: About, Donate, Home (+ CategoryCard, SearchBar) | About and Donate equal; Home: only the differences listed below |
| Globalization invariant mode in csproj, props, compose, Dockerfiles | not set; `aspnet:11.0` (Debian) has ICU |
| Images in the image build | `Tsr.Host.Site.csproj` copies `wwwroot/**`; `.dockerignore` excludes none |
| CI | no `.github/workflows`: nothing runs these suites automatically |
Not checked: no browser, no stack, no generated site, no Stryker or ESLint (not set up).

## Spec verdict (per requirement; "breaks?" = would a test fail if the behaviour broke)

| Req | Verdict | Evidence | Breaks? |
|---|---|---|---|
| R20 | PASS | `TC_SITE_R20_01`, `_02`, `_03`; text diff above identical | yes |
| R21 | PASS | `TC_SITE_R21_01` (labels in order, value non-empty); values equal by my text diff | partly: a wrong bank value passes the test |
| R22 | PASS | `TC_SITE_R22_02`, `_03`; wiring `hosts/site/Program.cs:22` | partly: deleting the Program.cs call breaks no test |
| R30 | PASS | `TC_SITE_R30_01`, `_02`; `Publication.cs` `Groups` matches `page.tsx` grouping, English-first, localeCompare | yes, on this machine's ICU |
| R31 | PASS | `TC_SITE_R31_01`, `_02`; buttons match `PublicationsTabs.tsx` | yes |
| R32 | PASS by code only | `site.js` `setUpPublications` `show()`; markup pairing `TC_SITE_R32_01` | no (DOM never run) |
| R33 | PASS | Node `TC-SITE-R33-02..04` (match, trim, "No matches"); DOM loop by code | the rule yes; the wiring no |
| R34 | PASS by code only | `site.js` summary toggle; `TC_SITE_R34_01` markup only | no |
| R35 | PASS | `TC_SITE_R35_01` | yes |
| R36 | PASS | `TC_SITE_R36_01`, `_02` | yes |
| R40 | PASS | `TC_SITE_R40_01..09`; `matchesFilter` exact slug as `ArticlesList.tsx` | the rule yes; card hiding no |
| R41 | PASS | `TC_SITE_R41_01..08`; slugified-only match is equivalent to the three present rules (exact or lower-case equal implies slug equal) | the rule yes; wiring no |
| R42 | PASS | `TC_SITE_R42_01..06`; counts by own slug as `app/articles/page.tsx` | markup and states yes; toggles no |
| R43 | PASS | `TC_SITE_R43_01..04`; unknown filter: no card + nothing-found box, as the present code | yes (words); see note |
| R44 | PASS | `TC_SITE_R44_01` | weak: string scan for `fetch(`/`XMLHttpRequest` only |
| R50 | PASS | `TC_SITE_R50_01` (ordered markers), `_02.._07` | yes |
| R51 | PASS by code only | `site.js` `setUpHomeCategories`; scripts-off lists `TC_SITE_R51_01`, `_02` | open/close no |
| R52 | PASS | `TC_SITE_R52_01`; `HomePage.razor:102` GET form, `name="q"` | yes |
| R53 | PASS | `TC_SITE_R53_01` | yes |
| R54 | PASS | `TC_SITE_R54_01`, `_02` | yes |

Note on R43: the issue text says an unknown filter "SHALL show the whole list" and also "with the nothing-found behaviour";
the code follows the present site (no card, the box). The issue's wording should be fixed, not the code.
Scope creep: none beyond the slices; the removed sample home page and `NavTitle` are required by R54.

## Findings

### Serious
None.

### Moderate
1. **Interactive behaviour never executed** (`site.js:130-305`). R32, R34, R51 and the DOM half of R33, R40 to R42 rest on
   code reading; Node tests cover only the pure functions, C# tests only the markup. Breaking `show()`, the summary toggle,
   card hiding or the card toggles leaves all 626 tests green. Stated in slice 3, 4, 5 notes; still the largest risk.
2. **Program.cs wiring of R22 is untested** (`hosts/site/Program.cs:22`). Remove the `RequireFiles` line: every test passes
   and a missing QR image or photo ships as a broken image.
3. **Article counts computed twice** (`ArticleFilters.cs:73-85` vs `ContentSite.MenuAsync` using the API's `articleCount`).
   `api.yaml` defines `articleCount` as "published articles filed under this slug itself", the same number. Rule 9 of
   `domains/CLAUDE.md` (render what the API returns) is review-only; two sources for one fact can drift.
4. **Rules and text in the browser script, duplicated at build time.** `site.js:22` repeats the default description that
   `ArticleIndexPage.razor:11` writes; `headingFor` (tag wins), `noMatchText`, `countLabel` hold present-site wording; `slugify`
   exists in C# and JS, kept equal only by mirrored test cases (`TC_SITE_R41_02` / `TC-SITE-R41-04`). No test ties the two
   copies of the description. Slugifying the typed query at runtime is unavoidable; the wording could come from data.
5. **One odd video stops the whole site build** (`Home.cs:75-78`; `ContentSite.ReadVideosAsync`). The present site hides the
   section on failure. Input: one feed entry with an id outside `[A-Za-z0-9_-]{1,32}` or an http thumbnail. The old pages stay
   up (Program writes only a finished site), so no reader sees a broken page, but no new article is published until the feed
   changes. Stated only in slice-5 notes (decision 7), not in the issue or code comment beyond the method summary.

### Minor
6. `HomePage.razor:76` writes the badge row only when a category title is known; `page.tsx` always writes the
   `flex ... mb-2` row. Input: a latest article whose first category is unknown: its title sits 0.5rem higher. Unstated.
7. Home search box (`HomePage.razor:102-111`): no clear button and no trim; `SearchBar.tsx` trims and drops an empty `q`.
   Input: Enter on an empty box goes to `/articles/?q=`. Unstated (R52 is still met).
8. `?q=` does not collapse the filter panel (`site.js` `filtered` ignores `q`); `CategoryFilter.tsx` collapses on a search.
   Out of scope until the search slice; unstated.
9. `site.js` runs publications, home cards, article filters, then the menu in one function: an exception in any earlier part
   stops the menu wiring. Input: a category slug containing `"` or `\` makes `site.js:264` `querySelector` throw. Category
   slugs are not validated at build time (article slugs are, `ContentSite.Folder`).
10. The `/status/` page is no longer linked from any page: the sample home page was its only link. Unstated.
11. Stale comments: `site.test.js:1` "The two functions" (nine are exported); `ArticleFilters.cs:14` "the script only
    compares strings and shows or hides" (it also slugifies and words headings); `ContentSite.cs:7-11` summary omits the home
    page and the video route; `site.js:2-3` names only the publications page as handing over class lists (the article list does too).
12. Weakened bar, justified by R54: `SiteModuleBoundaryTests` relaxed `Any(p => p.Path != "/")` to `Is.Not.Empty` and dropped
    the nav assertion (the `NavTitle` field is gone). `SiteBuildTests` swapped `HomePage` for `NotFoundPage`. No skips, no
    suppressions, no empty catches added.
13. `TC_SITE_R44_01` would miss `import(`, `sendBeacon` or an injected `<script src>`; acceptable for now.
14. Publications sort (`Publication.cs:31-35`): invariant ICU order stands in for `localeCompare`; equal for Latin letters and
    case, not compared on real Urdu or Hindi titles (stated, slice-3 decision 2).
15. The tab's two class lists exist twice in `PublicationsPage.razor` (`data-*-class` and the `@code` constants); a change to
    one copy alone gives a different look before and after the first click.

### Differences stated only in slice notes (not in an issue or a code comment)
Home: no "New" badge (also in a code comment); a failed video route stops the build (5 above); unreadable dates hidden.
Article list: no "Go to Admin Panel" link; `animate-in` classes dropped; titles entity-decoded (present shows them raw).
Publications: build stops on a publication without a title or a link (present: "Untitled publication" or dropped).
Links end in `/` everywhere (`/articles/`, `/about/`, `/donate/`, `/tsr-publications/`).

## Standards verdict
- Build, site tests and Node tests pass (numbers above). Weakened-bar scan: only item 12.
- Review-only on this stack, checked by eye: domains rule 9 (items 3, 4); MUST 10 dead code (none found: every new
  member and export is used); MUST 2 bounded work (lists come from bounded API reads; fine); comments matching code (item 11);
  `hosts/` holds only wiring (`SiteBuilder.RequireFiles` is a generic file check, fine).
- Not run: `hosts/api/tests`, `db/tests`, Hurl, `flutter analyze` (nothing they cover changed). No browser check: needed
  before merge for items 1 and 9.
