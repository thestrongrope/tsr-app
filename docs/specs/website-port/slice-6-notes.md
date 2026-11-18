# Website port, slice 6: implementer's notes (18 Nov 2026)

Issue #74 (part of #38): the Self-reflection pages. Uncommitted on `feature/74-self-reflection`. No plan exists: the test names are the test cases (SITE-R60 to R69).

## What was built
- `domains/content/site/self-reflection.json` (embedded resource): the three languages of `translations.ts`. `SelfReflection.cs`: typed model, section names (the page's regex), the sticky cut at 15 characters, the option lists for the script, the class sets, the four pages. `SelfReflectionPage.razor` (one component, `Language` parameter) and `SelfReflectionEntryPage.razor`. Registered in `ContentSite.PagesAsync`; no API call.
- `hosts/site/wwwroot/self-reflection.js` (390 lines, own file): pure functions (score, range, weakest, parse, write, load, save, clear) plus the DOM part. Loaded only by the three pages.
- Host: `SitePage` gains `Script` (checked by `RequireFiles` like `Files`; the layout writes it after `site.js`) and `RefreshTo` (a meta refresh in the head). `site.input.css` scans `self-reflection.js` and `SelfReflection.cs`; `site.css` regenerated; `StylesheetTests` reads both scripts and `SelfReflection.AllClasses`.
- Tests: `SelfReflectionTests.cs` (C#), `tests/js/self-reflection.test.js` (`node --test`).

## The present site's scoring rules (copied from page.tsx)
| Section | Max | Rule |
|---|---|---|
| 1 | 6 | questions 1-3: Yes = 1; questions 4-6: No = 1; unanswered 0 |
| 2 | 5 | by position: Q1 option 2, Q2 option 2, Q4 option 1, Q5 option 1 = 1 each; Q3 any choice = 1 |
| 4 | 5 | strong 1, inconsistent 0.5, weak 0 |
| 5 | 3 | a step chosen (the "other" step only with text) 1; plan trimmed over 30 characters 2, 1 to 30 characters 1; capped at 3 |
| total | 19 | sum of the four. Range: 15 and over, 11 to under 15, 6 to under 11, under 6. Weakest: lowest score/max, strict `<`, a tie keeps the first. Sections 3 and 6 are not scored |

## How the text copy was proved exact
`translations.ts` was converted by a one-off `uv run python` script (a small tokenizer for the object literal, no retyping), written with `ensure_ascii=False`. Proof: a one-off Node script imported `translations.ts` itself (type stripping) and `assert.deepStrictEqual` it against the JSON: equal, 348 strings. The script is not kept (it reads a path outside the repo). Kept: a test that the three languages hold the same keys and no empty value, and a test that every string appears on its page word for word (the `{bold}` instructions as `<strong>`).

## Gujarati font
The present site names no Gujarati font anywhere (no rule, no font file, no `next/font`): the reader's system font is used. Same here; no font file added (a test says so). Urdu: `lang="ur"` on `<main>` brings the existing `[lang="ur"]` rule (Gulzar, right to left).

## Decisions I had to make
1. **Section 2 storage.** The present site stores the option's translated words and scores by comparing them, so an answer saved in English is lost on the Urdu page, against SITE-R64. I keep the shape (words, so the present site still reads it) and map words to a position through the option lists of all three languages (handed over as a `data-options-all` attribute). Writes use the words of the page's language. Words that match nothing are no answer.
2. **Wrong-shaped storage.** Not JSON, not an object, or any field of the wrong type or length: the whole form starts empty. A missing or null field takes its empty value (the present `??`). Storage that throws on read: empty form; on write: a console error, the form still works for the visit.
3. **Saved on change only.** The present page also writes the empty form when it loads. Reset removes the key and writes nothing back.
4. **Reset confirmation** is the present English sentence on all three pages (it is in `page.tsx`, not `translations.ts`); a constant in `SelfReflection.cs`.
5. **Scripts off:** the whole form shows; the numbers, the sticky bar, the weakest line and the range highlight need the script, so they are written `hidden` and revealed by it. The `<noscript>` line (my English): "The scores need scripts: turn scripts on in your browser to see them and to keep your answers."
6. **Dropped classes:** `rtl` / `ltr` on `<main>` (no rule exists for them; `dir` does the work). The "Loading..." text is not rendered (no wait for storage here). Both are in tests or this list.
7. **Entry page:** `/self-reflection/` has a meta refresh in the head (`SitePage.RefreshTo`) and a visible link. Language links end with a slash, as the rest of the site.
8. Section names for the weakest line and the sticky bar are cut at build time; the page writes four hidden candidates and the script shows one.

## Not done or untested
- **The DOM part of `self-reflection.js` never ran** (no browser, no jsdom): clicking, typing, the live numbers, class swapping, the reset button. Only `node --check`. A walk in a browser is the missing check.
- The meta refresh was not tried in a browser. The three pages were not opened; layout rests on equal classes.
- Not changed, as told: the sentence "Your answers are not saved anywhere" (issue 75).
- Dark mode, `aria-pressed` (added by the script) and the sticky bar's look are unchecked by eye.

## Checks
| Check | Result |
|---|---|
| `dotnet build TsrApp.slnx` | 0 warnings, 0 errors |
| `dotnet test hosts/site/tests` | 755 passed, 0 failed (the new C# tests are in `SelfReflectionTests`; the rest are stylesheet cases and the older tests; one older expectation, the page list in `SiteBuildTests`, gained the four pages) |
| `node --test hosts/site/tests/js/` | 41 passed (15 before; 26 new for scoring, parsing, storage) |
The tests were written first: the JS tests failed on the missing module, the C# tests on the missing types. Not run: other test projects, Hurl, `flutter analyze`. Mutants run: `plan > 30` to `>= 30` failed R62-07; weakest `<` to `<=` failed R62-03 and R62-09; dropping `RefreshTo` failed R67-01; each reverted, all green again. Weakened-bar check on the diff: no suppression, skip or TODO; the one changed expectation is the page list in `SiteBuildTests`, which gained the four pages. Storage is touched only inside each function's try (a getter is passed), tested by R68-05.
