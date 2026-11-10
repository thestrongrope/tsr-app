# Member profile (read and update)

Owner domain: `membership` · Status: live (parity with PHP; the search touch and the gender lock's classes half are not built)

<!-- Living document: describes TODAY. Rewrite in every PR that changes behaviour. Template: docs/templates/capability.md -->

## 1. Purpose
A member sees and edits their own profile in the app: name, gender, age range, mobile number, place, language and postal code. The
profile is what the rest of the system knows about a person; classes are gender-segregated, so the gender is locked while a member is
enrolled.

## 2. Actors and scope
- **Actors:** a signed-in member with a token above 0 (a guest is refused by `identity` before these routes run).
- **In scope:** `GET /me`, `PATCH /me`.
- **Out of scope:** the name and picture written at sign-in (`ProfileSink`, `identity` calls it); the staff routes that read other members; erasure on account deletion (identity's command is not built).

## 3. Requirements (current behaviour)
`D` = `db/tests/ProfileTests.cs` (real database, limited role); `U` = `api/domain/<Name>.Tests.cs`; `H` = `spec/tests/profile-get.hurl`, `profile-update.hurl` (PHP parity stack and dev stack, same fixture members).

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| PROF-R1 | IF the caller is not signed in THEN the system SHALL return 401 with a `{"detail"}` body; IF the member lacks `profile:read` (GET) or `profile:update` (PATCH) THEN 403 `You do not have permission to do that` | identity and access order | Must | Test: H case 1 of each file; 403: none (section 9) |
| PROF-R2 | WHEN a member asks for their profile THEN the system SHALL return the sixteen fields `id, token, email, name, roleid, picture, gender, age_range, mobile, country, state, city, language, zip, sendupdates, unsubscribe`, in that order | the Dart `User` model | Must | Test: D `A_member_gets_the_sixteen_fields_of_the_wire_contract_in_order`; H profile-get 2 |
| PROF-R3 | WHILE an account deletion is pending the system SHALL still answer GET, and SHALL answer PATCH with 403 `Account deletion pending` and `deletion_status` | the member must be able to see and cancel | Must | Test: D `A_pending_account_deletion_still_lets_the_member_read_but_not_change_their_profile` |
| PROF-R4 | The system SHALL show a member with no profile row PHP's column defaults (empty mobile as null, language 0, `sendupdates` and `unsubscribe` "N") and SHALL NOT create a row on a read | PHP's `users` row always exists | Must | Test: D `A_member_with_no_profile_row_shows_PHPs_defaults_and_a_role_of_zero` |
| PROF-R5 | The system SHALL cast as PHP's `api_cast`: `name` is the integer 0 when null or empty; `gender` and `age_range` are the int of a numeric text and null otherwise (so "Male", "Female" and "" are null, never 0); `mobile, country, state, city, zip` are entity-decoded and empty is null; `picture` and the two flags are not decoded, empty is null; `language` 0 stays 0 | the app crashes on a wrong type | Must | Test: U `ProfileViewTests`; D `Text_fields_are_entity_decoded_the_picture_is_not_and_an_empty_name_is_zero`, `A_gender_that_is_not_a_number_reads_as_null`; H profile-get 2 to 5 |
| PROF-R6 | WHEN a PATCH body names none of the nine updatable keys (a list, an empty body and unknown keys included) THEN the system SHALL answer 200 with the current profile and SHALL validate nothing | PHP returns before validating | Must | Test: D `A_body_with_no_updatable_key_is_a_200_with_the_current_profile_and_nothing_is_validated`; H profile-update 3 |
| PROF-R7 | IF the body is not a JSON object or list THEN the system SHALL return 422 `Invalid JSON body`; a body over 1 MiB SHALL be 413 | PHP `api_body`; bounded input | Must | Test: U `JsonBodyTests`; D `A_body_that_is_not_an_object_or_list_is_a_422_Invalid_JSON_body`; H profile-update 2 |
| PROF-R8 | WHEN fields are sent THEN the system SHALL validate them in the order name, gender, age_range, mobile, country, state, city, language, zip, return the first error as 422 with PHP's text, and write nothing; a null value is not validated | PHP `api_validate_profile_field` | Must | Test: U `ProfileFieldsTests`; D `The_first_invalid_field_in_PHPs_order_is_a_422_and_nothing_is_written`; H profile-update 4, 5 |
| PROF-R9 | The system SHALL NOT validate `age_range` at all and SHALL store any value as its string cast | PHP has no rule | Must | Test: U `ProfileFieldsTests.Age_range_and_unknown_fields_are_never_validated`; H profile-update 7 |
| PROF-R10 | WHEN `state` or `city` changes (compared trimmed with the stored value) and holds a Unicode digit THEN 422 `State cannot contain numbers` / `City cannot contain numbers`; WHEN `country` changes, is not in the country list and the list is loaded THEN 422 `Choose your country from the list`; WHEN `zip` changes and looks like an email or a phone number THEN 422 `That does not look like a postal code. Leave it empty if you do not have one.`, unless the country's own regex or a held postal code vouches for it. First problem in that order wins | old saved values keep saving | Must | Test: U `PlaceRulesTests`; D `A_state_or_city_with_a_digit_is_refused_but_only_when_it_changed`, `A_country_must_be_from_the_list_when_the_list_is_loaded_and_anything_goes_when_it_is_not`, `A_zip_that_looks_like_an_email_or_a_phone_number_is_refused_unless_the_country_vouches_for_it`; H profile-update 6 (the vouching cases: D only, the geo fixtures hold no regex that vouches) |
| PROF-R11 | WHEN `zip` or `country` was sent non-null, the zip is not empty, and the zip or the country changed THEN the system SHALL replace `state` and `city` with the postal code's non-empty values (the text "0" counts as empty), whatever was sent | the code is the better source | Must | Test: D `A_new_postal_code_we_hold_overwrites_state_and_city_whatever_was_sent`, `A_postal_code_with_no_change_leaves_the_typed_state_and_city_and_an_empty_postal_city_is_not_used`; H profile-update 11, 12 |
| PROF-R12 | IF the member is enrolled in a class, the stored gender is 1 or 2, and the gender sent (int cast, null is 0) differs THEN the system SHALL return 422 `Gender cannot be changed while you are enrolled in a class` and log `profile.gender_change_refused` | the member could switch, join the other gender's class and switch back | Must | Test: U `GenderLockTests` (fake classes port); D `A_member_enrolled_in_a_class_cannot_change_gender_but_can_repeat_it`, `A_member_whose_gender_is_not_set_may_set_it_even_when_enrolled`; H: none (no classes yet) |
| PROF-R13 | WHEN the update is valid THEN the system SHALL store the values as sent (untrimmed, entities not decoded, the member's row created on the first write) and answer 200 with the re-read profile | PHP stores what it receives | Must | Test: D `A_valid_update_stores_the_values_as_sent_untrimmed_and_answers_with_the_new_profile`, `A_member_with_no_profile_row_gets_one_on_their_first_write`, `A_name_with_entities_is_stored_raw_and_answered_decoded`; H profile-update 7, 10 |

**Quirks copied on purpose** (each also in `docs/specs/initial-build/php-parity-feedback.md`, "Membership batch 3b-2"):

| ID | Quirk | Verification |
|---|---|---|
| PROF-Q1 | A name, city, state or country is stored with its spaces; only validation trims | D `A_valid_update_stores_...`; H profile-update 7 |
| PROF-Q2 | `gender` is stored as the text of what was sent: "1abc" validates (its int is 1), is stored as "1abc" and reads back as null; 1.9 and `true` are stored as "1.9" and "1" and read back as 1 | D `PDO_style_casts_apply_...`; H profile-update 8 |
| PROF-Q3 | A non-string value is validated and stored as its string cast: `true` is "1", an array is "Array" (PHP also prints a warning into the body on its test stack, which is not copied) | U `PhpValueTests`, `ProfileColumnsTests` |
| PROF-Q4 | `language` goes to an integer column: 2.5 or "2.5" is stored as 3 (the database rounds), " 2" is 2, "2abc" refuses the write (500) | U `ProfileColumnsTests`; D `A_decimal_language_is_rounded_by_the_database_and_text_that_is_not_a_number_is_a_500` |
| PROF-Q5 | `mobile: null` passes validation and the NOT NULL column refuses it: 500 and nothing is saved | D `A_null_mobile_passes_validation_then_the_not_null_column_refuses_it_a_500_as_in_PHP_and_nothing_is_saved` |
| PROF-Q6 | A name of 51 or more characters is refused, but a long run of spaces around a short name is not (the length is counted after trim) | U `ProfileFieldsTests.A_text_field_longer_than_fifty_characters_after_trimming_is_refused` |
| PROF-Q7 | A mobile number or zip ending in a newline passes (PCRE's `$`) | U `ProfileFieldsTests` |

## 4. Quality requirements (ISO/IEC 25010)
| ID | Characteristic | Requirement (measurable) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|---|
| PROF-Q8 | Compatibility | The two Hurl files give the same results on PHP and on the new API | store-live builds | Must | Demonstration: `tools/membership-contract.sh parity` and `dev` |
| PROF-Q9 | Security | Every query is a prepared statement (EF); the update's column set is a fixed list; the postal regex (from the database) runs with a 250 ms timeout; the 16 fields never include another member's data | CODING-GUIDELINES | Must | Inspection: `api/features/profile-update/`, `api/domain/PlaceRules.cs` |
| PROF-Q10 | Reliability | The request reads at most 1 MiB; a refusal writes nothing | bounded work | Must | Test: D `The_first_invalid_field_in_PHPs_order_is_a_422_and_nothing_is_written` |

## 5. Rules and permissions
`profile:read:self` and `profile:update:self` (the member set, every member with a token above 0). No gender scope: a member only ever touches their own row.

## 6. Interfaces
- **API:** `GET /me`, `PATCH /me` (`spec/api.yaml`; gateway `location = /me`).
- **Uses:** `UserDirectory` (identity: email), `Permissions.RoleIdAsync` (access: `roleid`), `Geo` (platform: country, postal code), `IClassEnrolments` (the classes port, default "not enrolled").
- **Events:** none. PHP queues a search reindex (`outbound_messages`, channel search) when name or gender changes: deferred (section 9).

## 7. Data
Table `membership.member_profiles` (one row per member, keyed by identity's user id, no foreign key). PII: name, gender, age range, mobile, place, picture. Erasure on account deletion: not built (identity's deletion command does not exist).

## 8. Decisions in force
| ID | Decision | Reason |
|---|---|---|
| PROF-D1 | `gender` stays PHP's raw text so all five PHP readings of it (card, placement, children list, lock, `/me`) stay identical | parity first; normalising is a separate change |
| PROF-D2 | The gender lock reads the caller's own profile by user id; PHP reads `users` by token, first row | a shared token is rare and the caller's own row is the one being changed |
| PROF-D3 | The `Geo` and `Lookups` interfaces hold primitives; the personal-data rule is here, in `PlaceRules` | the rule belongs to this operation, not to the data |

## 9. Known limitations, gaps and open questions
- **Search touch deferred:** PHP queues `outbound_messages` (search channel, `person:<token>`) when name or gender is sent non-null; the table does not exist in the new database and search is not built.
- **Gender lock, classes half:** proven with a fake port only; no Hurl case until `classes` supplies `IClassEnrolments`.
- **Permission 403:** the member set gives every member both permissions and nothing can deny them, so the 403 is not provable end to end.
- **PHP's 500s** (mobile null, language "2abc", an array in a text column) render on the parity stack as HTTP 200 with PHP's error text, so they are proven in `db/tests` only.
- **Not copied:** PHP's warning text inside the body for array values; the exact text of floats in exponent form (PHP `1.0E+25`, here `1E+25`).
- **Entity decoding** uses .NET's table (HTML 4 plus `&apos;`); PHP knows all HTML5 names, so an obscure name stays as written here.
