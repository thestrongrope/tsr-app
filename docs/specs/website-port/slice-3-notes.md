# Website port, slice 3: implementer's notes (18 Nov 2026)

Issue #66 (part of #38): `/tsr-publications`. Uncommitted on `feature/66-publications-page`. No plan exists: the test names are the test cases.

## What was built
- `domains/content/site/Publication.cs`: the route's shape (copied from `api.yaml`, `V1Publication`) and the page's rules:
  `Publications.Groups` (language trimmed, "Other" when none, English first then by name, each group by title), the count
  words, the dash for a missing size or date, and direction, alignment and `lang` for right-to-left text.
- `domains/content/site/PublicationsPage.razor`: the markup and classes of `page.tsx` and `PublicationsTabs.tsx`. Every group
  is written. The tab list, the search box and each "more" button carry the `hidden` attribute; summaries are written whole.
- `ContentSite.PagesAsync` reads `/api/v1/publications` once and adds `/tsr-publications/` (title and description of the
  present page's front matter). The build stops on a failed answer, a publication without a title, with neither address, or
  with an address that is not site-relative (one leading `/`) or http(s).
- `hosts/site/wwwroot/site.js` (+75 lines, same single function): shows the hidden controls, shows the active tab's group only,
  hides the cards whose `data-search-text` does not contain what was typed, rewrites the count line, cuts a summary to two
  lines and toggles it. Loaded outside a browser it only exports `matchesSearch` and `countLabel`.
- `hosts/site/tests/js/site.test.js` (Node's runner, no package; command in `docs/testing.md`). `MenuPanel.razor`: the menu
  link is now `/tsr-publications/`. `site.css` regenerated (167 lines added). `domains/content/CLAUDE.md`: one row.

## Decisions I had to make (assumptions to confirm)
1. **The search reads the title only** (`data-search-text` is the title), as the present site does. The issue says "text";
   adding the summary is one attribute's change.
2. **Sort order**: .NET's invariant culture stands in for the browser's `localeCompare`. Equal for letters and case
   ("Apple, mango, zebra"); not compared against the present site title by title for punctuation or Hindi and Urdu titles.
3. **Scripts off**: the controls that would do nothing are hidden and summaries are whole. With scripts on the page is as the
   present site's. This uses the `hidden` attribute, not the class, so the kept class lists are untouched.
4. **A tab's two looks** are in the tab list's `data-*-class` attributes; the script copies them (`StylesheetTests` reads them too).
5. **Right to left (R36)**: by the script of the text, as an article's title (`text-right`, `direction: rtl`). The font comes
   from `lang="ur"` (the stylesheet's existing rule) only for an Urdu publication. `lang="ar"` was avoided: the stylesheet's
   `div:has([lang="ar"])` rule would turn every enclosing block. Other right-to-left languages (none today) keep the page font.
6. **Lower-casing for the search is in the script**, on both sides in one function, so .NET and the browser cannot disagree.
7. The missing-value dash is the present site's character (U+2014). Read Online addresses are written as sent (no closing
   slash). The canned answer and one existing test (`The_list_is_read_page_by_page_until_no_more`) gained the route and page.

## Tests, each watched failing first (19 failed against stubs; the Node file failed on load)
| Test | Covers |
|---|---|
| `TC_SITE_R30_01` to `_05` (9 cases) | grouping, order, sort; the page, counts, menu link; empty and singular; answers that stop the build |
| `TC_SITE_R31_01`, `_02` | title, summary, type, size, date, dash; Read, Download, Download PDF only, Read Online, addresses as sent |
| `TC_SITE_R32_01` | a tab and a panel per language with matching names, first tab chosen, both looks on the tab list |
| `TC_SITE_R33_01`; Node `TC-SITE-R33-02` to `-04` | the search box, each card's search text, a count line per panel; matching and the count words |
| `TC_SITE_R34_01` | summary whole, a hidden "more" after it, no two-line cut in the markup |
| `TC_SITE_R35_01` | in `<main>` only the tab list, the search box and the "more" buttons are hidden; 5 panels, 7 cards |
| `TC_SITE_R36_01`, `_02` (7 cases) | Urdu title and summary; direction by script, font by language |

## Checks, as run
| Check | Result |
|---|---|
| `dotnet build TsrApp.slnx` | 0 warnings, 0 errors |
| `dotnet test hosts/site/tests` | 472 passed, 0 failed (404 before: 21 new cases, 47 new stylesheet class cases) |
| `node --test hosts/site/tests/js/` | 3 passed, 0 failed |
| Fixed class lists against the two source files, by script | every source list is in the component; the tab's two looks by eye |

## Not done, or not checked
- **Untested, decided only by the script**: a click on a tab showing its group only (R32), typing hiding the cards (R33),
  "more" opening and closing (R34), the un-hiding at load. `setUpPublications` was never run (no browser, no DOM); only
  `node --check` passed. It needs one look in a browser.
- No site generated, no stack, no page opened; layout rests on equal classes. Not run: `hosts/api/tests`, `db/tests`, Hurl, `flutter analyze`.
- The PDFs and the Read Online pages are not on the static server (#59, out of scope): those links answer not-found.
- No capability document exists for the public site, so none was updated. `docs/status.md` untouched. Complexity flag: none.
