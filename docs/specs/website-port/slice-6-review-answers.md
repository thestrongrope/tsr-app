# Slice 6 (issue 74): answers to the two reviews

Work is uncommitted. Tests: `hosts/site/tests/js/self-reflection.test.js` (JS) and `hosts/site/tests/SelfReflectionTests.cs` (C#).
Each new test was seen to fail first (missing function, or no exception), then the fix was made.

| Id | Status | Test or reason |
|---|---|---|
| L1 | fixed | JS `TC-SITE-R65-02`, `R65-03`: `formAfterStorageEvent` gives the empty form for a removed or cleared key, the parsed form for a changed key, null for another key. The page listens for `storage` and for `pageshow` with `persisted` (re-read, refill, re-score). The listeners themselves are the DOM half and were not run (see M1) |
| L2 | fixed | C# `TC_SITE_R67_03` (`//host/x.js`, `/\host`, `https://`, `javascript:`, `/`, spaces, tab, backslash, empty, for both fields; message names page and field), `R67_04` (good forms). The rule moved to `shared/site/SitePaths.cs`; `ContentSite` uses it too |
| M1 | not fixed | As told: the owner runs the browser half |
| M2 | fixed | JS `TC-SITE-R64-06`, `R64-07`: words stay as stored until `chooseOption` changes that answer, then the page's words. The old `R64-04` and `R64-05` expectations changed (the written words are now the stored ones) |
| M3 | not fixed | As told: the "scores need scripts" line and the entry link stay English on `/ur` and `/gu`; the translations must be the owner's words |
| N1 | not fixed | As told: no change. The present site (tsr-web) sets no `autocomplete` attribute on these fields and has no `<form>`; this page is the same, so the browser's session restore behaves alike |
| m1 | not fixed | Words matching no current list are dropped on save. Neither site scores them; old Urdu words are rare |
| m2 | not fixed | One bad field still empties the form: the present site never wrote such a value, and a partial read is a behaviour change. The discard is now reported (m3) |
| m3 | fixed | JS `TC-SITE-R68-06`: `parseStored` and `loadForm` take `onDiscard(reason)`, called for bad JSON, a non-form, a wrong field or unreadable storage (not for nothing stored; the reason holds no answer). The page passes a `console.warn` |
| m4 | not fixed | Intended (decision 3 of the notes): reset removes the key, nothing is written on load |
| m5 | fixed | Dead `hasAttribute('aria-pressed')` removed. Behaviour-preserving, in the DOM half: no test can reach it |
| m6 | not fixed | The maxima are in two places (C# and JS); one source needs a markup hand-over, a larger change |
| m7 | fixed | `docs/testing.md` row now lists `self-reflection.js` and `SelfReflection.cs`; the notes line 3 no longer says "Uncommitted" |
| m8 | not fixed | `Math.min(s5, 3)` mirrors page.tsx and is harmless |
| unused `data-sr-tier-box` | not fixed | Harmless attribute; no test would show it |
