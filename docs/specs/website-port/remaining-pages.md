# Website port: the pages still missing, sized (18 Nov 2026)

Issue #38. Read-only recon of the present website (`tsr-web/web`, Next.js) against the static site on the slice-1
branch. Change document: it loses its value once the slices are planned. Decisions in `slice-1-notes.md` are taken as given.

Sizes: **S** = under a day of agent work, **M** = one to three days, **L** = more, or blocked on a decision or another issue.
Line counts are the present site's TypeScript (page + components), most of it markup.

## Summary

| # | Page | Address | Data today | Buildable from the six routes | Script needed | Size |
|---|---|---|---|---|---|---|
| 1 | About | `/about` | text in the page's code | yes (no data at all) | none | S |
| 2 | Donate | `/donate` | text in the code, one QR image | yes, plus one image file | none | S |
| 3 | Publications | `/tsr-publications` | front matter of `pages/tsr-publications.md` | yes (`/api/v1/publications`); the PDFs are a separate question | tabs, search box, "more" (about 80 lines plain) | S to M |
| 4 | Article list filters | `/articles?category=`, `?tag=` | `search-index.json` in the browser | yes (the cards are already in the page) | filter + filter panel (about 150 lines plain) | M |
| 5 | Home | `/` | articles, categories, YouTube feed, 3 images | yes, plus 3 image files | category card open/close; search box is a plain form | M |
| 6 | Fixed pages | `/{slug}` (30), `/pages` | `content/pages/*.md` (35 files) | **no**: a pages route is missing | none | M |
| 7 | Self-reflection | `/self-reflection/{en,ur,gu}` | text in the code (`translations.ts`) | yes (no API data) | form, scores, localStorage (about 250 lines plain) | M |
| 8 | Article search | box on `/articles` and `/` | Elasticsearch through `/api/v1/search`, Fuse.js fallback | **no**: decision + #22 | fetch, debounce, result cards with highlights | L |
| 9 | Lectures | `/lectures` | Elasticsearch through `/api/v1/lectures/search` | **no**: no lecture data or route in this repo | search, language filter, load more, chapters | L |

## Per page

### 1. About (`/about`), S
1. A heading and two cards of fixed prose ("who we are" style). `app/about/page.tsx`, 122 lines, no import but `Metadata`. No content file, no API, no third party. No email, phone or link found in it (checked by count, not read in full).
2. Buildable now: one Razor component with the text. Which module owns it is the only choice (the host, like the home page, or `content`).
3. No script.
4. S: copy of markup; the stylesheet test will name any new class and `tools/site-css.sh` adds it.
5. The text lives in code on the present site, so it will live in a `.razor` file here: an edit is a deploy. Not a risk, but it is not "content".

### 2. Donate (`/donate`), S
1. A heading, a QR image (`public/images/donate-qr.jpeg`) and a "Bank Transfer Details" card with four labelled values (account name, account number, bank code, branch). 65 lines, all fixed in code.
2. Buildable now. Needs the QR image copied into `hosts/site/wwwroot/images/`.
3. No script.
4. S.
5. **The page publishes bank account details and a payment QR code.** They are the organisation's and already public, but they would enter a public git repository as text and as an image. The owner should confirm that, and that the details are current, before the copy. I did not record the values here.

### 3. Publications (`/tsr-publications`), S to M
1. Publications grouped by language into tabs (the tab order and the per-tab sort by title are computed in the page), each with title, summary (two lines, "more" opens it), type, size, updated date, and buttons: Download, Read (the PDF in a new tab; hidden when `downloadOnly`), Read Online (9 entries link to a fixed page such as `/a-gift-for-the-youth`). Data: the `publications:` list in the front matter of `content/pages/tsr-publications.md`. `/{slug}` deliberately answers 404 for this slug.
2. The list: yes, `/api/v1/publications` sends every field the page uses. I did not confirm whether the page also shows the file's Markdown body; `MarkdownRenderer` is imported but I found no call with the page content. **The files are not solved:** `public/downloads` is 196 MB, 36 PDFs (`tsr-publications/` 34 MB, `books/` 163 MB). LIB-D10 in `library-reads.md` says PDFs stay outside the repository; issue #59 is said to decide they go in. The two disagree in the repo today. Until one is settled the buttons point at files the static server does not have.
3. `PublicationsTabs.tsx`, 302 lines: active tab, a search box filtering the active tab by text, expand/collapse of the summary. All three are plain DOM work: render every group, hide all but the active one, filter by a `data-` text attribute. About 80 lines.
4. S for page and script; M if it includes bringing the files and checking 36 links.
5. Read Online links point at fixed pages (slice 6), so they are dead until then. Some titles and summaries are Hindi, Urdu and Gujarati: needs the right-to-left and font handling the article page already has. Copyright of the book PDFs was not looked at.

