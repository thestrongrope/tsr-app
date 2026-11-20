# Lectures (the Lectures page of the static site)

Owner domain: `content` · Status: partial (browse only; search is issue 22)

<!-- Living document: describes TODAY. Rewrite in every PR that changes behaviour. Template: docs/templates/capability.md -->

## 1. Purpose
A visitor to the new website browses every published lecture, newest first, filters by language and opens a lecture, or one
of its chapters, on YouTube. The page is built from one data file in the repository when the site is built.

## 2. Actors and scope
- **Actors:** a visitor; the maintainer (runs the content import); the system (the site build).
- **In scope:** `/lectures/`; the data file `content/lectures/lectures.ndjson`; its import and its guard.
- **Out of scope:** keyword search and the search box; the lecture search route the app calls (issue 22); the home page's search form, which still sends `?q=` to `/lectures` where it is ignored; checking that a video is still public (a video made private stays listed until the next import); producing the data (the lecture pipeline stays in the website repository).

## 3. Requirements (current behaviour)
Tests: `LT` = `hosts/site/tests/LecturesTests.cs`, `JS` = `hosts/site/tests/js/site.test.js`, `GT` = `domains/content/api/tests/ContentGuardTests.cs`,
`GR` = `domains/content/api/tests/RepositoryContentTests.cs`, `PI` = `tools/prove-content-import.sh`.

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| LEC-R1 | The site SHALL serve a Lectures page at `/lectures` that lists every lecture of the published lecture data, newest first (date descending, then slug) | the menu links there; the old page browses newest first | Must | Test: `LT` `The_page_lists_every_lecture_newest_first`, `The_repository_lectures_render_and_the_page_stays_under_eight_megabytes`; Demonstration: `/lectures` and `/lectures/` answer 200 on the served site |
| LEC-R2 | For each lecture the page SHALL show its thumbnail, title, excerpt, duration and up to four tags, and link the thumbnail and the title to the video on YouTube | what the old card shows | Must | Test: `LT` `A_card_shows_thumbnail_title_excerpt_duration_and_four_tags`, `Timestamp_writes_minutes_and_hours` |
| LEC-R3 | WHERE a lecture has chapters, WHEN the visitor opens them THEN the page SHALL list each chapter with its start time, linking into the video at that time | what the old card shows | Must | Test: `LT` `Chapters_are_listed_with_their_times_and_link_into_the_video`; Demonstration: a chapter opens YouTube at its time |
| LEC-R4 | The page SHALL first show the newest 24 lectures; WHEN the visitor asks for more THEN it SHALL show the next 24 of the chosen language and stop offering more when none is left; it SHALL say how many are shown of how many | the old "Load more" | Must | Test: `LT` `Only_the_first_24_cards_are_shown_without_script`; `JS` `TC-LEC-R4-02 load more shows the next 24 and stops at the total`; Demonstration: the count line and Load more in a browser |
| LEC-R5 | WHEN the visitor picks a language (All, English, Urdu / Hindi, Arabic) THEN the page SHALL show only that language's lectures, starting again at 24; Urdu / Hindi SHALL hold `hi` and `ur` | the old filter; `ur` lectures belong with Urdu / Hindi (LEC-D3) | Must | Test: `JS` `TC-LEC-R5-01 a language shows only its lectures`; `LT` `Urdu_and_Hindi_lectures_carry_the_same_group`; Demonstration: the buttons in a browser |
| LEC-R6 | IF the browser runs no script THEN the page SHALL still show the newest 24 lectures with working links and chapters, and no control that does nothing | the site is static | Should | Test: `LT` `Only_the_first_24_cards_are_shown_without_script`; Demonstration: script switched off |
| LEC-R7 | IF the lecture data is missing, empty, too large, or a record breaks a rule of section 7 THEN the site build SHALL fail, naming the fault, and publish nothing | a broken library must not replace a working one | Must | Test: `LT` `A_bad_lecture_file_stops_the_build_naming_the_fault`, `A_missing_or_empty_lecture_file_stops_the_build`, `A_missing_lecture_file_fails_when_the_pages_are_collected` |
| LEC-R8 | The lecture data SHALL be copied from the website repository by the content import, and hold no transcript and no embedding | one import for all content; the transcripts are 20 MB the page does not show | Must | Test: `PI` case 12 |
| LEC-R9 | IF the repository's lecture data holds a key outside the eight (or a chapter key but `start_sec` and `title`) THEN the content guard SHALL fail, naming the line, the lecture and the key | LEC-R8 is checked, not trusted | Must | Test: `GT` `A_lecture_with_a_key_outside_the_eight_is_a_problem_that_names_it`; `GR` `The_repository_content_has_no_problem` |

## 4. Quality requirements (ISO/IEC 25010)
| ID | Characteristic | Requirement (measurable) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|---|
| LEC-Q1 | Performance | The rendered `/lectures/` page SHALL be under 8,000,000 bytes (5.06 MB for the 917 lectures of 20 Nov 2026) | every card is in the page (LEC-D2) | Must | Test: `LT` `The_repository_lectures_render_and_the_page_stays_under_eight_megabytes` |

## 5. Rules and permissions
Public content; no sign-in, no `access` check. All text goes through Razor's encoding.

## 6. Interfaces
- **Page:** `/lectures/` (`domains/content/site/LecturesPage.razor`, `Lectures.cs`); the script part is in `hosts/site/wwwroot/site.js` (`lecturesToShow`, `setUpLecturesPage`).
- **API / events:** none.

## 7. Data
`content/lectures/lectures.ndjson`: one JSON object per line, one line per lecture, with exactly these keys: `slug` (the YouTube video id, `^[A-Za-z0-9_-]{11}$`, unique), `title` (not blank), `excerpt` (may be empty), `tags` (array of strings; a blank one is not shown), `language` (a string, may be empty; `en`, `hi`, `ur`, `ar` are the ones the filter knows), `publishedDate` (exactly `yyyy-MM-ddTHH:mm:ssZ`), `durationSec` (integer of 0 or more), `chapters` (array of `{start_sec: integer of 0 or more, title: not blank}`). At most 5,000 lectures and 20,000,000 bytes. Public data, no PII. Copied by `tools/content-import.sh` (the source's `lectures/lectures.ndjson`, trimmed with `jq`); see `content/README.md`.

## 8. Decisions in force
| ID | Decision | Reason |
|---|---|---|
| LEC-D1 | The page is built from a file, not from the API, until lecture search (issue 22) is built (owner, 20 Nov 2026) | the app reads lectures only through search; the named exception to `domains/CLAUDE.md` rule 9 |
| LEC-D2 | Every lecture is written into the page; the script only shows and hides cards | no data file to fetch, no card built in script, no change to the site host's code |
| LEC-D3 | `ur` lectures are shown with `hi` under "Urdu / Hindi" | the old page left the 27 `ur` lectures out of every language button |

## 9. Known limitations, gaps and open questions
- The script's `render()` (count line, the more element, the reset to 24 on a language change) and the page without script have no automated test; the repository has no browser test for the site.
- A video made private stays listed until the next import.
