# Lectures (the Lectures page of the static site)

Owner domain: `content` · Status: partial (browse only; search is issue 22)

<!-- Living document: describes TODAY. Rewrite in every PR that changes behaviour. Template: docs/templates/capability.md -->

## 1. Purpose
A visitor to the new website browses every published lecture, newest first, filters by language and opens a lecture, or one
of its chapters, on YouTube. The page is built from one data file in the repository when the site is built.

## 2. Actors and scope
- **Actors:** a visitor; the maintainer (runs the content import); the system (the site build).
- **In scope:** `/lectures/`; the data file `content/lectures/lectures.ndjson` (the full file, which the search feed also reads: `domains/search/CLAUDE.md`); its import, its mask and its guard.
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
| LEC-R8 | The lecture data SHALL be copied from the website repository by the content import, every line copied whole, the transcript, the search phrases, the key points and the embedding too, as the search feed reads them (lecture search, issue 22), except for the mask of LEC-R10 | one import for all content; the site reads eight keys and ignores the rest; the owner accepts the transcripts as public (issue 22, decision a) | Must | Test: `PI` cases 12 and 14 |
| LEC-R9 | IF the repository's lecture data holds a key outside the thirteen (`slug`, `title`, `url`, `excerpt`, `content`, `search_phrases`, `key_points`, `tags`, `language`, `publishedDate`, `durationSec`, `chapters`, `embedding`), or a chapter key but `start_sec`, `title`, `summary` and `url`, THEN the content guard SHALL fail, naming the line, the lecture and the key | LEC-R8 is checked, not trusted | Must | Test: `GT` `A_lecture_with_a_key_outside_the_thirteen_is_a_problem_that_names_it`, `A_lecture_with_the_thirteen_keys_of_the_full_file_is_not_a_problem`; `GR` `The_repository_content_has_no_problem` |
| LEC-R10 | The content import SHALL replace each phone-like run in a text key of a lecture (`title`, `excerpt`, `content`, `search_phrases`, `key_points`, `tags`, a chapter's `title` and `summary`) with `[number removed]` and change no other key or byte; IF a text key of the repository's lecture data holds a phone-like run THEN the content guard SHALL fail, naming the line, the lecture and the key. A phone-like run is (1) an optional `+` and 10 to 13 digits in all, a single space, dot, hyphen or parenthesis allowed between digits, no digit before or after (a letter ends it); or (2) a run of 4 or more digits in all, written the same way, that begins within 80 characters after the words whatsapp, phone, mobile or contact and then number or no (any case), or after a `[number removed]`; the window opens again after each mask, so the groups of a number said in pieces go one after the other; the import repeats rule 2 until nothing changes, at most 10 passes (the real file needs 2) and refuses if it still matches; 1 to 3 digits stay | the lectures say a WhatsApp number aloud; the repository is public and holds no personal data; the vectors stay as computed from the unmasked text | Must | Test: `PI` cases 14 to 17; `GT` `A_phone_like_run_in_a_text_key_is_a_problem_that_names_the_line_the_lecture_and_the_key`, `A_figure_after_a_masked_run_is_a_problem_when_it_begins_within_80_characters_of_the_mask`, `A_figure_more_than_80_characters_after_the_last_mask_is_not_a_problem`, `A_masked_run_and_figures_that_are_not_phone_like_are_not_a_problem`, `Short_figures_and_figures_far_from_the_words_are_not_a_problem_after_a_number_word`, `The_embedding_is_not_read_for_phone_like_runs`; `GR` `The_repository_content_has_no_problem` |

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
`content/lectures/lectures.ndjson`: tsr-web's full file (917 lectures, about 22.7 MB), one JSON object per line, one line per lecture, with these keys. The page reads the first eight and ignores the rest. `slug` (the YouTube video id, `^[A-Za-z0-9_-]{11}$`, unique), `title` (not blank), `excerpt` (may be empty), `tags` (array of strings; a blank one is not shown), `language` (a string, may be empty; `en`, `hi`, `ur`, `ar` are the ones the filter knows), `publishedDate` (exactly `yyyy-MM-ddTHH:mm:ssZ`), `durationSec` (integer of 0 or more), `chapters` (array of `{start_sec: integer of 0 or more, title: not blank}`, and `summary` and `url`, which the page ignores). The five keys only the search reads: `url`, `content` (the transcript), `search_phrases`, `key_points` and `embedding` (384 numbers, last key; 19 lectures have none). At most 5,000 lectures and 64,000,000 bytes (the site's bound and the feed's). Public data; phone-like runs in the text keys are masked at import (LEC-R10), so the text differs from tsr-web's in those characters and the vectors, computed from the unmasked text, are kept as they are. Copied by `tools/content-import.sh` (the source's `lectures/lectures.ndjson`); see `content/README.md`.

## 8. Decisions in force
| ID | Decision | Reason |
|---|---|---|
| LEC-D1 | The page is built from a file, not from the API, until lecture search (issue 22) is built (owner, 20 Nov 2026) | the app reads lectures only through search; the named exception to `domains/CLAUDE.md` rule 9 |
| LEC-D2 | Every lecture is written into the page; the script only shows and hides cards | no data file to fetch, no card built in script, no change to the site host's code |
| LEC-D3 | `ur` lectures are shown with `hi` under "Urdu / Hindi" | the old page left the 27 `ur` lectures out of every language button |

## 9. Known limitations, gaps and open questions
- The script's `render()` (count line, the more element, the reset to 24 on a language change) and the page without script have no automated test; the repository has no browser test for the site.
- A video made private stays listed until the next import.