### 4. Article list filters (`/articles?category=`, `?tag=`), M
1. A collapsible filter panel (parent categories, each opening to subcategories with counts), a heading that names the current category or tag, and the cards filtered. The present page downloads `/search-index.json` (1.9 MB, every article with its full Markdown) and filters in the browser: category = slug in the article's list; tag = exact, case-insensitive or slugified match. No paging: all matching cards are shown.
2. Buildable now. The generated list already holds all 501 cards; each needs `data-categories` and `data-tags` (the list route sends both; **not confirmed** that `ArticleSummary` in `domains/content/site/Article.cs` already reads tags). No index file is needed for filtering. Old addresses `/category/{slug}` and `/tag/{slug}` redirect to these query addresses on the present site (`next.config.ts`); that is #39.
3. `ArticlesList.tsx` 393 + `CategoryFilter.tsx` 190 lines. Plain script: read `location.search`, hide cards, set the heading, mark the active filter, open/close the panel. About 150 lines. Category counts can be written at build time.
4. M: the script is small, but SITE-R12 wants "the same results", so it needs a test that runs the filter on real content against the present site's list (the comparison tool does not run scripts today), and `site.js` has no test harness yet.
5. Without script the page shows the whole list (acceptable). One 501-card page is about as heavy as today's index download, but check its size. The tag match has three rules; the slugified one must be copied exactly or `?tag=` links from article pages will differ.

### 5. Home (`/`), M
1. In order: a verse banner (Arabic + English, fixed text); three endorsement cards with photos linking to `/accreditation#...`; "Latest Articles" (5 newest, with first category); a search box that sends the reader to `/articles?q=`; a grid of parent category cards with counts, each opening to its subcategories; a link to `/lectures`; "Latest Videos" (6, thumbnail, title, link to YouTube) from the channel's public RSS feed, fetched server-side and refreshed hourly. `app/page.tsx` 364 lines, `CategoryCard.tsx` 100.
2. Buildable from articles (limit 5), categories and `/api/v1/youtube` (limit 6). Needs three images from `public/uploads/` (2.8 MB folder; only the three are needed here).
3. Category card open/close: about 20 lines, the same pattern as the menu's categories in `site.js`. The search box is a plain `<form method="get" action="/articles/">` with no script; it does nothing useful until slice 8.
4. M: long markup, four data sources, and the host currently owns `HomePage.razor` while the data is `content`'s. Either the home page moves into `domains/content/site/`, or the host gets a way to ask a domain for "latest articles" (a new seam). Decide before building.
5. (a) **Videos are frozen at build time**; today they refresh hourly. A build with the feed down gives no video section (the route sends an empty list, never an error), and every test stack sends an empty list, so the section cannot be compared on a lane. A small script reading `/api/v1/youtube` in the browser would keep it fresh but makes the public page depend on the API being reachable from browsers. (b) Thumbnails are hot-linked from `i.ytimg.com`: a third-party request from every reader. (c) The three photos are of named people and an organisation's seal; no licence note exists (same gap already listed for the logos). (d) The cards link to `/accreditation` (slice 6) and `/lectures` (slice 9).

### 6. Fixed pages (`/{slug}`, `/pages`), M, blocked on a route
1. `/{slug}`: title, the Markdown body through the same `MarkdownRenderer` as articles, and for book chapters a previous / contents / next bar (`prevPage`, `nextPage`, and `parent` minus `-preface` plus `-toc`). `/pages`: three groups (book, resource, about) of published pages without a parent, by `order`. Data: `content/pages/*.md`, 35 files, 472 KB; the largest is 121 KB. `[slug]/page.tsx` 150 lines, `pages/page.tsx` 122.
   - 30 addresses answer: every file except `tsr-publications` (404) and four retired slugs (301 to `/`).
   - `/{slug}` does **not** check `status` (10 files have none, the privacy policy among them); only `/pages` does.
   - An unknown `/{slug}` that is an article's slug redirects 301 to `/articles/{slug}`. That is #39, but the static server needs the rule.
