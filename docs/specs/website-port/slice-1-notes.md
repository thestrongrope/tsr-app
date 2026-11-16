# Website port, slice 1: implementer's notes (16 Nov 2026)

Issue #38, plan in draft PR #58. Change document: it loses its value when the slice is merged and verified.

## Finding first: what the API returns for an article's body

`GET /api/v1/articles/{slug}` returns the body as **HTML**, in `data.content`. The API renders it from the Markdown
at refresh time (`domains/content/api/domain/ArticleHtml.cs`): plain CommonMark with no extension, raw HTML dropped, and
a link or image address whose scheme is not `http`, `https` or `mailto` emptied. The Markdown itself (`rawContent`) is
not sent (LIB-D3).

The present website's article page does NOT use that HTML. It renders the Markdown itself (`MarkdownRenderer.tsx`:
`react-markdown` with `remark-gfm` and `rehype-raw`, after six text replacements on the Markdown).

So the site cannot "render Markdown the way the website does": it has no Markdown. `domains/content/site/ArticleBody.cs`
reads the API's HTML strictly and writes it again with the classes and rules of `MarkdownRenderer.tsx`. Markdig is not
used by the site.

### What is reproduced
Classes of `p`, `h1` to `h3`, `ul`, `ol`, `li`, `blockquote`, `pre`, `code` (inline against block), `hr`, `strong`,
`em`, `a` (an address starting `http` opens in a new tab), `img` (floated frame with its caption); `arabic-text` and
`arabic-mixed` on paragraphs by the same character ranges and the same "more than half" rule; removal of the text's
own "Reading Time: N minutes" line.

### What cannot be reproduced from the API's HTML (decision needed)
**Since changed:** the table, footnote and bare address rows below are reproduced now; see "Footnotes, tables and bare links" at the end.

Counted over the present site's 501 published article files (counts only, no text read into this repo):

| Feature of the present site's rendering | Published articles using it | On the generated page |
|---|---|---|
| GitHub-flavoured table | 1 | the table's source lines as a paragraph |
| Footnotes (`[^1]`), with the hover text and the "Footnotes" section | 9 or 10 | the markers as plain text |
| Raw HTML in the Markdown (`<p ...>`) | 1 | dropped by the API |
| Bare address made a link | 39 | the address as plain text (same text, no link) |
| Joining of broken reference lines (six replacements on the Markdown) | not counted | mostly white space only; one replacement can merge two paragraphs |
| Strikethrough, images | 0 | - |

Ways to close it, none taken here: the API renders with the GFM extensions and sends that HTML (changes what the app
receives too), or the API sends the Markdown to the site (LIB-D3 reversed), or these few articles are accepted as
different and listed in `tools/site-compare.allow`.

Also different by source: the reading time in the page header is the API's `readingTime` (words of the Markdown, 200 a
minute). The website's page computes its own after stripping Markdown characters, so a figure can differ by one near
a boundary. The website shows 4 related articles ordered by score only; the site shows the first 4 of the API's 5
(score, then newest, then slug), so ties can differ.

## Blocked: the comparison on real content (verification 2) was NOT run

Lane 5 already existed when I started: containers `tsr-app-test-5-*`, created 14 Nov from the main checkout
(`/Users/asifshakir/Projects/tsr-app`), workers `search-feed` with its own Elasticsearch, synthetic content. It is not
mine. `up` on it would rebuild it from this worktree and replace its content and workers, and the `remove` I was told
to finish with would delete its database. I did not touch it (one read-only GET, and its containers' settings and log, to see what it was). It served no
request but mine in the six hours before. Needed: either a word that lane 5 may be taken over, or another lane number.

What was run instead:
- The site generated from the default test stack (:8089, 12 synthetic articles): 15 pages, every body accepted by
  `ArticleBody` (the fixture includes a table, raw HTML, a script-scheme link and a right-to-left article).
- `tools/site-compare.cs` end to end against https://thestrongrope.com with `--max 3`, three times (9 requests in
  all, one a second): it read the present site's `/articles` and `/search-index.json` (501 articles, the same number
  as the published files). For `/articles` the **title, the heading and the intro line were equal**. Everything else
  differed as it must, the generated side being synthetic (12 `list-extra`, 501 `list-missing`, 1 `status` 404).
  So the counts asked for (compared, equal, different on real articles) do not exist yet.

