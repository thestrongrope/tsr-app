# Batch 1 (issues 65 to 68): security review

Reviewed: `git diff origin/develop...HEAD` in the `site-batch` worktree (commits 1e78eab, 79f7b4f, 3ccc935, 04529cb), without the
generated `site.css`. Read-only; nothing was changed. Rules followed: root `CLAUDE.md` (rules 1, 5 and 6) and `CODING-GUIDELINES.md`.

**Verdict: no critical, high or medium findings. 3 low and 3 informational findings.** Everything the API sends reaches the
page through Razor's HTML encoding or `textContent`. The two addresses that come from outside are checked when the site is built.

## Checks run

| Check | Result |
|---|---|
| `dotnet build TsrApp.slnx` | 0 warnings, 0 errors |
| `dotnet test hosts/site/tests` | 611 passed, 0 failed, 0 skipped |
| `node --test hosts/site/tests/js/` | 15 passed, 0 failed |
| gitleaks over the 4 commits | no leaks found |
| semgrep `p/default` on the changed .cs and .js files | 2 results, both rejected (see below); 1 parse error on a file semgrep could not read |
| Security gate script | none in this repo (no `scripts/security-check.sh`, and no security gate in `docs/testing.md`) |
| osv-scanner | not run: the change adds no package |
| Image metadata (`mdls`, `strings`) | no GPS, author, creator or camera fields. One PNG has the XMP comment "Screenshot". The JPEG has an empty Photoshop/EXIF block |

## Findings

