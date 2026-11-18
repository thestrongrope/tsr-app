# Website port, slice 2: implementer's notes (18 Nov 2026)

Issue #65 (part of #38): `/about` and `/donate`. Change document: it loses its value when the slice is merged and verified.
Uncommitted on `feature/65-about-donate`. No draft PR or plan exists yet, so the test names below are the test cases; nothing was written to GitHub.

## What was built

- `domains/content/site/AboutPage.razor`, `DonatePage.razor`: the markup, classes and text of the present website's
  `src/app/about/page.tsx` and `src/app/donate/page.tsx` (the brief said `app/...`; the files are under `src/app/`).
  Fixed text, no API call.
- `ContentSite.PagesAsync` adds `/about/` and `/donate/` (`FixedPages`), with the present pages' titles and descriptions.
- `hosts/site/wwwroot/images/donate-qr.jpeg`: a byte-for-byte copy of the present site's file (`cmp` equal).
- SITE-R22: `SitePage` has a new optional `Files` (site addresses of static files a page shows). `SiteBuilder.RequireFiles`
  stops the build, naming the file and the page, when one is not in the static folder. `Program.cs` calls it right after
  the pages are collected, before anything is rendered or written.
- `hosts/site/wwwroot/site.css` regenerated with `tools/site-css.sh` (Tailwind v4.3.5): 257 lines added, none removed.

## Decisions I had to make (assumptions to confirm)

1. **The file check is a seam in `shared/site`** (`SitePage.Files`), not a line in the host that knows about Donate: the domain
   says what its page needs, the host owns the files. One new optional field; nothing else uses it yet.
2. **The frame's links now end with a slash** (`/about/` in the menu, `/donate/` in the menu and the footer), as slice 1's
   decision 4 does for `/articles/`, so the server answers the page and not a redirect. `/about` and `/donate` without the
   slash still work: the stock nginx redirects a folder to its slash address (not tried on a running server, see below).
3. **The QR image is a plain `<img>`** with the present page's `src`, `alt`, `width`, `height` and classes. The present site
   serves it through the framework's image optimiser (resized copies, `srcset`); not reproduced.
4. **The tests do not repeat the bank values.** They assert the four labels in order, each followed by a non-empty value in
   its own row. That the values equal the present page's was checked once by script (below), not by a kept test.
5. One existing test changed: `The_list_is_read_page_by_page_until_no_more` listed content's pages exactly, so its
   expected list gained `/about/` and `/donate/`.

## Tests (`hosts/site/tests/AboutDonateTests.cs`), each watched failing first (9 failed, 337 passed)

| Test case | Covers |
|---|---|
| `TC_SITE_R20_01` | About: title, description, `h1`, both `h2`, the nine items, inside the frame |
| `TC_SITE_R20_02` | Donate: title, description, `h1`, `h2`, the two lines of text, inside the frame |
| `TC_SITE_R20_03` | both addresses are pages; the frame links to them with the closing slash |
| `TC_SITE_R21_01` | the QR image, then the heading, then four label and value rows |
| `TC_SITE_R22_01` | Donate names the image as a needed file; the generator ships it; the real pages pass the check |
| `TC_SITE_R22_02` | image missing: `SiteBuildException` naming the file and `/donate/` |
| `TC_SITE_R22_03` (3 cases) | a needed file that is not an address inside the static folder stops the build |

## Checks, as run

| Check | Result |
|---|---|
| `dotnet build TsrApp.slnx` | 0 warnings, 0 errors |
| `dotnet test hosts/site/tests` | 404 passed, 0 failed (337 before: 9 new, 58 new stylesheet class cases) |
| Source against component, by script: the class attributes in order and the visible text of `<main>` | About: 46 class lists equal, text equal. Donate: 24 class lists equal, text equal (bank values included) |
| `cmp` of the QR image with the present site's | identical |

## Not done, or not checked

- Not run: `hosts/api/tests`, `db/tests`, Hurl, `flutter analyze` (nothing they cover was changed); no docker, no stack. The site was not generated end to end and no page was opened in a browser: layout is checked by equal classes only.
- `/about` without the slash redirecting on the real server, and the image arriving in the Docker image
  (`hosts/site/Dockerfile` publishes `wwwroot/**`, as for the fonts), were read from the files, not tried.
- `tools/site-compare.cs` does not compare these two pages; not extended (out of scope).
- No capability document exists for the public site (as in slice 1), so none was updated. `docs/status.md` not touched.