To run it once a lane is free (n = the lane):
```
TSR_STACK=n TSR_LANE_WORKERS=content-refresh TSR_CONTENT_SRC=$HOME/Projects/tsr-web/web/content tools/test-stack.sh up
TSR_STACK=n tools/contract-website.sh test --prepare        # waits for the worker; check the count is 501, not 12
TSR_BASE_URL=http://localhost:810n dotnet run --project hosts/site -- build/site-n
dotnet run tools/site-compare.cs -- build/site-n https://thestrongrope.com
TSR_STACK=n tools/test-stack.sh remove
```
The generator's 5 minute limit and 10 second timeout have not been tried on 501 article reads.

## A mistake to know about

Once, I ran `dotnet run --project hosts/site` without `TSR_BASE_URL`. Its default is the dev stack (:8088), so the
generator sent read-only GETs to the dev stack's public routes (`/health`, the public Library routes). It wrote
nothing there, ran no seed, reset or contract script, and no output folder was created on this side (the run failed).
Those routes carry published website content only, never member data. `docs/testing.md` now says to always set
`TSR_BASE_URL`. The default itself is unchanged (not in this slice); changing it to the test stack would remove the trap.

## Decisions I had to make (assumptions to confirm)

1. **Percent-encoded slugs.** The synthetic content has one and the real content has 4 (of 501). The generator
   stopped on them ("not a safe path"), so no site could be built at all. Now: the page is written under the decoded
   slug (the server decodes the address a browser sends), links keep the slug as written, and the decoded name must be
   letters, marks and digits joined by `-`, or the build stops. The present website answers 404 for these four
   addresses (LIB-D7), so here the static site serves 4 pages the present one does not. The alternative is to leave
   them out.
2. **The list's order and source.** The present `/articles` page holds no article in the HTML it serves: the browser
   draws the list from `/search-index.json`. The generated list is in the page, newest first as the API sends it, and
   the comparison checks it against that index file.
3. **Titles and excerpts** are decoded once (HTML entities) and escaped once. The present list puts them in the page as
   raw HTML; a title holding real markup would show as text here.
4. **Links** carry a trailing slash (`/articles/`, `/articles/{slug}/`) so the server does not redirect. Category and
   tag links point at `/articles/?category=` and `?tag=`, which show the whole list until the filters are built. The
   menu's and footer's links to pages not ported yet (`/lectures`, `/about`, `/donate`, `/privacy-policy` ...) answer
   the not-found page.
