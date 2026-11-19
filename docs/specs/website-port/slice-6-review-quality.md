# Slice 6 (issue #74, Self-reflection): independent quality review

Reviewed 18 Nov 2026, `feature/74-self-reflection` at b996401 against `origin/develop`. This was a read-only review. It did not
read `hosts/site/wwwroot/site.css`, apart from its `[hidden]` rule. The source of truth is tsr-web
`web/src/app/self-reflection/[lang]/page.tsx` and `translations.ts`.

**Verdict:** PASS with findings. No serious finding: no input gives a different score, range or weakest section, and the stored
shape matches. The DOM half of the script has no test at all (finding M1).

## Checks run
| Command | Result |
|---|---|
| `dotnet build TsrApp.slnx` | 0 warnings, 0 errors (incremental) |
| `dotnet test hosts/site/tests` | 755 passed, 0 failed |
| `node --test hosts/site/tests/js/` | 41 passed, 0 failed |
| In-memory mutants on `self-reflection.js` (file not touched; module swapped in `require.cache`) | 8 scoring and storage mutants killed: Q3 any-choice, Q4 position, `choice < 5`, range `>= 11`, `readList` validation, cross-language lookup, `Math.round`, the 0.5 for inconsistent. 4 survived: removing the click listener, removing the first `fillFields(); refresh();`, removing the `data-sr-needs-script` reveal, and dropping `Math.min(s5, 3)` (an equivalent mutant: s5 is at most 3) |
| `site.js` and the stylesheet on these pages | `site.js` has no fetch, XMLHttpRequest, sendBeacon or Image; every font `url()` is local `/fonts/...` |
Not checked: there is no JS type check, linter or complexity tool in the repo, so MUST 1 and MUST 5 on the JS were checked by eye only. No page was opened in a browser.

## The scoring, worked out from page.tsx first
- S1 (max 6): items 0 to 2 score 1 for `true`; items 3 to 5 score 1 for `false`.
- S2 (max 5): Q0 = option 1, Q1 = option 1, Q2 = any non-null, Q3 = option 0, Q4 = option 0. page.tsx compares the stored
  **words** with the current language's options.
- S4 (max 5): strong 1, inconsistent 0.5.
- S5 (max 3): 1 for a choice, where choice 5 needs `other.trim()` to be non-empty; then 2 for `plan.trim().length > 30`, or 1 for a plan longer than 0; then `min(…, 3)`.
- Total out of 19 and `toFixed(1)`. Ranges: `>=15`, `[11,15)`, `[6,11)` and `<6`.
- Weakest section: `reduce`, strict `<` on score/max over the order [S1, S2, S4, S5]. A tie keeps the earlier section. Progress is `round(total/19*100)`.

`self-reflection.js:32-82` gives the same formula, comparison operators and order. I ran it under Node with my own inputs:
- Ties 3/6 against 2.5/5 → S1; 2/6 against 1/3 → S1; 4/6 against 2/3 → S1; all full → S1; all zero → S1.
- Ranges at 14.5, 15, 10.5, 11, 5.5 and 6 give 1, 0, 2, 1, 3 and 2.
- Plan 30 characters scores 1; 31 characters with surrounding spaces scores 2; Other with blank text scores 0; Other with `"a"` scores 1.
All match page.tsx. Totals are multiples of 0.5, so the float division in the tie test matches exactly.

**The only differences are in S2, by design (R63 and R64).** An answer stored in another language's words:
- Present site: 0 for Q0, Q1, Q3 and Q4 (+1 for Q2).
- New page: the answer is mapped to its position and scored.

The other difference is words that match no current list (a minor finding, m1).

## The stored data
Present site: key `tsr-self-reflection`. The value is JSON with these fields:
- `section1Checks` (6 x bool|null) and `section1Reflection`
- `section2Choices` (5 x the option's words in the page's language, or null) and `section2Reflection`
- `section3Answers` (4 x string)
- `section4Traits` (5 x 'weak'|'inconsistent'|'strong'|null) and `section4Reflection`
- `section5Choice` (0 to 5 or null), `section5Other` and `section5Plan`
- `covenant` and `lastUpdated` (ISO)

The present site writes this on load and on every change. After a reset its save effect writes the empty form back.

`git log -p` shows that the key and every array length are the same in all four tsr-web commits. Only the Urdu S2 words changed, in 9570a41.

The new page reads this shape (`parseStored`, :124) and writes the same keys in the same order (`toStored`, :163). Test TC-SITE-R64-04 checks this.

Which stored values have which effect:
- Do not parse, are not an object, or any one field has the wrong type or length (for example `section3Answers` of length 3, or `section5Choice` 6 or "2"): the **whole** form starts empty and nothing is logged. The first change then overwrites the stored answers.
- Words in S2 that are not in a current list: dropped to null.
- Nothing throws: `loadForm` catches errors, and TC-SITE-R68-01 to 05 cover this.