2. **Not buildable:** no route sends pages. Needs: a `pages` table filled by the content refresh, a public route (list + one page, HTML rendered as for articles), and the content source (#59). `ArticleBody.cs` can be reused for the body, which argues for keeping pages in `content`.
3. No script.
4. M: route + migration + refresh + Hurl + two site components. The site half alone is S.
5. (a) **The accreditation page is raw HTML** (`<style>`, 7 `<div>`, 4 `<img>`): the API's renderer drops raw HTML, so this one page needs its own answer (a hand-made component, or an allowed exception). The home page links to its anchors. (b) 18 pages use footnotes and 1 a table: covered since LIB-D18. (c) The site is not allowed to read the content folder directly (it reads the API only), so "content files in this repo" alone does not unblock it. (d) The privacy policy is one of these files and the app stores point at it (#39): it could be done first as a single hand-made page if the stores need it early. (e) `home.md`, `v2.md`, `announcement.md` and others have no status and still answer today; the owner may want to drop some rather than port them.

### 7. Self-reflection (`/self-reflection`, `/self-reflection/{lang}`), M
1. `/self-reflection` redirects to `/self-reflection/en`. One long form in English, Urdu (right to left) and Gujarati: five sections (yes/no checks, option buttons, free-text reflections, trait ratings, a chosen step with a plan), a covenant text box, a live score per section and in total, the score range that applies, and the weakest section named. `[lang]/page.tsx` 682 lines, `translations.ts` 393. No API, no content file, no third party.
2. Buildable now: three static pages from one Razor component and one translations table (C# or a JSON file read at build time). Gujarati needs a font check: slice 1 shipped Latin, Arabic and Urdu faces only, and I did not check what the present site uses for Gujarati (probably the system font).
3. The script keeps about 15 values, computes four scores (rules below), and saves the whole form to `localStorage` under `tsr-self-reflection` on every change, with a reset button. Plain script can do it: `data-` attributes on inputs, one `recalc()` on change. About 250 lines. The scoring compares the chosen option to a position in the option list, so the script should score by index, not by translated text.
4. M: two of the three languages cannot be checked by eye by most reviewers, the score rules need unit tests (the repo has no JavaScript test runner yet: a decision), and SITE-R14 is "Demonstration".
5. (a) **The page tells the reader "Your answers are not saved anywhere", yet it stores every answer, including free-text confessions, in the browser's `localStorage`** with no expiry, shared across the three languages. Nothing leaves the device, but on a shared computer the next person sees it. Port as it is and raise it, or fix the wording: an owner decision, and a behaviour change if fixed. (b) The redirect from `/self-reflection` needs a server rule or a meta-refresh page. (c) The page fixes its own language and direction on `<main>`, not on `<html>`.

### 8. Article search (box on `/articles` and `/`), L, blocked
1. Typing sets `?q=`; after 300 ms the browser calls the website's own `/api/v1/search` (limit 50, optional category). That route asks **Elasticsearch** (weighted title, excerpt, content and tags, fuzzy, with highlights) and falls back to Fuse.js over all article text (threshold 0.4). It is rate-limited and logs each search; a click on a result posts to `/api/v1/events` (analytics, also in Elasticsearch). The page shows "Found N results using {engine} search", highlights and a relevance score.
2. **Not buildable to SITE-R12.** The new API's `q` on `/api/v1/articles` matches title, excerpt or a tag only: different results. Three ways, none decided: (a) wait for the search route of #22 and call it from the browser; (b) build an index file at site-build time and search in the browser (the API does not send article text to build it from, and the present index is 1.9 MB); (c) accept the simpler `q` and change the requirement. With (a) the public static page depends on the API at reading time, which no page does so far.
3. About 150 lines of plain script for the fetch, debounce and result cards, on top of slice 4's script.
4. L: blocked on #22 or a decision; "same results" against a ranking engine cannot be met exactly by any other engine, so the requirement itself needs a tolerance.
5. Search and click analytics exist today; dropping or keeping them is a decision (they record queries, no personal data seen in the payload: surface, query, slug, rank). Google Analytics is loaded on every page of the present site (`layout.tsx`); the static frame has none. Not in any issue I read.

### 9. Lectures (`/lectures`), L, blocked
1. A search box, a language filter (All, English, Urdu/Hindi, Arabic), cards (YouTube thumbnail, title, excerpt, duration, date, matched chapters with timestamps linking into the video, a "chapters" toggle), 24 at a time with "load more". An empty query browses newest first. Everything comes from `/api/v1/lectures/search`, which reads an Elasticsearch index (two-stage strict then fuzzy match; an optional embedding layer, off by default). `LecturesList.tsx` 317 lines, `lectures-search-service.ts` 514.
2. **Not buildable.** No lecture table, route or data in this repo. The source is `content/lectures/lectures.ndjson`: 917 lectures, 22.7 MB, because each record carries the full transcript and a 384-number embedding. A browse-only page (newest first, language filter, chapters) could be generated from a new plain list route with no search engine; search needs #22.
3. With a list route: about 120 lines for the language filter, load more and the chapters toggle. Search adds the same script as slice 8.
4. L: a new table + refresh + route, the data question (#59: 22.7 MB of transcripts in git, or a trimmed file of about 2 to 3 MB without transcript and embedding, my estimate), then search.
5. Transcripts are machine-made text of talks by named speakers: public, but check before it enters a public repository. Thumbnails hot-link `i.ytimg.com`. The file's date (10 Oct) is newer than the search index file beside it: I did not check how the file is produced or how often.

## Things that cut across slices

- **Images and files.** The static server has only `hosts/site/wwwroot`. Needed from the present site's `public/`: `uploads/` (2.8 MB; 4 references from articles and pages, 3 from the home page), `images/` (the QR), `downloads/` (196 MB, 2 references from Markdown plus every publication), `duas/` (two stand-alone HTML pages, linked from nowhere I searched, not in the issue's table). Where they live is #59's question and blocks 3 (files) and part of 5 and 6.
- **Script tests.** Slices 3, 4, 5 and 7 add script; `site.js` has no test today. One decision (a browser test, or a Node test runner in the repo) serves all four. Cheaper to take it at the first of them.
- **Redirects** (`next.config.ts`: `/tag/*`, `/category/*`, dated WordPress addresses, `/feed`; the code: retired slugs, article slug at the root, `/self-reflection`): #39, but slices 4, 6 and 7 each create the target.
- **Dead links in the frame** end as slices land: `/about`, `/donate` (1, 2), `/lectures` (9), `/privacy-policy` (6).
- `/docs` (API reference) and `/admin` (CMS) are out of scope by the issue.

## Recommended order

| Slice | Pages | Size | Blockers |
|---|---|---|---|
| 2 | About, Donate | S | owner confirms the bank details and QR may be in the public repo |
| 3 | Article list filters (category, tag); decide the script test here | M | none |
| 4 | Home (search box present, plain form) | M | where the home page lives (host or `content`); three photos' licence; videos frozen at build: accept or not |
| 5 | Publications: page, tabs, search | S | none for the page; the PDFs wait for #59 against LIB-D10 |
| 6 | Self-reflection, three languages | M | none technical; the "not saved anywhere" wording; a Gujarati reader for the demonstration |
| 7 | Fixed pages and `/pages` (new pages route) | M | content source (#59); the raw-HTML accreditation page |
| 8 | Article search | L | #22, or a decision to build an index or relax SITE-R12 |
| 9 | Lectures: browse first, then search | L | lecture data in this repo (#59), a list route, then #22 |

Why this order: 2 to 6 need no new API work and remove most dead links early; 3 before 4 because the home page's search box and category cards link to the filtered list; 6 can move anywhere, it depends on nothing. 7 is the first that needs API work and is the one the stores care about (privacy policy). 8 and 9 share the search decision and should be planned together.

## Where I am unsure or did not read

- Not read in full: `about/page.tsx` and `donate/page.tsx` text, `CategoryFilter.tsx`, `CategoryCard.tsx`, `PublicationsTabs.tsx`, `LecturesList.tsx`, the self-reflection page's markup (outlines and greps only). Plain-script line counts are estimates.
- Not checked: whether the publications page shows a Markdown intro; whether the site's `ArticleSummary` already carries tags; what font Gujarati uses today; the copyright of the PDFs and photos; how `lectures.ndjson` is produced.
- Issues 39, 22 and 59 were read for title and problem statement only. The statement that #59 puts the PDFs in the repo comes from the session's notes, not from the issue text I read.
- No page was opened in a browser, nothing was run, and no stack was touched.