5. **Menu.** As the website: every category without a parent, each with the children that hold an article. Counts are
   read at build time and used only for that (the website's menu shows no number either).
6. **Theme icons.** Both icons are in the page and the stylesheet picks one (`hidden dark:block`, `dark:hidden`): the
   only classes that are not the website's own, with the `hidden` and `translate` classes site.js toggles.
7. **Not-found page.** The website has none of its own (the framework's "404 | This page could not be found." in the
   frame). `404.html` says the same in the frame, with a link home.
8. **`SitePage.Title`** is now the whole `<title>`; `SitePage.Description` and `MenuCategory` are new in `shared/site`.
   The list's title is "The Strong Rope", as on the website (its list page sets none).
9. **Empty list.** The website's text for it offers the Admin Panel; the static page says "No articles found" only.
10. **Fonts.** next/font also makes a size-adjusted fallback face per family to soften the swap; not reproduced.
11. `og:` tags and the canonical link of the article page are not written (not title or main text).

## Fonts: exact sources (16 Nov 2026)

Stylesheets asked from `https://fonts.googleapis.com/css2?family=<F>&display=swap` with a desktop Chrome User-Agent and
no other header of mine, for `Inter:wght@300;400;500;600;700;800;900`, `Amiri:wght@400;700`,
`Noto+Naskh+Arabic:wght@400;500;600;700`, `Noto+Nastaliq+Urdu:wght@400;500;600;700`, `Gulzar`. Only the subsets
`layout.tsx` names were kept. Inter and the two Noto families are variable fonts: one file serves every weight.

| File in `hosts/site/wwwroot/fonts/` | Source |
|---|---|
| `inter-latin.woff2` | https://fonts.gstatic.com/s/inter/v20/UcC73FwrK3iLTeHuS_nVMrMxCp50SjIa1ZL7W0Q5nw.woff2 |
| `amiri-400-arabic.woff2` | https://fonts.gstatic.com/s/amiri/v30/J7aRnpd8CGxBHpUrtLMS7JNKIjk.woff2 |
| `amiri-400-latin.woff2` | https://fonts.gstatic.com/s/amiri/v30/J7aRnpd8CGxBHpUutLMS7JNK.woff2 |
| `amiri-700-arabic.woff2` | https://fonts.gstatic.com/s/amiri/v30/J7acnpd8CGxBHp2VkaY6zp5gGDAbnCA.woff2 |
| `amiri-700-latin.woff2` | https://fonts.gstatic.com/s/amiri/v30/J7acnpd8CGxBHp2VkaY_zp5gGDAb.woff2 |
| `noto-naskh-arabic-arabic.woff2` | https://fonts.gstatic.com/s/notonaskharabic/v44/RrQKbpV-9Dd1b1OAGA6M9PkyDuVBeN2DHV2mLXgzTrc.woff2 |
| `noto-nastaliq-urdu-arabic.woff2` | https://fonts.gstatic.com/s/notonastaliqurdu/v23/LhW4MUPbN-oZdNFcBy1-DJYsEoTq5pu3SvoMGdX1OW12.woff2 |
| `gulzar-400-arabic.woff2` | https://fonts.gstatic.com/s/gulzar/v14/Wnz6HAc9eB3HB2I7YzYYiAzcPDKo.woff2 |
| `OFL-<family>.txt` (5) | https://raw.githubusercontent.com/google/fonts/main/ofl/<family>/OFL.txt for `inter`, `amiri`, `notonaskharabic`, `notonastaliqurdu`, `gulzar` |

The logo and icons (`tsr-logo.png`, `icon.png`, `favicon.ico`) are copies of the present site's `web/public/` files.

## Verification, as run

| Check | Result |
|---|---|
| TC-SITE-R11-01 `StylesheetTests` | failed first with an empty `site.css` (every class), then again when two `@source` lines missed `domains/content/site` (37 classes named); passes after `tools/site-css.sh` |
| TC-SITE-R11-02 side by side | not done: I cannot take screenshots |
| TC-SITE-R10-01 comparison | tool written and exercised; NOT run on matching content (above) |
| TC-SITE-R13-01 theme kept | not demonstrated (needs a browser); the snippet and the key are the website's, checked by `Article_text_is_escaped_and_the_only_scripts_are_the_frame_s_two` |
| TC-SITE-R15-01 not found | `docker build -f hosts/site/Dockerfile.server --target selftest hosts/site` passed: nginx inside the build answered 404 with the stand-in `404.html`. Text half: `ProductionStackTests.The_site_server_answers_an_unknown_address_with_the_site_s_own_page`. The generator's page: `The_not_found_page_is_written_as_404_html_in_the_site_s_frame`. Not tried on a running production stack |
| TC-SITE-R16-01 no draft | the site reads only routes that hold published articles (LIB-R12, tested in `db/tests`); from :8089 it wrote 12 article pages for 12 published, 2 drafts absent. No new test of its own |
| TC-SITE-R17-01 | `ProductionStackTests.The_site_tells_search_engines_not_to_crawl_it` passes, unchanged |
| `dotnet build TsrApp.slnx` | 0 warnings, 0 errors |
| `dotnet test hosts/site/tests` | 293 passed, 0 failed |
| `dotnet test hosts/api/tests` | 117 passed, 0 failed (one test added, none changed) |
| `docker build -f hosts/site/Dockerfile .` | built; `/app/wwwroot` holds the stylesheet, the script, 8 fonts, 5 licences |
| `docker build -f hosts/site/Dockerfile.server hosts/site` | built |

Not run: `db/tests`, the Hurl files, `flutter analyze` (nothing they cover was changed).

`ProductionStackTests`: no existing test was changed. `docker-compose.yml`'s `site` now has `build:` (context
`hosts/site`, `Dockerfile.server`) instead of `image:`, and mounts only the pages.

Tests changed in `hosts/site/tests`, and why: `Article_text_is_escaped_and_the_page_has_no_script` became
`..._the_only_scripts_are_the_frame_s_two` (the frame now has the two scripts the plan decides); the fake API answers
the `/api/v1/` routes instead of the stub `/articles`; `RenderAsync` takes the menu instead of the nav list.

## After the implementer: the comparison, the reviews and the fixes (16 Nov 2026)

Lane 5 was rebuilt from this worktree with the present website's published content (501 articles); it is still up.

| Check | Result |
|---|---|
| Site generated from lane 5 | 504 pages in about 6 seconds |
| `tools/site-compare.cs` against https://thestrongrope.com, 59 pages | list: 501 on each side, same titles and order. Pages: 45 equal, 14 different (12 main-text, 2 status); the same after the fixes below |
| Side by side in a browser (article page at 1280 and 375 wide, the list, dark theme, the menu) | header, footer, fonts, spacing and colours match; the dark theme is kept across pages; the menu lists the categories. Screenshots were looked at, not saved |

