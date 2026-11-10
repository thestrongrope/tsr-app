# Class request form (registration)

Owner domain: `membership` · Status: live (parity with PHP)

<!-- Living document: describes TODAY. Rewrite in every PR that changes behaviour. Template: docs/templates/capability.md -->

## 1. Purpose
A member who wants to join classes fills in one form: where they live and work, birth year, years of Islamic study, education, field of study, courses, occupation, LinkedIn, languages and what they could help with. The form is saved so the member can return to it; coordinators read it to place the member (those operations are built with `classes`).

## 2. Actors and scope
- **Actors:** a signed-in member (token above 0); no permission is checked (PHP checks none), and each member only reads and writes their own rows.
- **In scope:** `GET /registration`, `POST /registration`.
- **Out of scope:** the waiting list, placing and rejecting a registration, the downloads (built with `classes`); erasure on account deletion.

## 3. Requirements (current behaviour)
`D` = `db/tests/RegistrationTests.cs` (real database, limited role); `U` = `api/domain/RegistrationForm.Tests.cs`, `RegistrationParts.Tests.cs`; `H` = `spec/tests/registration-get.hurl`, `registration-save.hurl` (PHP parity stack and dev stack).

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| REG-R1 | IF the caller is not signed in THEN the system SHALL return 401 with a `{"detail"}` body | identity | Must | Test: H case 1 of each file |
| REG-R2 | WHEN a member reads THEN the system SHALL return `{registration, interestOptions, selectedInterestIds, languages}`; `registration` is null when nothing is saved; `languages` is an object (`{}` when empty), `{language: {skill: proficiency}}` | the app pre-fills the form | Must | Test: D `A_member_with_nothing_saved_...`; H registration-get 2 to 4 |
| REG-R3 | The system SHALL answer `registration` from the first row of the member's token by id, with PHP's camelCase keys in PHP's order, raw values (not decoded), `fieldOfStudy` and `professionalCourses` as lists (empty when empty or invalid), `status` as stored, and no status reason | PHP's `fetch()` takes the first row | Must | Test: U `RegistrationPartsTests`; D `With_duplicate_rows_the_first_by_id_is_read_...`; H registration-get 2, 3 |
| REG-R4 | The system SHALL list the active interest options ordered by sort order then name, as `{id, name}` | the form's checkboxes | Must | Test: D `The_options_are_in_sort_order_then_name_and_inactive_ones_are_left_out`; H registration-get 2 (the whole order) |
| REG-R5 | IF `preferredLocation`, `birthYear` or `islamicStudyYears` is empty after trim THEN the system SHALL return 422 `preferredLocation, birthYear and islamicStudyYears are required` and write nothing; "0" study years are accepted | PHP's rule | Must | Test: U `RegistrationFormTests`; D `A_missing_required_field_is_a_422_and_writes_nothing`; H registration-save 2 |
| REG-R6 | IF the body is not a JSON object or list THEN 422 `Invalid JSON body` (before the required fields are read); a body over 1 MiB SHALL be 413 | PHP `api_body`; bounded input | Must | Test: D `A_body_that_is_not_an_object_or_list_is_a_422_Invalid_JSON_body`; H registration-save 3 |
| REG-R7 | The system SHALL trim every text, store an empty optional text as null, cast `birthYear` and `islamicStudyYears` as PHP's `(int)` with no range check, and keep a LinkedIn address only when it matches `https?://(www.)?linkedin.com/(in\|pub\|company)/<word>` ignoring case (ASCII), as typed | PHP's rules | Must | Test: U `RegistrationFormTests`; D `A_first_save_inserts_one_pending_row_...`; H registration-save 4, 5 |
| REG-R8 | The system SHALL keep a dropdown value (`education, occupationType, fieldOfWork, yearsExperience, roleLevel`) only when it equals an active lookup label exactly (case-sensitive), otherwise null, and SHALL keep in a multi-select (`fieldOfStudy, professionalCourses`) the trimmed values that are labels, in order, duplicates included, stored as JSON; none kept or not a list is null | the lists are platform's `lookups` | Must | Test: U `RegistrationFormTests`; H registration-save 4 |
| REG-R9 | WHEN the member has no row THEN the system SHALL insert one (status Pending); WHEN rows exist THEN it SHALL update every row of the token, set `for_classid`, `profession` and the legacy `interests` to null, set `modified_at`, and keep each status | PHP's UPDATE where token | Must | Test: D `A_first_save_inserts_...`, `A_save_updates_every_row_of_the_token_wipes_three_legacy_columns_and_keeps_the_status`; H registration-save 4, 7 |
| REG-R10 | WHEN `languages` is a non-empty array or object THEN the system SHALL delete the member's saved languages and insert the entries whose language, skill and proficiency are in PHP's lists (case-sensitive; "Don't Know" is skipped); an empty, null or non-array value SHALL leave them | PHP's guard | Must | Test: U `RegistrationPartsTests`; D `A_non_empty_languages_map_...`, `An_empty_or_missing_languages_value_leaves_the_saved_ones`; H registration-save 4 to 6 |
| REG-R11 | WHEN `interestIds` is an array (even empty) THEN the system SHALL delete the member's choices and insert, one at a time, the (int) of each element that is an active option; a missing or non-array value SHALL leave them | PHP's guard | Must | Test: U `RegistrationPartsTests`; D `Interest_ids_replace_the_choices_...`, `An_empty_interest_list_erases_...`; H registration-save 4 to 6 |
| REG-R12 | WHEN the form is saved THEN the system SHALL answer 200 `{"success": true, "message": "Class request submitted successfully"}` | the app reads it | Must | Test: D `A_first_save_inserts_...`; H registration-save 4 |

