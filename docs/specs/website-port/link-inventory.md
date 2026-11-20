# Link inventory: what the old website answers and the new site does not

Measured 20 Nov 2026 against `https://thestrongrope.com` (the old website, tsr-web `main` `0093ac3`) and
`https://web.thestrongrope.com` (the new static site, release 0.5.0). Read-only requests. Three sources:

1. Every address the old website is known to answer: its routes, its 35 fixed pages, its redirect rules and its public files (89 addresses).
2. Every internal link the new site writes: all 510 pages crawled, 565 distinct internal addresses requested.
3. Every link to the old website inside the new site's pages (article text): 11 distinct addresses.

## Summary

| Group | Count | Needs | State |
|---|---|---|---|
| Fixed pages (`/<slug>`, `/pages`) | 31 of 35 page files, plus `/pages` | a pages route in the API | spec and plan drafted, waits for the owner's decisions |
| Lectures (`/lectures`) | 1 | lecture data and a route | built (issue 88), not released |
| Old addresses that redirect (WordPress links, old article addresses) | 11 rules | server configuration only | built, self test passes, not committed |
| Public files (`.well-known`, `duas`, dark icons, uploads) | 15 files | copy into the site | built, not committed |
| Redirects to the member app (`/join/<code>`, `/mcq/<code>`) | 2 rules | the member app's address in the site server | open: owner's decision |
| Public API routes (search, lecture search, events) | 3 | API work | search is issue 22; the others have no issue |
| Not ported on purpose | 8 | nothing | see the last section |

Works on both today (17 of the 89): Home, About, Articles, an article, Donate, Publications, Self-reflection (entry and three languages), `favicon.ico`, `icon.png`, `tsr-logo.png`, the donate image and three uploads.

## 1. Dead links the new site itself writes (12)

| Address | Pages that link it | Where | Group |
|---|---|---|---|
| `/accreditation` (and its three anchors) | 510 | the menu or footer; the three endorsement cards on Home | fixed page |
| `/privacy-policy` | 510 | the footer | fixed page |
| `/lectures` | 510 | the menu | lectures (built, issue 88) |
| `/a-gift-for-the-youth`, `/behaar-al-anwaar-preface`, `/excellence-of-holy-quran-toc`, `/fragrance-of-mastership`, `/gardens-of-scholars`, `/salaah-a-mode-of-divine-proximity-and-recognition`, `/the-city-of-miracles` | 1 each | "Read online" on Publications | fixed pages |
| `/duas/dua-atawajjahu.html`, `/duas/dua-faakshif.html` | 1 each | Publications | public files (built) |

The other 553 internal addresses answer 200, the 33 publication files among them.

## 2. Fixed pages (the old website's `content/pages`, 35 files)

Answer 200 on the old website and 404 on the new one (31):
`a-gift-for-the-youth`, `accreditation`, `announcement`, `behaar-al-anwaar-preface`, `bibliography`,
`essay-writing-competition-for-tsr-students`, `excellence-of-holy-quran-preface`, `excellence-of-holy-quran-toc`,
the 14 chapters `excellence-of-holy-quran-chapter-one` to `-fourteen`, `fragrance-of-mastership`, `gardens-of-scholars`,
`privacy-policy`, `salaah-a-mode-of-divine-proximity-and-recognition`, `the-city-of-miracles`, `the-strong-rope`, `v2`,
and the list `/pages`. `home` answers 200 on the old website (the redirect work sends `/home` to `/`).

Redirect on the old website, so they are not pages to port (4): `account`, `my-account`, `register`, `registration`.

One page file is ported already: `tsr-publications`.

## 3. Old addresses that redirect

| Old address | Old website sends it to | New site today | After the redirect work |
|---|---|---|---|
| `/tag/<slug>` | `/articles?tag=<slug>` | 404 | 301 `/articles/?tag=<slug>` |
| `/category/<slug>` | `/articles?category=<slug>` | 404 | 301 `/articles/?category=<slug>` |
| `/YYYY/MM/DD/<slug>`, `/YYYY/MM/<slug>` | `/articles/<slug>` | 404 | 301 `/articles/<slug>/` |
| `/<article slug>` (no `/articles/` in front) | `/articles/<slug>` | 404 | 301 when the article exists, else the 404 page |
| `/feed`, `/feed/<type>` | `/articles` | 404 | 302 `/articles/` |
| `/author/<slug>`, `/page/<n>` | `/articles` | 404 | 301 `/articles/` |
| `/articles/importance-reality-awaiting-intezaar-imam-mahdi` | the "virtue" article | 404 | 301 to it |
| `/join/<code>`, `/mcq/<code>` | the member app (`account.`) | 404 | **not built**: needs that address in the server's configuration |
| an address without its trailing slash | (no such rule) | 301 to `http://...`, then back to `https://` | one relative 301 |

Ten of the 11 links to the old website inside article text are of these kinds (9 old article addresses, 1 category);
the eleventh is the fixed page `/fragrance-of-mastership/` (linked by 26 articles).

## 4. Public files

| File | New site today | After the public-files work |
|---|---|---|
| `/.well-known/apple-app-site-association`, `/.well-known/assetlinks.json` (the phones' link check; they matter when the domain moves) | 404 | served; the first as JSON |
| `/duas/dua-atawajjahu.html`, `/duas/dua-faakshif.html` | 404 | served |
| `/favicon-dark.ico`, `/icon-dark.png`, `/tsr-logo-dark.png` | 404 | served |
| 8 files in `/uploads/` (11 addresses were dead; 3 were already present under the same names) | 404 | served |

## 5. Public API routes (old website's API against the new API)

| Route | Old | New | The app calls it |
|---|---|---|---|
| `/api/v1/articles`, `/api/v1/taxonomies/categories`, `/taxonomies/tags`, `/publications`, `/youtube` | 200 | 200 | yes |
| `/api/v1/search` | 200 | 404 | yes (issue 22) |
| `/api/v1/lectures/search` | 200 | 404 | yes |
| `/api/v1/events` (POST) | 405 on GET | 404 | not found in the app's code |

The app's other `/api/v1/taxonomies/categories/...` call was not traced to a route here.

## 6. Not ported on purpose

`/admin` and `/config.yml` (the old content editor), `/docs` and `/api/docs` (the old API's documentation),
`/api/articles` (an older API), `/search-index.json` (the old search's index; search is issue 22), and the sample images
`file.svg`, `globe.svg`, `next.svg`, `window.svg`.

## How this was measured

- Old addresses: the route files, `next.config.ts` redirects and `public/` of tsr-web `main`; each requested on both sites.
- The new site's links: every `href` and `src` of the 510 pages, the internal ones requested once each.
- Not covered: links inside the PDFs; addresses search engines hold that match no rule above; the old website's query strings.