The 14 differences, by cause (none allowed yet; the owner decides, issue 38):
- 11 main-text: the present site adds a comma after a page reference at a line end (one of its six text replacements). The Markdown has none; the generated page shows the source.
- 1 main-text: a footnote marker shown as written (see "What cannot be reproduced" above).
- 2 status: a percent-encoded slug answers 404 on the present site and 200 here.

Found by real content, fixed test first: a slug whose decoded text holds an Arabic comma stopped the build
(`A_slug_whose_characters_include_punctuation_of_another_script_is_still_a_page`).

Fixed after the independent quality and security reviews, each test first:
- The site is now written to a folder of its own and put in place only when finished (`SiteBuilder.Replace`, `robots.txt` first),
  so a failed render or the time limit never leaves a partial site.
- `TSR_BASE_URL` unset now reads the default test stack (:8089), never the dev stack.
- A body nested deeper than 64 elements stops the build; the reading-time pattern has a 2 second limit.
- `domains/content/CLAUDE.md` no longer says the site reads the stub.

Not fixed, listed for a later change: two slugs that differ only by case or by encoding can overwrite each other on a Mac
(Linux is unaffected); the server image is not pinned to a digest and sends no security headers; `site-build` runs as root;
related excerpts are not entity-decoded; the three logo images carry no licence note; `site.js` has no test of its own.

## Left open

- The stub `GET /articles` and `content.articles` are no longer read by the site; `domains/content/CLAUDE.md` still
  calls the stub "the example of a domain with site pages". Removing the stub is a separate change.
- `hosts/site/Program.cs` still defaults to the dev stack when `TSR_BASE_URL` is unset.
- The PR's task boxes are not ticked: I was told not to write to GitHub.
- No capability document exists for the public site; none was written.

## Footnotes, tables and bare links (16 Nov 2026, after the first comparison)

Decided by the owner: the API renders footnotes, pipe tables and bare web addresses (LIB-D18 in
`domains/content/capabilities/library-reads.md`), and the site shows them in the present website's markup
(`domains/content/site/ArticleBody.cs`). The refresh hash covers the stored HTML, so the next refresh after a deploy
renders every stored article again. Two comparison differences were allowed in `tools/site-compare.allow`
(the comma after a page reference, the percent-encoded slug).

| Check | Result |
|---|---|
| `dotnet build TsrApp.slnx` | 0 warnings, 0 errors |
| `dotnet test hosts/site/tests` | 337 passed |
| `dotnet test hosts/api/tests` | 117 passed |
| `dotnet test db/tests` | 1362 passed |
| Hurl, `TSR_STACK=6 tools/contract-website.sh test` on a new lane with the synthetic content (`v1-article.hurl` case 2 changed) | 6 files, 97 requests, 0 failed |
| Lane 5 rebuilt from this worktree | the refresh rendered the 501 stored articles again: 9 hold footnotes, 1 a table |
| Site generated from lane 5 | 504 pages; no body stopped the build |
| `tools/site-compare.cs` against https://thestrongrope.com, 59 pages | list 501 on each side; 46 equal, 13 allowed (11 reference-comma, 2 status), 0 not allowed. The footnote difference of the first run is gone |
| The hover text and a table in a browser; the app on the new HTML | not looked at |

Fixed after the independent quality and security reviews, each test first:
- A note's text is written at each of its references, so a page could grow to hundreds of megabytes: what is written has the
  same 2,000,000 character bound as what is read (`A_body_that_its_hover_texts_grow_past_the_bound_stops_the_build`).
- A footnote number is ASCII digits only (`A_footnote_number_in_digits_of_another_script_stops_the_build`).
- The notes are read once for a body, not once for each reference (24,000 references took 13.8 seconds). No test: timing only.

Not fixed, for a later change:
- A bare `ftp:` or `tel:` address becomes a link with an empty address, not plain text; a bare `mailto:` address is linked.
- The hover text is empty for a note that starts with a list, code or raw HTML; a note that no text refers to leaves an
  empty "Footnotes" section; a note that refers to another shows that note's number in its hover text.
- Older than this change: a form feed or another control character in an article stops the whole site build, and so does
  the reading-time pattern's 2 second limit (`hosts/site/Program.cs` does not catch it).
- `site.css` holds `.container` and `.table`, which no markup uses.