### L1 (low, confirmed): a publication address can leave the site through `/\` or a tab
- Sink: `domains/content/site/PublicationsPage.razor:91, 101, 107, 116` (`href="@publication.File"` and `@publication.ReadOnlineUrl`).
- Check: `domains/content/site/ContentSite.cs` `IsAddress` (the diff's lines 276 to 280) accepts any value that starts with `/` but not `//`.
- Input: a `file` or `readOnlineUrl` of the form `/\host/...` or `/<TAB>/host/...` in the publications answer.
- What happens: the WHATWG URL parser reads `\` as `/` in http(s) addresses and drops tabs and newlines. Such a value becomes a
  link to another host, even though the check is meant to allow only site-relative or http(s) addresses. Script execution
  is not possible: `javascript:` and the other schemes are rejected.
- Who can trigger it: whoever writes the publication content files (editors). That is the same trust as an http(s) link,
  which is already allowed, so the impact is a check that does not hold, not a new capability.
- Why it is not stopped: the check tests only the first two characters. Fix class: reject `\` and ASCII control or whitespace
  characters in the value, or parse with `Uri` and compare the host.

### L2 (low, needs_validation): category slugs are not validated, and the script builds a selector from them
- Sinks: `hosts/site/wwwroot/site.js` (diff line 777) `'[data-subcategories="' + slug + '"]'`. The slug is read from a
  `data-subcategory-toggle` attribute written at build time. Also the unencoded query value in
  `href="/articles/?category=@card.Slug"` (`HomePage.razor:125, 156`, `ArticleIndexPage.razor` at the parent and child links).
- Input: a category slug containing `"`, `]`, `&` or `#`. `ReadCategoriesAsync` checks only that the slug is not null.
  Article slugs go through `Folder()`, but category slugs do not.
- What happens: `querySelector` throws a SyntaxError. The rest of `setUpArticleFilters` stops, and so does the menu setup that
  runs after it in the same script, so the menu is dead on `/articles/`. A slug with `&` or `#` makes a link that filters
  on the wrong value. This cannot lead to XSS: the attribute is HTML-encoded and the value is never parsed as HTML.
- Unproven link: whether the content API can emit such a slug. Its slugs are probably restricted, but that was not checked
  in this review. Fix class: check category slugs against the article-slug pattern at build time, or use `CSS.escape`
  and `Uri.EscapeDataString`.

### L3 (low, confirmed): a video thumbnail may name any https host
- `domains/content/site/Home.cs` (`Videos`) requires only `https://`. `HomePage.razor:213` writes it as `<img src>`.
- Input: a thumbnail URL in `/api/v1/youtube` that points to a host other than YouTube's image host. The feed is an outside
  source that the API passes on.
- What happens: every visitor's browser fetches an image from that host (it can track visitors; no script runs). The video
  id is limited to `^[A-Za-z0-9_-]{1,32}$` and the title must be present. Both are handled.
- Fix class: allow only `https://i.ytimg.com/` (or build the thumbnail address from the checked video id).

### I1 (info): unbounded response sizes
`/api/v1/publications` and the category list are read whole, with no limit on count or size. The limits are the per-request
`HttpClient.Timeout` of 10 s and the build's 5-minute `CancellationTokenSource` (`hosts/site/Program.cs:15-16`). Videos are
cut to 6, and the article list is capped by `MaxListPages`. A huge answer can make the build slow or use a lot of memory.
It cannot publish a broken site: the site is written to a staging folder and swapped in only when finished. The reader
(`SiteApi`) existed before this change.

### I2 (info): malformed answers that are not `SiteBuildException`
A duplicate category slug makes `ToDictionary` throw `ArgumentException` (`ArticleFilters.DataJson`, `Home.Latest`,
`ContentSite.PagesAsync`). Bad JSON throws `JsonException`. `Program.cs:31` catches only `SiteBuildException`,
`HttpRequestException` and `TaskCanceledException`, so these errors end with an unhandled stack trace instead of a clear
message. No page is published in either case.

### I3 (info): `UnsafeRelaxedJsonEscaping` in `ArticleFilters.Json`
The filter data is safe today: it goes into a `data-article-filters` attribute, and Razor HTML-encodes it, so `"`, `<` and
`&` cannot break out. If this JSON is ever moved into a `<script>` block, a category title containing `</script>` would
break out. Use the default encoder if that ever happens.

## Threats checked and handled (rejected)
- Text from the API (titles, summaries, tags, category names and descriptions, publication fields, video title, description,
  date and views) is always written through Razor `@`, which HTML-encodes it. There is no `MarkupString` and no raw HTML in
  the new pages.
- Attributes: `data-*`, `class`, `style` and `lang` are encoded. The values of `style`, `class` and `lang` are fixed strings
  chosen in C# (`Publications.Direction`, `RightAligned`, `Lang`), never data.
- The `href` and `src` of articles: article slugs go through `Folder()`. The video link uses the checked id. The QR image and
  the photos are constants.
- `site.js` and the address: `location.search` is read with `URLSearchParams` and reaches only `textContent`,
  `createTextNode` and string comparisons. Nothing goes to `innerHTML`, `eval`, `href` or a selector. The class names
  come from `data-*-class`, and the state value is one of a fixed set. Lookups use `hasOwnProperty`, so `?category=__proto__`
  cannot reach the prototype. Both regexes (`[^a-z0-9]+` and `(^-|-$)`) run in linear time, in JS and in C#.
- `RequireFiles` (`hosts/site/SiteBuilder.cs`): it requires a leading `/`, then compares the `GetFullPath` result with the
  static root as a prefix. That blocks `..` and rooted paths, and the names it checks are compile-time constants.
- The two semgrep hits `unsafe-path-combine` (`SiteBuilder.cs:101` robots.txt and `:150` 404.html) predate this change
  and combine constant file names.
- Secrets and PII: gitleaks is clean. The Donate page carries only the bank details and QR image the owner approved (values
  not repeated here). No phone number, personal email, token or member data was found in code, tests, notes or the fixtures
  (`*.invalid` and `AAAAAAAAAAA` placeholders). The slice notes give only counts of real articles, not their content.
- Images: no location, author or device metadata.

## Third parties
New in this change: video thumbnails from the host named in the feed (in practice `i.ytimg.com`, see L3), and outbound links
to `www.youtube.com` (`rel="noopener noreferrer"`, `target="_blank"`). The change adds no third-party script and no new font
host. The font requests described in the slice-1 notes predate this batch.

## Not checked
- The content API's own validation of category slugs and publication addresses (L2, L1).
- The repo has no security gate script, so none was run.
- No browser test of the `/\` behaviour; the conclusion rests on the WHATWG URL specification.
- One file semgrep could not parse (1 error reported).
