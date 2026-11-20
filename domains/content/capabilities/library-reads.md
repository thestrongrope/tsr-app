# Library reads (articles, categories, tags, publications, latest videos)

Owner domain: `content` · Status: partial (built and tested on the local stacks; the live domain does not point here yet, so no app build reaches it)

<!-- Living document: describes TODAY. Rewrite in every PR that changes behaviour. Template: docs/templates/capability.md -->

## 1. Purpose
Members and guests open the app's Library to read articles, browse by category and tag, see publications and the
channel's latest videos. Store-live app builds have the website's addresses and answer shape built in, so these reads
answer at the same addresses in the same shape. The content files in git stay the source: a worker copies the published
ones into `content`'s tables and the reads answer from that copy.

## 2. Actors and scope
- **Actors:** a reader (member or guest, never signed in on these routes); an editor (changes the content files); the
  operator (reads the worker's log and `content.refresh_state`); the system (the `content-refresh` worker).
- **In scope:** the six public `GET` routes under `/api/v1/` (section 6), the `content-refresh` worker, the in-memory
  copy of the channel's feed.
- **Out of scope:** search of articles and lectures; the public pages; redirects, PDFs and other files of the website;
  the address that lists one category's articles (no app build calls it); the stub `GET /articles` and its table
  `content.articles`, which are separate from everything here (`domains/content/CLAUDE.md`).

## 3. Requirements (current behaviour)
"Published" means the file's `status` is `publish` or `published`; the publish date is not checked. Test files:
`HA` = `spec/tests/v1-articles.hurl`, `H1` = `v1-article.hurl`, `HC` = `v1-categories.hurl`, `HT` = `v1-tags.hurl`,
`HP` = `v1-publications.hurl`, `HV` = `v1-videos.hurl` (case numbers are the numbered comments in each file);
in `db/tests/`: `DA` = `V1ArticlesTests.cs`, `D1` = `V1ArticleTests.cs`, `DT` = `V1TaxonomiesTests.cs`,
`DP` = `V1PublicationsTests.cs`, `DR` = `ContentRefreshTests.cs`, `CL` = `ContentLoadTests.cs`, `DF` = `ContentFilesTests.cs`,
`DV` = `LatestVideosTests.cs`, `DY` = `YouTubeFeedTests.cs`;
in `api/tests/`: `GT` = `ContentGuardTests.cs`, `GR` = `RepositoryContentTests.cs`; `PI` = `tools/prove-content-import.sh` (cases numbered as printed).

**All reads**

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| LIB-R1 | The system SHALL answer every Library read without asking the caller to sign in | guests use the Library; the app sends no sign-in | Must | Test: case 1 of `HA`, `H1`, `HC`, `HT`, `HP`, `HV`; `DA` `The_list_needs_no_sign_in_and_answers_in_the_v1_shape` |
| LIB-R9 | IF a request carries an option the route does not use THEN the system SHALL ignore it and answer as if it were absent | supported builds send options the website ignores | Must | Test: `HA` case 30; `H1` case 23; `HC` case 8; `HT` case 2; `HP` case 4; `HV` case 4 |
| LIB-R12 | The system SHALL never include an unpublished article in any list, count, related list or answer | a filter fault must not leak a draft | Must | Test: `DR` `A_draft_is_never_copied_and_appears_in_no_read`; `HA` case 1, `H1` case 1, `HC` case 1, `HT` case 1 (the fixture's two drafts would raise the counts) |
| LIB-R19 | WHEN a supported app build sends a Library request THEN the system SHALL answer with every field that build reads, under the same name, of the same kind, in the shape `{success, data, meta, pagination}` | no app release can be required | Must | Test: the field assertions of case 1 of `HA`, `H1`, `HC`, `HT`, `HP`; `DV` `Videos_page_newest_first`, `A_video_s_fields_are_made_as_the_website_makes_them`. The app itself has not been run against these routes (section 9) |
| LIB-R25 | WHERE a caller sends `If-None-Match` equal to the answer's `ETag`, or on the two article routes, with no `If-None-Match` sent, an `If-Modified-Since` not older than its `Last-Modified`, the system SHALL answer 304 with no body (LIB-D16). The videos route sends an `ETag` and never answers 304 | saves data on phones; the website's videos route never compares | Should | Test: `HA` cases 34 to 38; `H1` cases 16 to 22; `HC` cases 9 to 11; `HT` cases 3 to 5; `HP` cases 5 and 6; `HV` case 3; `DV` `The_videos_send_the_cache_headers_and_never_a_304` |

**The published content in the repository** (the folder `content/`, filled by `tools/content-import.sh`, copied into the API image and loaded at each deploy)

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| LIB-R27 | The repository SHALL hold the published content the Library and the site read: every published article, every category, and the publications list | a deploy can only carry what the repository holds | Must | Test: `GR` `The_repository_content_has_no_problem`, `GT` `An_empty_folder_and_an_unexpected_file_are_problems`. Inspection: the article count of `content/articles` equals the website's published count, and its `categories` equal file for file (`diff -r`), done by hand at each import |
| LIB-R28 | IF a file in the repository's published content is an article that is not published THEN the repository's checks SHALL fail and name the file | a draft in a public repository is published for good | Must | Test: `GT` `A_draft_is_a_problem_that_names_the_file` (the statuses `draft`, `Publish` and none) |
| LIB-R29 | WHEN content is copied from the source into the repository THEN only published articles SHALL be copied | the source holds more drafts than published articles | Must | Test: `PI` cases 1 to 3 |
| LIB-R30 | WHEN content has been copied from the source THEN the copy SHALL report how many files it copied and how many it left out | the person copying must see what was left out | Should | Test: `PI` case 1 |
| LIB-R31 | IF a published article in the repository names a category the repository does not hold THEN the repository's checks SHALL fail and name the article and the category | otherwise the article silently drops out of its category | Should | Test: `GT` `A_category_without_a_file_is_a_problem_that_names_both` |
| LIB-R32 | WHEN the production stack has been deployed THEN the Library SHALL answer with the content of the deployed version, with no step by hand after the deploy | production answered nothing | Must | Test: `ProductionStackTests` `The_stack_loads_the_image_s_content_at_each_deploy`; `CL` `A_load_copies_the_content_directory_and_reports_success`. Demonstration: the production stack from empty, `content-load` exits 0 and `GET /api/v1/articles?limit=1` answers the full count |
| LIB-R33 | WHEN the production stack has been deployed THEN the public site SHALL show the content of the deployed version | a site built before the content is loaded is empty | Must | Test: `ProductionStackTests` `The_site_is_built_only_after_the_content_is_loaded`. Demonstration: the site's `/articles/` page lists articles |
| LIB-R34 | IF the content of a deployed version cannot be loaded THEN the Library and the site SHALL keep serving the content they served before (nothing, where there was none) | a bad content change must not empty a live site | Must | Test: `CL` `A_load_that_fails_keeps_the_last_set_and_reports_failure`; the job exits 1, so `site-build` does not start |
| LIB-R35 | IF the content of a deployed version cannot be loaded THEN the failure and its cause SHALL be visible in the deployment's logs | a failure nobody sees is found by a reader | Must | Test: `CL` `A_load_that_fails_logs_the_cause_as_an_error` |
| LIB-R36 | WHEN a reader, on the site or in the app, opens a file the publications list links THEN the system SHALL send that file (the site answers each `/downloads/` path) | the publications page and the app link to the files; the app joins the same path to the website address, so it works before and after the domain moves | Must | Test: `ProductionStackTests` `The_site_image_carries_the_publication_files`. Demonstration: the production stack with placeholder settings, every `file` of `/api/v1/publications` answers 200 as `application/pdf` from the `site` container |
| LIB-R37 | IF the publications page links a file the repository does not hold, or the repository holds a file no publication links, or anything below `downloads/` is not a folder or a regular `.pdf` file, or a `file` link does not start with `/downloads/` THEN the repository's checks SHALL fail and name the link or the path (names compared exactly, case included) | a dead link is found before a release, a file nobody links is dead weight in git, and the server is case-sensitive where a developer's Mac is not | Should | Test: `GT` `A_linked_file_the_folder_does_not_hold_is_a_problem_that_names_the_link`, `A_link_that_differs_only_in_case_from_the_file_is_a_problem`, `A_file_no_publication_links_is_a_problem_that_names_the_path`, `Only_pdf_files_are_allowed_below_downloads`, `A_file_below_a_subfolder_of_downloads_is_checked_too`, `A_file_link_outside_downloads_is_a_problem_that_names_the_link`; `GR` `The_repository_content_has_no_problem` |

**GET /api/v1/articles**

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| LIB-R2 | WHEN a reader asks for the article list THEN the system SHALL return published articles newest first, 20 to a page unless `limit` asks for 1 to 100, starting at `offset` (0 when absent, negative or not a number), with `pagination` `{total, limit, offset, hasMore}` | browse the Library | Must | Test: `HA` cases 1 to 6 |
| LIB-R3 | WHEN a reader gives `category` THEN the system SHALL return only the articles filed under exactly that slug, case and all | one subject | Must | Test: `HA` cases 7 to 10 |
| LIB-R4 | WHEN a reader gives `tag` THEN the system SHALL return only the articles carrying exactly that tag name, case and all | one theme | Must | Test: `HA` cases 11 to 13 |
| LIB-R5 | WHEN a reader gives `q` THEN the system SHALL return only the articles whose title, excerpt or one tag contains it, in any case | find a half-remembered article | Must | Test: `HA` cases 14 to 17 |
| LIB-R6 | WHEN a reader gives `sort` as `publishedDate:desc`, `publishedDate:asc`, `title:asc` or `title:desc` THEN the system SHALL order the list so; equal titles come newest first in both directions | oldest first, or by title | Must | Test: `HA` cases 19 to 23; `DA` `Equal_titles_come_newest_first_in_both_directions_of_the_title_order`, `Titles_differing_in_case_or_accent_sort_as_a_dictionary_does_not_in_byte_order` |
| LIB-R7 | IF `sort` is any other value THEN the system SHALL answer 400 with `error.code` `VALIDATION_ERROR` and a message naming the valid values | builds parse it | Must | Test: `HA` cases 24 and 25; `DA` `An_unknown_sort_is_a_400_in_the_v1_error_shape_without_cache_headers` |
| LIB-R8 | IF `limit` is below 1 or above 100 THEN the system SHALL use 1 or 100, and 20 when it is not a number, and SHALL NOT refuse | a refusal would break a build that sends one | Must | Test: `HA` cases 27 to 29; `DA` `A_number_is_read_as_javascript_reads_it_and_clamped` |
| LIB-R26 | WHEN a reader gives `locale` THEN the system SHALL return only the articles written in exactly that language code | the website does | Must | Test: `HA` cases 31 to 33 |

**GET /api/v1/articles/{slug}**

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| LIB-R10 | WHEN a reader asks for a published article by its slug THEN the system SHALL return it with its text as HTML in `content` (LIB-D18), its reading time, and five other published articles in `relatedArticles`: highest score first (2 for each shared category, 1 for each shared tag), equal scores newest first, a score of 0 included | read and continue; the app displays HTML | Must | Test: `H1` cases 1 to 8; `D1` `Related_are_the_five_highest_scores_a_shared_category_counting_two_and_ties_newest_first`, `Related_are_filled_up_to_five_with_articles_that_share_nothing_newest_first`, `The_199_character_slug_opens`, `A_percent_encoded_slug_opens_as_written_and_as_the_characters_it_stands_for`, `The_raw_html_article_opens_without_anything_that_could_run`; the HTML itself: `DF` `A_footnote_becomes_a_numbered_reference_and_a_list_of_notes_at_the_end`, `A_pipe_table_becomes_a_table`, `A_bare_web_address_becomes_a_link`, `Strikethrough_and_task_lists_of_github_markdown_stay_as_written` |
| LIB-R11 | IF a reader asks for a slug that no published article has (a draft's slug included) THEN the system SHALL answer 404 with `error.code` `NOT_FOUND` and the message `Article not found: <the slug asked>`, and nothing else | a draft must not be readable by its address | Must | Test: `H1` cases 9 to 14; `D1` `An_unknown_or_unpublished_slug_is_a_404_that_echoes_only_the_slug_asked`, `A_slug_no_article_can_have_is_a_404_never_a_500` |

**Categories, tags, publications**

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| LIB-R13 | WHEN a reader asks for the categories THEN the system SHALL return the parents in order, each with its `subcategories`, each category with the number of published articles filed under its own slug; `hierarchical=false` gives the flat list and `includeArticleCounts=false` gives every count as 0 | choose a subject | Must | Test: `HC` cases 1 to 7; `DT` `The_categories_are_the_parents_in_order_each_with_its_children_and_its_own_count`, `Flat_categories_are_all_seven_in_order_with_their_parent_and_no_children`, `Only_the_text_false_switches_an_option_off` |
| LIB-R14 | WHEN a reader asks for the tags THEN the system SHALL return each tag with `name`, `slug` and its number of published articles, most used first, equal counts in the order first met walking the articles newest first | choose a theme | Must | Test: `HT` case 1; `DT` `The_tags_are_most_used_first_and_equal_counts_in_the_order_first_met_newest_article_first`, `A_tag_s_slug_is_made_as_the_website_makes_it` |
| LIB-R15 | WHEN a reader asks for the publications THEN the system SHALL return each, in file order, with its title and, where the file has them, summary, type, size, language, date of last update, `file` and `readOnlineUrl` as the file writes them; `language` narrows to one language in any case | open a book; the app joins a site-relative link to its website address | Must | Test: `HP` cases 1 to 3; `DP` `The_publications_come_in_file_order_with_site_relative_links_and_no_field_that_the_file_lacks`, `The_language_filter_matches_the_whole_language_in_any_case` |

**GET /api/v1/youtube**

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| LIB-R16 | WHEN a reader asks for the latest videos THEN the system SHALL return the channel's videos newest first, 10 to a page unless `limit` asks for 1 to 50, starting at `offset`, from the 50 newest at most | watch a recent lecture | Must | Test: `DV` `Videos_page_newest_first`, `The_totals_are_the_size_of_the_slice_taken`; `HV` case 2 (the clamps, on an empty list) |
| LIB-R17 | IF the channel's feed cannot be read and a list was read earlier THEN the system SHALL return that list with status 200 | the home screen must not break | Must | Test: `DV` `A_failed_feed_serves_the_kept_list`, `A_feed_that_throws_anything_serves_the_kept_list_and_is_not_asked_again_for_30_minutes` |
| LIB-R18 | IF the channel's feed cannot be read and no list was ever read, or no channel is configured, THEN the system SHALL return an empty list with status 200 | the first read after a start must not break the home screen | Must | Test: `DV` `A_feed_never_read_gives_an_empty_list`, `Without_a_channel_the_real_reader_calls_nothing_and_the_list_is_empty`; `HV` case 1 |

**The refresh**

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| LIB-R20 | WHEN an article is published in the content files THEN the system SHALL include it in every read after the next refresh, which runs at start and every 5 minutes, with no manual step | an editor runs nothing by hand | Must | Test: `DR` `A_new_published_file_is_read_on_the_next_tick`. Inspection: the interval in `api/workers/ContentRefreshWorker.cs`. The 10 minute bound over the real content: not verified (section 9) |
| LIB-R21 | WHEN a published article is changed in the content files THEN the system SHALL return the changed article after the next refresh | corrections reach readers | Must | Test: `DR` `A_changed_file_replaces_the_article`, `A_change_to_any_stored_field_of_an_article_a_category_or_a_publication_is_a_change` |
| LIB-R22 | WHEN an article is removed from the content files or set to a draft THEN the system SHALL stop returning it after the next refresh | a mistake does not stay public | Must | Test: `DR` `A_file_removed_or_set_to_draft_is_no_longer_returned` |
| LIB-R23 | WHILE a refresh is running, the system SHALL keep answering from the last complete set | a half-loaded Library is worse than a stale one | Must | Test: `DR` `A_reader_sees_the_last_complete_set_until_the_refresh_commits`, `A_refresh_that_throws_before_its_commit_leaves_the_last_set` |
| LIB-R24 | IF a refresh cannot read the files, finds no published article, or finds fewer than half the articles of the last complete set, THEN the system SHALL keep the last complete set, store the time and cause in `refresh_state`, and log one warning with the cause | a refresh that "succeeds" empty must not empty the Library | Must | Test: `DR` `A_refresh_that_fails_or_shrinks_keeps_the_last_set_and_records_why`, `Four_articles_down_to_two_is_not_a_halved_refresh`, `A_read_that_throws_keeps_the_last_set_and_records_the_exception_type` |

## 4. Quality requirements (ISO/IEC 25010)
| ID | Characteristic | Requirement (measurable) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|---|
| LIB-Q1 | Compatibility | The same Library requests give the same status, `Cache-Control` and JSON from today's website run locally and from this API, apart from the lines of `tools/website-parity.allow` | store-live builds | Must | Demonstration: `tools/website-parity.cs` over `tools/website-parity.cases` and `--sweep`; last run in `docs/specs/website-port/parity-results.md`. Run by hand, not part of the gates |
| LIB-Q2 | Performance | On the local stack, 95 of 100 list or article reads answer within 300 ms | the Library opens on these reads | Should | Demonstration: `tools/website-parity.cs --timing`; last run in `parity-results.md` |
| LIB-Q3 | Security | No unpublished article is copied out of the content files into the database | a draft that is not stored cannot leak | Must | Test: `DR` `A_draft_is_never_copied_and_appears_in_no_read`; `DF` `Only_publish_and_published_are_kept` |

## 5. Rules and permissions
No sign-in, no permission, no scope: every route is a public read (`security: []` in `spec/api.yaml`). The article,
category, tag and publication routes read only tables that hold published content; the videos route reads a public feed.
Every answer carries `Access-Control-Allow-Origin: *` and `X-Content-Type-Options: nosniff`.

The content files are untrusted input. One refresh reads at most 20,000 files, 5 MB a file, 200 MB in all, 64 KB of
front matter nested 16 deep, an article body of 100,000 characters, within 2 minutes; a symbolic link is refused. Any
of these, a file that cannot be parsed, a duplicate slug, or a published article that cannot be stored fails the whole
read, never truncates it (LIB-R24). A failure's cause is a fixed phrase and a file name at most (`DF`).

## 6. Interfaces
- **Screens:** none here; the app's Library screens live in the tsr-account repository and call these routes.
- **API** (`spec/api.yaml`; contract files in `spec/tests/v1-*.hurl`):
  `GET /api/v1/articles`, `GET /api/v1/articles/{slug}`, `GET /api/v1/taxonomies/categories`,
  `GET /api/v1/taxonomies/tags`, `GET /api/v1/publications`, `GET /api/v1/youtube`.
  Success: `{success: true, data, meta: {timestamp, version, cache: {expires, maxAge}}, pagination?}`.
  Failure: `{success: false, error: {code, message}, meta}` with code `VALIDATION_ERROR` (400), `NOT_FOUND` (404) or
  `INTERNAL_ERROR` (500), and no cache headers.
- **Worker:** `content-refresh` (run mode `--workers`), setting `TSR_CONTENT_DIR`.
- **Settings:** `TSR_CONTENT_DIR`, `TSR_YOUTUBE_CHANNEL_ID`, `TSR_YOUTUBE_FEED_URL` (`domains/content/CLAUDE.md`).
- **Events:** none.

## 7. Data
Tables in schema `content`, replaced whole by each refresh in one transaction, never written by a route:
`published_articles` (one row a published article: slug as written, decoded slug, Markdown, HTML, dates, categories,
tags), `categories`, `publications`, and `refresh_state` (one row: the hash and count of the last copy, when it was
made, and the time and cause of the last failure). The latest videos have no table. No PII: everything is published
website content. Nothing to erase on account deletion.

## 8. Decisions in force
| ID | Decision | Reason |
|---|---|---|
| LIB-D1 | The content files in git stay the source; the `content-refresh` worker copies them and nothing in the API writes content | one place to write articles |
| LIB-D2 | The same `/api/v1` addresses and the `{success, data, meta, pagination}` shape as the website, with its failure shape: the named exception to root rule 7's `{"detail"}` | supported app builds read this shape |
| LIB-D3 | `rawContent` (the article's Markdown) is not sent | the app does not read it and it carries the file's raw HTML |
| LIB-D4 | Raw HTML in the Markdown is dropped, and a link or image address whose scheme is not `http`, `https` or `mailto` is emptied, in a table cell and a footnote as anywhere else (`DF` `Raw_html_in_a_footnote_or_a_table_cell_is_dropped`, `A_bare_address_with_another_scheme_in_a_table_cell_keeps_its_text_and_has_no_address`) | the HTML is put in a page; the website's renderer sanitises too |
| LIB-D5 | Front matter is read by the project's own reader over the YAML event stream; it refuses aliases, anchors, tags, keys that are not text, a second document and nesting past 16 | the library's document tree overflows the stack or never ends on aliases |
| LIB-D6 | Drafts are never copied: only `status` `publish` or `published` leaves the files. The publish date is not checked, so a future-dated article is shown | a draft that is not stored cannot leak; the website does not check the date either |
| LIB-D7 | A percent-encoded slug opens: the path is matched against the decoded slug, and the answer's `slug` is the file's own text | the website never finds these articles; no live address changes |
| LIB-D8 | The feed's text is sent decoded (the website sends it still XML-escaped) | the feed is read as XML, so the text is the text |
| LIB-D9 | The videos are kept in memory, per process: one read of the feed is believed for 30 minutes, and the last good list is served when a read fails | the website's behaviour; no outside call per request |
| LIB-D10 | The 33 PDFs the publications page links are held in this repository (`content/downloads/`, plain git, 187 MB, decided by the owner 16 Nov 2026). The site image carries them; the API image does not (`The_api_image_carries_the_text_content_and_not_the_files`). The three PDFs of the website that no entry links stay out | the files must ship with a release and the repository is the source of a release; the API never reads them |
| LIB-D11 | Known faults of the website's answers are kept: a comma-joined filter matches nothing, every list item says `readingTime` 1, a missing `id` is 0, the videos' totals are the size of the slice taken (so `hasMore` is never true), related articles are filled up with articles that share nothing | each fix is its own later change |
| LIB-D12 | The `ETag` is an MD5 over `data` and `pagination` only, never `meta` | `meta.timestamp` changes on every answer |
| LIB-D13 | Slugs, categories and tags are case-sensitive `text` columns, the written exception to "every text column is citext" (`db/tests/SchemaGuardTests.cs`) | an address, a category and a tag match exactly on the website |
| LIB-D14 | Equal category orders tie by slug; title order is ICU's (`en-x-icu`) | the website's tie order is the file system's, not a rule |
| LIB-D15 | A publication link must be site-relative (one leading `/`) or `http`/`https`, with no white space; anything else fails the refresh | a reader's app or browser opens it |
| LIB-D16 | A request that carries `If-None-Match` is judged by it alone; `If-Modified-Since` is read only when it is absent (RFC 9110 section 13.1.3). The website answers 304 when either matches | a cache that sends both must not keep an old copy of a corrected article whose date did not move |
| LIB-D17 | The channel's id is in the code (a public id, as the website has it); the setting `TSR_YOUTUBE_CHANNEL_ID` names another, and set to nothing it turns the feed read off, which every test stack and the test host do | nothing secret; production needs no setting; no test calls the feed |
| LIB-D18 | Markdown is rendered as CommonMark with three features of GitHub-flavoured Markdown and no other: footnotes (`[^1]` with `[^1]: text`), pipe tables, and a bare web address (`http://`, `https://`, `www.`) as a link. Strikethrough and task lists stay as written. A footnote is a numbered link in the text and a list in `<div class="footnotes">` at the end (`DF` `A_footnote_becomes_a_numbered_reference_and_a_list_of_notes_at_the_end`, `A_pipe_table_becomes_a_table`, `A_bare_web_address_becomes_a_link`, `Strikethrough_and_task_lists_of_github_markdown_stay_as_written`) | the website's pages show these three, and the static site is built from this HTML; the website's own API renders plain CommonMark, so `content` differs from it for an article that uses one |
| LIB-D19 | The repository holds published content only; drafts stay in the source. The guard reads every article with the real reader (`api/tests/ContentGuard.cs`), so a file the reader would not publish fails it | a public repository cannot hold a draft |

## 9. Known limitations, gaps and open questions
- **Test gaps:** LIB-R19 for the app itself: its website address is a constant, so its Library journeys have not run
  against these routes. LIB-R20 to R22: the "within 10 minutes" bound rests on the 5 minute interval; the time of one
  refresh over the real content is not recorded. LIB-Q1 and LIB-Q2 are manual runs against a local development server
  of the website, not a production build and not the live site; the parity tool does not compare conditional requests,
  `ETag`, `Last-Modified` or the cross-origin headers. No test covers `OPTIONS` or `HEAD`.
- **Known differences from the website, kept:** `content` of an article with a footnote, a pipe table or a bare web address holds the rendered
  feature where the website's API holds the source text (LIB-D18); no app build has been run on that HTML. A bare `mailto:` address is linked and
  shown without the word `mailto:`. A slug whose `%` is encoded twice answers 404 where the website answered 200 (LIB-D7).
  The list's `Last-Modified` is the newest article date, so it does not move when an article is withdrawn (the `ETag` does).
  `OPTIONS` and `HEAD` answer 405; the website answers the preflight, which is needed before a browser client uses these routes.
- **Not verified against a real service:** the channel's feed in the automated tests (a fake at the boundary; the real
  feed was read once in the parity run).
- **Limits:** no rate limit and no shared cache stand in front of these routes, and each request reads its tables.
  The videos' copy is per process. `TSR_YOUTUBE_FEED_URL` is in no compose file. Where production gets the content files is not decided (the folder `content/` exists, but nothing reads it yet), and production is not wired.
- **Open questions:** whether 10 minutes, 300 ms and "fewer than half" are the right numbers; whether a future-dated
  article should wait for its date; which app build is the floor for "supported".