## Requirements
| Req | Verdict | Evidence | Would the test fail if broken? |
|---|---|---|---|
| R60 | PASS | TC_SITE_R60_01 to 04 (`SelfReflectionTests.cs:91-166`). The notes say the JSON was proven equal to translations.ts by a one-off script | Yes for a missing or changed string. No for strings in the wrong order or place: the test only checks `Contains` per string |
| R61 | PASS | TC_SITE_R61_01 and 02. The `[lang="ur"]` rule (Gulzar, rtl, line-height 2.4) is word for word the same as tsr-web globals.css | Yes |
| R62 | PASS on the rules; the display rests on code reading only | JS R62-01 to 10. Display: `showScores` :296 | Rules: yes (mutants killed). Display: no. The live update was never run (M1) |
| R63 | PASS | JS R63-01, C# TC_SITE_R63_01, `sectionScores` :43-47 compares positions | Yes |
| R64 | PASS on the pure functions; the page wiring rests on code reading only | JS R64-01 to 05, C# R64-01 to 05 | Load and save: yes. Fill and listen: no (the `fillFields` and click mutants survived) |
| R65 | PASS on `clearForm`; the button rests on code reading only | JS R65-01, C# R65-01; `onReset` :378 | `clearForm`: yes. The button and the reset of fields: no |
| R66 | PASS | C# R66-01 and JS R66-01 search for request APIs. `site.js` and the fonts were checked by hand (above) | Yes, for the named APIs in `self-reflection.js` only. Not for `site.js` or the frame |
| R67 | PASS | TC_SITE_R67_01 and 02 | Yes. The meta refresh was not tried in a browser |
| R68 | PASS | JS R68-01 to 05 | Yes |
| R69 | PASS, but the line is English on every page | TC_SITE_R69_01 | Yes, for the noscript text and for no field being hidden. Not for the reveal (mutant survived) |
Scope creep: `SitePage.Script` and `RefreshTo` in shared/site. Both are small and are needed by R66 and R67. Nothing else.

## Script against markup
I traced every `data-sr-*` selector in the script against `SelfReflectionPage.razor`:
- `check`/`value`, `option`/`position`, `trait`/`level`, `step`, `row`, `radio`, `dot`, `badge`/`badge-value`, `total`, `percent`, `bar`, `range`, `tier`, `weakest`, `weakest-score`, `focus`, `field`/`index`, `reset` and `needs-script` are all written.
- Every element passed to `setOn` carries both `data-on-class` and `data-off-class`, so `getAttribute(...).split` never meets null.
- `showOnly`'s `selector.slice(1,-1)` gives the attribute name.
- The `[hidden]` rule is `display:none !important`, so it beats `inline-flex` on the badges.
- The JSON of `data-options-all` is HTML-encoded and `getAttribute` decodes it.
Nothing found would throw. Unused: `data-sr-tier-box` (:247) and `data-sr-section` (used by tests only).

## Findings
**Serious:** none.

**Moderate**
- M1. `self-reflection.js:228-394`: no test runs the DOM half. Removing the click listener, the first fill, or the reveal leaves all 41 JS tests and 755 C# tests green. So the "WHEN a reader answers…" parts of R62, R64, R65 and R69 rest on code reading only. The notes file (`slice-6-notes.md`) says so too. A jsdom test or a browser walk is the missing check.
- M2. `toStored` :167 writes S2 in the words of the page's language. Suppose a reader answered in English on the present site, then changed anything on the new `/ur` page. Back on the present English page, all of S2 then shows unselected and scores 0 for Q0, Q1, Q3 and Q4. The words are not lost: they stay stored, and the new page still reads them. This is decision 1 in the notes, but neither the issue nor a code comment states this effect on the present site. Keeping each answer's original words would avoid it.
- M3. `SelfReflectionPage.razor:36` and `SelfReflectionEntryPage.razor:5`: the noscript line and the entry link are new English text, on `/ur` and `/gu` too. R60 asks for every instruction in the page's language. The notes say "my English", but the issue does not.

**Minor**
- m1. `positionOf` :114 maps words that match no current list to null. The case seen in tsr-web history is the Urdu words before 28 Jan 2026 (`الفاظ`, `دیکھا جائے`, `اکیلے`, `مقصد`, `توجہ ہٹانے`). Neither site scores these words today, so there is no difference in score. The new page drops them on its next save, where the present site keeps them. Q2's "any non-null" does not apply, because Q2's words never changed.
- m2. `parseStored` :149: one bad field empties the whole form, and the next save overwrites it. page.tsx keeps every field it can read. The present site never wrote such a value (the shape is stable in its history), so this is not reachable from real data.
- m3. `loadForm` :185 and `parseStored` :128-131 drop unreadable storage silently; page.tsx at least calls `console.error`. This conflicts with CODING-GUIDELINES MUST 5 and is review-only.
- m4. Reset leaves no key, and nothing is written on load. page.tsx writes the empty form back after `removeItem`, and writes on every load. This is harmless and stated only in the notes.
- m5. `self-reflection.js:258`: `element.hasAttribute('aria-pressed')` is never true before the script sets it. Only the `BUTTON` branch counts, so this is dead code.
- m6. `SECTION_MAX` and `TOTAL_MAX` (:10-11) repeat `Maxima` (razor :292) and the literal 19 in the markup. There are two sources for the maxima.
- m7. `docs/testing.md:43` does not list `SelfReflection.cs` and `self-reflection.js` as reasons to rerun `tools/site-css.sh`. `slice-6-notes.md:3` says "Uncommitted", but the work is committed.
- m8. `Math.min(s5, 3)` :60 can never apply. It is copied from page.tsx and is harmless.

## Standards verdict
- Weakened-bar check on the diff found no suppression, skip, deleted test, removed assertion or lowered threshold. The one changed expectation is `SiteBuildTests.cs:116`, whose page list gained the four new pages, as expected.
- Review-only rules on the JS (no tool in the repo):
  - MUST 1 complexity: about 22 for `parseStored` and about 15 for `sectionScores`, counting branches and `&&`/`||`. Both are over 10, and `sectionScores` mirrors page.tsx.
  - MUST 5: m3.
  - MUST 10: m5 and `data-sr-tier-box`.
- Build-time placement is right: the section names, the sticky cut and the option lists are built in C#, and the script only scores, maps and shows.
