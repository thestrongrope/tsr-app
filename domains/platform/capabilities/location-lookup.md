# Location lookup (country list, postal code, city search)

Owner domain: `platform` · Status: live (a small synthetic data set; the full GeoNames load is not built)

<!-- Living document: describes TODAY. Rewrite in every PR that changes behaviour. Template: docs/templates/capability.md -->

## 1. Purpose
While a member fills in their location, the app offers the country list, fills State and a suggested City from a postal
code, and suggests cities as they type. The data is public GeoNames data, never member data.

## 2. Actors and scope
- **Actors:** a signed-in member (a guest finishing sign-up included once registered), no permission needed.
- **In scope:** `GET /geo/countries`, `POST /geo/postal`, `POST /geo/cities`; the per-member rate limit.
- **Out of scope:** checking a saved profile against the list (membership); loading the full GeoNames data.

## 3. Requirements (current behaviour)
`G` = `db/tests/GeoTests.cs` (real database); `U` = `api/domain/<Name>.Tests.cs`; `H` = `spec/tests/geo-countries.hurl`, `geo-postal.hurl`, `geo-cities.hurl` (PHP parity stack and dev stack, same rows).

**Common**

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| GEO-R1 | IF the caller is not signed in THEN the system SHALL return 401 with a `{"detail"}` body before anything else | identity's middleware | Must | Test: H case 1 of each file; G `Without_sign_in_every_route_is_401` |
| GEO-R2 | WHEN a member has made 60 geo calls in the last 60 seconds THEN the system SHALL answer the next with 429 `Too many lookups; try again in a minute`; every call counts, including one that later fails validation, but a refused call does not extend the wait | stops scripts, not typists | Must | Test: U `MemberRateLimit` (shared/api) `Sixty_calls_in_a_minute_are_allowed_and_the_61st_is_refused`, `A_call_is_allowed_again_exactly_one_window_after_the_first_but_not_a_second_earlier`, `The_window_slides_so_only_calls_older_than_a_window_are_forgotten`, `A_refused_call_is_not_counted_so_it_does_not_extend_the_wait`; G `The_61st_call_in_a_minute_is_a_429_with_the_php_detail` |
| GEO-R3 | The 429 SHALL come after the sign-in check and before body validation | PHP order | Must | Test: G `Calls_that_fail_validation_count_and_the_429_comes_before_body_validation` |
| GEO-R4 | Each member SHALL have a separate count | one member must not block another | Must | Test: U `MemberRateLimit` `Each_member_has_their_own_count`; G `One_members_limit_does_not_affect_another` |
| GEO-R5 | IF a geo table is missing THEN the system SHALL log it and answer with no rows (empty list, found false), not an error; any other database error SHALL be an error | a profile can still be saved as plain text | Should | Test: G `A_missing_geo_table_gives_an_empty_answer_not_an_error` |

**GET /geo/countries**

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| GEO-R6 | WHEN a member asks THEN the system SHALL return `{"countries": [{code, name, hasPostalCodes}]}` for every country, sorted by name ignoring case and accents, `hasPostalCodes` a real boolean | the country picker | Must | Test: H geo-countries case 2; G `Countries_sort_ignoring_case_and_accents_and_carry_a_real_boolean` |

**POST /geo/postal**

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| GEO-R7 | IF the body is not a JSON object or list (not valid JSON, a scalar, null) THEN the system SHALL return 422 `Invalid JSON body`; an empty body, an empty list or a missing field SHALL be the field's 422 | PHP `api_body` | Must | Test: U `GeoBody` tests; G `A_bad_postal_body_is_a_422_with_the_php_detail`; H geo-postal case 14 |
| GEO-R8 | IF `country` is not a string, is blank after trim, or is longer than 2 code points counted before the trim THEN the system SHALL return 422 `country is required and must be at most 2 characters`; THEN the same for `code` (20), `query` (100) with their names; country is checked first | PHP `api_geo_text` | Must | Test: U `GeoField` tests, `PhpText` tests; G `A_bad_postal_body_is_a_422_with_the_php_detail`, `A_query_over_100_characters_is_a_422_and_exactly_100_is_accepted`; H geo-postal case 3, 13; geo-cities case 12 |
| GEO-R9 | WHEN country and code are valid THEN the system SHALL upper-case both (ASCII only) and look up the code whole, then (if it holds an ASCII space) the part before the first space; the first hit wins; matching ignores case and accents | UK outward codes | Must | Test: U `GeoLookupTests` `A_code_with_a_space_is_tried_whole_then_by_the_part_before_the_first_space`, `Only_an_ascii_space_splits_a_code`; G `Postal_codes_are_found_like_the_php_lookup`; H geo-postal cases 2 to 8 |
| GEO-R10 | The system SHALL NOT look up a code of exactly "0" | PHP `array_filter` quirk | Must | Test: U `A_code_of_exactly_zero_is_never_tried_because_php_array_filter_drops_it`; H geo-postal case 11 |
| GEO-R11 | WHEN a code is found THEN the system SHALL return `{found: true, city, state}` with the stored strings (an empty string stays empty; only a missing value is null); WHEN not found, or the country is unknown, THEN `{found: false, city: null, state: null}` | the app fills State and a suggested City | Must | Test: G `Postal_codes_are_found_like_the_php_lookup`; H geo-postal cases 9, 10, 12 |

