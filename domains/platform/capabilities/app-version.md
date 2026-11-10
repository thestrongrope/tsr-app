# App version check (start-up update prompt)

Owner domain: `platform` · Status: live

<!-- Living document: describes TODAY. Rewrite in every PR that changes behaviour. Template: docs/templates/capability.md -->

## 1. Purpose
When the mobile app starts it asks which build is the lowest allowed and which is the newest, so it can block a build that
is too old and offer the update, with that release's notes and one optional announcement. It must work for a build whose
sign-in has expired, and a lost or half-edited catalog file must never lock anyone out.

## 2. Actors and scope
- **Actors:** the app (asks, no sign-in), the person who edits the catalog file.
- **In scope:** `GET /app-version`; reading and validating the catalog; the permissive fallback.
- **Out of scope:** the release history list (`release-notes.md`); changing the file (a deploy); moving the data into a table.

## 3. Requirements (current behaviour)
`U` = `api/domain/AppCatalog.Tests.cs`; `H` = `spec/tests/app-version.hurl` (runs on the PHP parity stack and the dev stack, one shared synthetic catalog).

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| APPVER-R1 | WHEN anyone asks, signed in or not, THEN the system SHALL return 200 with an object holding `android`, `ios`, then `announcement` when there is one, in that order | the app reads it before it can sign in | Must | Test: H case 1, 4; U `The_payload_keeps_the_order_android_ios_announcement` |
| APPVER-R2 | IF the catalog is missing, unreadable, larger than 1 MiB, not valid JSON or not a JSON object or list THEN the system SHALL return 200 with minimumBuild 1, recommendedBuild 1 and the fixed store URL for both platforms, and log it | a lost file must not lock every client out | Must | Test: U `A_missing_file_serves_the_fallback`, `A_file_that_is_not_a_json_object_or_list_serves_the_fallback`, `A_file_with_a_byte_order_mark_serves_the_fallback_like_php`, `A_file_with_invalid_utf8_serves_the_fallback`; size cap: none yet (section 9) |
| APPVER-R3 | IF a platform has no `minimumBuild` that is a JSON integer (a quoted "12", 12.0, 1e2, a number beyond 64 bits, null, missing) THEN the system SHALL give that platform alone the fallback block, with no `latest` | a typo must degrade one platform, not the request | Must | Test: H case 2; U `A_minimumBuild_that_is_not_a_json_integer_gives_that_platform_the_fallback_block`, `A_platform_entry_without_a_minimumBuild_is_the_fallback_block`, `A_missing_platform_is_the_fallback_block`, `A_platform_that_fell_back_never_gets_latest_even_when_a_release_has_build_1` |
| APPVER-R4 | The system SHALL accept any JSON integer that fits 64 bits as a build (including 0, -0 and negatives) | PHP `is_int` | Must | Test: U `Any_json_integer_that_fits_64_bits_is_accepted_as_minimumBuild` |
| APPVER-R5 | The system SHALL use the catalog's `recommendedBuild` when it is an integer, else the `minimumBuild` | the recommended build can never be below nothing | Must | Test: U `A_recommendedBuild_that_is_an_integer_is_used`, `A_recommendedBuild_that_is_not_an_integer_becomes_the_minimumBuild`, `A_missing_recommendedBuild_becomes_the_minimumBuild` |
| APPVER-R6 | The system SHALL use the catalog's `storeUrl` when it is a non-empty string, else the platform's fixed store URL | a bad link must not break the prompt | Must | Test: U `A_storeUrl_that_is_a_non_empty_string_is_used`, `A_storeUrl_that_is_empty_or_not_a_string_is_the_fallback_url`, `The_store_url_is_written_with_unescaped_slashes_and_unicode` |
| APPVER-R7 | WHEN a valid release in the catalog has, for a platform, an integer build equal to that platform's `recommendedBuild` THEN the system SHALL add `latest` `{version, notes}` from the first such release in file order; otherwise `latest` SHALL be absent, not null | the prompt shows the notes of the build being offered | Must | Test: H case 1; U `Latest_is_the_first_release_in_file_order_whose_build_equals_the_recommendedBuild`, `Latest_skips_releases_that_do_not_match_and_keeps_the_file_order`, `Latest_is_absent_not_null_when_no_release_matches`, `Latest_needs_an_integer_build_so_a_quoted_build_never_matches`, `Latest_is_looked_up_per_platform` |
| APPVER-R8 | The system SHALL validate releases one by one and drop (with a log line) each one without a non-empty string `version`, a string `date` of the shape YYYY-MM-DD (shape only; 2030-99-99 passes; PHP lets one final newline through) and a `builds` object or list; a dropped release never affects the others or the minimum | a bad entry must not hide the rest | Must | Test: U `A_release_without_a_non_empty_string_version_is_dropped`, `A_release_whose_date_is_not_a_yyyy_mm_dd_string_is_dropped`, `A_date_is_checked_for_its_shape_only_and_php_lets_one_final_newline_through`, `A_release_without_a_builds_object_is_dropped`, `A_release_that_is_not_an_object_is_dropped_and_the_next_one_is_still_used`, `A_malformed_release_never_drops_the_others` |
| APPVER-R9 | IF `releases` is not a list or object THEN the system SHALL ignore it | same | Must | Test: U `A_releases_value_that_is_not_a_list_is_ignored`, `A_releases_value_that_is_an_object_is_read_as_its_values_in_file_order_like_php` |
| APPVER-R10 | The system SHALL keep only non-empty string notes of a release, in order | empty lines are noise | Should | Test: H case 1; U `Notes_keep_only_non_empty_strings_in_order`, `Notes_that_are_not_a_list_become_an_empty_list`, `Missing_notes_are_an_empty_list` |
| APPVER-R11 | WHEN the catalog has an `announcement` with a non-empty string `id` and `title` THEN the system SHALL add it with `body` as the string given, else ""; a null, absent or malformed one SHALL be left out, not null | a new id is what makes the app show it again | Must | Test: H case 3; U `A_valid_announcement_is_added_after_the_platforms`, `A_missing_or_malformed_announcement_is_left_out_not_null`, `An_announcement_body_that_is_not_a_string_becomes_empty` |
| APPVER-R12 | The system SHALL ignore unknown keys, and when a key repeats SHALL use the last value | hand-edited files carry comments | Should | Test: U `Unknown_keys_are_ignored_and_the_last_duplicate_wins` |