**Quirks copied on purpose** (also in `php-parity-feedback.md`, "Membership batch 3b-2"):

| ID | Quirk | Verification |
|---|---|---|
| REG-Q1 | The three writes are separate and unguarded: the form, then the languages, then the choices, with no transaction | D `A_duplicate_interest_id_is_a_500_...` |
| REG-Q2 | A duplicate id in `interestIds` breaks the unique key: 500 after the old choices were deleted and the first copy was inserted | D `A_duplicate_interest_id_is_a_500_after_the_old_choices_are_deleted_and_the_first_copy_is_kept_as_in_PHP` |
| REG-Q3 | A non-empty `languages` map of only invalid entries erases every saved language | D `A_non_empty_map_of_only_invalid_entries_erases_the_saved_languages`; H registration-save 6 |
| REG-Q4 | An update wipes `for_classid`, `profession` and the legacy `interests` set | D `A_save_updates_every_row_...` |
| REG-Q5 | `birthYear` "abc" is 0; a boolean or array in a text field is "1" or "Array"; a value outside the integer range is a 500 | U `RegistrationFormTests`; H registration-save 5 |
| REG-Q6 | An array inside a multi-select is a PHP `TypeError`: 500 | U `An_array_inside_a_multi_select_is_a_PHP_TypeError_so_it_throws` |
| REG-Q7 | A free text longer than its column is a database error: 500 (PHP's strict mode does the same) | none yet (section 9) |

## 4. Quality requirements (ISO/IEC 25010)
| ID | Characteristic | Requirement (measurable) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|---|
| REG-Q8 | Compatibility | Both Hurl files give the same results on PHP and on the new API | store-live builds | Must | Demonstration: `tools/membership-contract.sh parity` and `dev` |
| REG-Q9 | Security | Every query is a prepared statement (EF); a member only reaches rows of their own token | CODING-GUIDELINES | Must | Test: D `A_member_never_reads_or_writes_another_members_rows` |
| REG-Q10 | Reliability | Each list read is bounded (500 rows); the body is bounded (1 MiB) | bounded work | Must | Inspection: `api/features/registration-get/` |

## 5. Rules and permissions
None: PHP checks no permission here (a signed-in member with a token above 0 is enough).

## 6. Interfaces
- **API:** `GET /registration`, `POST /registration` (`spec/api.yaml`; gateway `location = /registration`).
- **Uses:** `Lookups` (platform: the seven option lists).
- **Events:** none.

## 7. Data
Tables `membership.class_registrations` (duplicates per token allowed, index on `token`, no unique key), `class_registrations_languages`, `interest_options` (19 seeded, 16 active), `student_interests` (unique per token and option). PII: location, birth year, LinkedIn, occupation. Erasure on account deletion: not built (PHP anonymises the registration, and leaves languages and choices: an open decision for the erasure handler).

## 8. Decisions in force
| ID | Decision | Reason |
|---|---|---|
| REG-D1 | Duplicates per token are kept; the read takes the lowest id, an update changes every row | PHP's table has no key; a unique key is a later, separate change |
| REG-D2 | `selectedInterestIds` is ordered by interest id (PHP has no ORDER BY) | a stable answer; the app treats it as a set |

## 9. Known limitations, gaps and open questions
- **Test gap:** REG-Q7 (a free text over its column length) has no test.
- **Unverified PHP edges:** a float in exponent form as text (`1.0E+25`) formats differently here.