**POST /geo/cities**

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| GEO-R12 | WHEN country and query are valid THEN the system SHALL return the cities of that country whose name starts with the query, ignoring case and accents, with `\|`, `%` and `_` in the query taken literally | autocomplete | Must | Test: U `The_like_pattern_escapes_the_pipe_percent_and_underscore_and_adds_a_trailing_percent`; G `Cities_match_a_prefix_ignoring_case_and_accents_and_take_wildcards_literally`; H geo-cities cases 2, 3, 6, 7 |
| GEO-R13 | The system SHALL order matches by population descending then name, return at most 10, and return the same name once per state | the biggest city first | Must | Test: G `Cities_are_ordered_by_population_and_the_same_name_is_returned_once_per_state`, `Cities_return_at_most_ten`; H geo-cities cases 4, 5, 9, 10 |
| GEO-R14 | The system SHALL decode HTML entities in `name` and `state`, return a missing or empty `state` as null, and return a name that is empty as the number 0 | stored text may be HTML-escaped; PHP `api_cast` | Must | Test: U `GeoLookupTests` `Html_entities_are_decoded_like_php`; G `Cities_decode_entities_and_turn_an_empty_or_null_state_into_null`; H geo-cities case 8; empty name: none yet (section 9) |
| GEO-R15 | An unknown country or no match SHALL give `{"cities": []}` | not an error | Must | Test: G case "XX"; H geo-cities case 11 |
| GEO-R16 | IF a geo request body is larger than 16 KiB THEN the system SHALL return 413 `Request body too large` | bounded input (PHP has no limit: a deliberate difference) | Should | Test: G `A_body_over_the_size_limit_is_a_413` |

## 4. Quality requirements (ISO/IEC 25010)
| ID | Characteristic | Requirement (measurable) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|---|
| GEO-Q1 | Compatibility | The Hurl files give the same results on PHP and on the new API | store-live builds | Must | Demonstration: `tools/platform-contract.sh parity` and `dev` |
| GEO-Q2 | Performance | The largest country's prefix search (30,000 rows) takes about 12 ms on PostgreSQL 18; postal lookup and country sort use indexes | the app calls it on each keystroke | Should | Analysis: `docs/specs/initial-build/phase-3-collation-proof.md` |
| GEO-Q3 | Security | Queries are parameterised; a member's input is never joined into SQL; the data is public | CODING-GUIDELINES | Must | Inspection: `api/features/geo-*/` |
| GEO-Q4 | Reliability | The rate limit table forgets members idle for a window, so memory is bounded | no unbounded state | Must | Test: U `Members_who_stopped_calling_are_forgotten_so_memory_stays_bounded` |

## 5. Rules and permissions
Any signed-in member; no permission, no scope (geo data is public). Sign-in creates the member row on first call, as PHP does.

## 6. Interfaces
`GET /geo/countries`, `POST /geo/postal`, `POST /geo/cities` (`spec/api.yaml`). The lookups are POSTs so that what a member types stays out of access logs. No events.

## 7. Data
Tables `geo_countries`, `geo_postal_codes`, `geo_cities` (platform, schema `platform`), read only at run time. No PII. The name and postal code columns use
the collation `geo_ci_ai` (decision GEO-D1). GeoNames data is CC BY 4.0: credit it wherever the data shows.

## 8. Decisions in force
| ID | Decision | Reason |
|---|---|---|
| GEO-D1 | One ICU collation (`und-u-ks-level1`, nondeterministic) on `geo_countries.name`, `geo_postal_codes.postal_code`, `geo_cities.name` instead of citext | MariaDB ignored accents as well as case; proof in `docs/specs/initial-build/phase-3-collation-proof.md`; the guard test lists the exception |
| GEO-D2 | The rate limit is in memory, per process | simplest; weaker with several API instances (each would allow 60) |
| GEO-D3 | A missing geo table is logged and answered as empty; other database errors are errors | PHP swallowed every database error; only the one deliberate case is kept |
| GEO-D4 | Body limit 16 KiB | bounded input |

## 9. Known limitations, gaps and open questions
- **Test gaps:** GEO-R14 for a name that is empty (the number 0) has no test.
- **Differences from PHP:** a trailing space in a postal code is not ignored in the database (input is trimmed, so unreachable); HTML5-only entity names beyond the common ones are not decoded; the body limit; non-"missing table" database errors are errors; level-equal names (Köln, Koln) have no defined relative order on either engine.
- **Not built:** the full GeoNames loader; checking a saved profile against the lists.
