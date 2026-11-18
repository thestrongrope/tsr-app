# Slice 6 (Self-reflection, issue 74): security and privacy review

Reviewer: independent security review, 18 Nov 2026, of `git diff origin/develop...HEAD` (commit b996401) in the
`self-reflection` worktree. Read-only. Rules followed: root `CLAUDE.md` (rules 1, 6; public repo), `domains/CLAUDE.md`.
Issue 75 (the "not saved anywhere" sentence) is known and not re-reported.

## Verdict

No critical, high or medium finding. Two low, one needs_validation. Nothing in the change sends the reader's answers off the device.

## Findings

### L1 (low, confirmed): a reset can be undone by another copy of the page that still holds the answers
- Where: `hosts/site/wwwroot/self-reflection.js:378-386` (`onReset`), `:191-198` (`saveForm` writes the whole in-memory form),
  `:391-394` (listeners: no `storage` event, no `pageshow` handler).
- Trigger (same reader, shared device). Confirmed path: the form is open in two tabs and the reader resets in one. Likely path
  (depends on the browser restoring the page from its back-forward cache): the reader goes /en -> /ur, resets on /ur, presses Back.
- What happens: the other tab, or the /en page restored from the back-forward cache, still has every answer in `form` and in its
  text fields, so the answers show on screen again; the next click or keystroke there writes the full set back to `localStorage`
  under `tsr-self-reflection`. The reader believes the device is clean; it is not.
- Why not stopped: the script reads storage once at load (`:238`) and never again; nothing reacts to another page's `removeItem`.
- Impact cap: local only (same browser profile); nothing leaves the device. Makes the issue-75 exposure worse after a reset.

### L2 (low, confirmed as a gap; not exploitable today): neither `SitePage.Script` nor `SitePage.RefreshTo` is held to a same-origin path
- Where: `shared/site/SitePage.cs` (both new fields); `hosts/site/Layout.razor:15-18` (refresh) and `:40-42` (script);
  `hosts/site/SiteBuilder.cs:163-171` (`RequireFiles`).
- `Script`: `RequireFiles` needs a leading `/`, a path inside `wwwroot` and an existing file. A value `//other.host/x.js` passes the
  shape check (`TrimStart('/')` gives `other.host/x.js`, inside the root) and is stopped only because no such file exists in
  `wwwroot`; a browser reads `<script src="//other.host/x.js">` as protocol-relative and loads it from another host.
- `RefreshTo`: no check at all. `https://other.host/` or `//other.host/` would make an instant off-site redirect from a trusted page.
- Not exploitable today: both values are code constants (`domains/content/site/SelfReflection.cs:75,154,156`); content files and the
  API cannot set them. Both are HTML-attribute encoded, so no attribute break-out.
- Gap: one rule for both, "starts with `/` and not `//`", would make the guarantee explicit rather than depend on a file being absent.

### N1 (needs_validation): the browser's own session-restore copy of typed text
- `SelfReflectionPage.razor:124,180,186,199,297`: text fields and textareas have no `autocomplete="off"`. There is no `<form>` and no
  submit, so form-autofill history should not record them; but Firefox and Chrome session restore may keep unsaved field text of
  open tabs on disk. Unproven link: whether the `fillFields()` overwrite at load and after reset updates that copy. Browser
  behaviour, not this code; listed so the issue-75 wording can account for it.

## Threats checked and found handled (rejected)

1. Answers leaving the device: `self-reflection.js` has no `fetch`, XHR, `sendBeacon`, `location`, `history`, `cookie`,
   `sessionStorage` or `document.title` use (grep, exit 1). The page has no `<form>`; every button is `type="button"`. The page
   loads only `/site.css`, `/site.js`, `/self-reflection.js`, `/tsr-logo.png` and local icons: a grep of every frame and content
   `.razor` for `http`, `src=` and `//` found no outside resource on the frame or this page; `site.input.css` gained only two
   `@source` lines; `wwwroot/site.css` has no `@import` and no outside `url(`. Links carry only
   fixed paths, so a referrer carries `/self-reflection/xx/` and never an answer. `console.error` messages hold no answer.
2. Stored data as input: `parseStored` (`:124-160`) rejects non-JSON, non-objects, wrong types and wrong lengths as a whole
   (empty form); `section5Choice` must be an integer 0-5; traits must be one of three words; section-2 words become positions by
   `indexOf` against build-time lists, so a stored string is never shown. Stored text reaches the DOM only as `field.value`
   (`:325`). Numbers reach it only via `textContent` and `style.width` from computed scores. No selector is built from a stored
   value (`showOnly` builds from constant selectors). `__proto__`/`constructor` keys: only named properties are read from the
   parsed object, and the form object is freshly built, so no pollution. Very large values: bounded by the browser's storage quota.
3. The reader's typing: goes only to `form[name]` (name from a page-written attribute) and back out as `.value`; never `innerHTML`.
4. `SitePage.Script` path traversal: `../` and absolute values fail the build (the `GetFullPath` + `StartsWith(root)` check holds,
   and it only tests existence). Encoding: `WebUtility.HtmlEncode` (`Layout.razor:40-42`). The `//` case is L2.
5. Copied text (`domains/content/site/self-reflection.json`): no `<`, `>`, URL, `@`, `javascript` or long digit run (grep, no
   match). Every string is written with Razor `@`, which encodes; `{bold}` is split in C# and the parts encoded
   (`SelfReflectionPage.razor:48-49`). `data-options-all` is JSON in an encoded attribute. A grep of every added line of the diff (code, tests,
   notes; `site.css` aside) for emails, `http(s)://`, `/Users/`, `C:\\`, digit runs of 9+ and the owner's name found only a test's
   `Does.Not.Contain("http://")`: no personal data and no local path committed.
6. Reset: removes the one key, replaces `form`, refills every field and re-renders (`:378-386`); no other storage key, global or
   DOM copy in this page (beyond L1's other pages).

## Checks run (this worktree, 18 Nov 2026)

| Check | Result |
|---|---|
| `dotnet build TsrApp.slnx` | 0 warnings, 0 errors |
| `dotnet test hosts/site/tests` | 755 passed, 0 failed |
| `node --test hosts/site/tests/js/` | 41 passed, 0 failed |
| `gitleaks git --log-opts=origin/develop..HEAD` | 1 commit scanned, 0 findings (JSON `[]`) |
| `semgrep --metrics=off` (p/javascript, p/csharp, p/secrets) on all 8 changed .js/.cs/.razor code and test files | 2 findings, both `unsafe-path-combine` at `SiteBuilder.cs:134,183`: outside the diff, constant file names: rejected. 1 parse error (the .razor file is not a supported language) |

## Not checked

- The DOM part of the script never ran in a browser here (no browser, no stack, by brief); L1 is from reading the code.
- Response headers (CSP, Referrer-Policy) of the nginx server: not in this diff.
- osv-scanner: no package changed in this diff.