## 4. Quality requirements (ISO/IEC 25010)
| ID | Characteristic | Requirement (measurable) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|---|
| APPVER-Q1 | Reliability | No input file makes the route answer anything but 200 | fail open | Must | Test: U (R2, R3, R8); the file read catches only IO and access errors |
| APPVER-Q2 | Compatibility | Byte-for-byte the same body as the PHP API for the shared synthetic catalog | store-live builds | Must | Demonstration: `tools/platform-contract.sh parity` and `dev`; checked once by comparing the two bodies with `cmp` |
| APPVER-Q3 | Security | The route returns only catalog contents (numbers, public URLs, release text); it reads no request input | it is public | Must | Inspection: `api/features/app-version/AppVersion.cs` |

## 5. Rules and permissions
None: public (`security: []`, reason in `domains/platform/CLAUDE.md`). No `access` check.

## 6. Interfaces
- **API:** `GET /app-version` (`spec/api.yaml`). **Setting:** `TSR_APP_VERSIONS_FILE` (path of the catalog; unset gives the fallback).
- **Events:** none.

## 7. Data
The catalog file, read on every request (no cache). No table, no PII. Changing it needs a deploy.

## 8. Decisions in force
| ID | Decision | Reason |
|---|---|---|
| APPVER-D1 | The catalog stays a file, as in PHP | parity first; a table is a later decision |
| APPVER-D2 | A JSON list counts as a usable catalog (it gives the fallback blocks) | PHP `is_array` accepts both; same answer either way |
| APPVER-D3 | JSON is written with unescaped slashes and non-ASCII characters (.NET "relaxed" escaping) | PHP `JSON_UNESCAPED_*`; `<`, `>`, `&` and ` ` may differ in bytes from PHP, never in meaning |

## 9. Known limitations, gaps and open questions
- **Test gaps:** the 1 MiB size cap of the catalog (APPVER-R2) has no test; an unreadable file (permissions) has none.
- PHP does not bound the file size; the new API does (a deliberate difference).
