# Release notes

Owner domain: `platform` · Status: live

<!-- Living document: describes TODAY. Rewrite in every PR that changes behaviour. Template: docs/templates/capability.md -->

## 1. Purpose
The app's "what's new" screen lists every release with its notes. It reads the same catalog as the update prompt
(`app-version.md`), through the same rules, so the two cannot disagree.

## 2. Actors and scope
- **Actors:** the app (no sign-in needed).
- **In scope:** `GET /release-notes`. **Out of scope:** the update prompt; editing the catalog.

## 3. Requirements (current behaviour)
`U` = `api/domain/AppCatalog.Tests.cs`; `H` = `spec/tests/release-notes.hurl`. Catalog rules (which releases are valid, what notes keep) are APPVER-R8 to R10.

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| RELNOTES-R1 | WHEN anyone asks THEN the system SHALL return 200 `{"releases": [...]}` with the valid releases in the catalog's order, not sorted | "newest first" is the file's job | Must | Test: H case 1; U `The_release_list_keeps_the_file_order_and_is_not_sorted` |
| RELNOTES-R2 | Each release SHALL be `{version, date, notes, builds}`, in that key order, with `date` as written in the catalog | the app parses these | Must | Test: H case 1, 2; U `Notes_keep_only_non_empty_strings_in_order` |
| RELNOTES-R3 | The system SHALL keep in `builds` only integer builds, written android then ios; IF a release has none THEN `builds` SHALL be the empty list `[]`, not `{}` | PHP quirk, kept for parity | Must | Test: H case 3, 4; U `Builds_keep_only_integer_values_and_are_written_android_then_ios`, `A_build_that_is_not_an_integer_drops_that_platform_from_the_release_only`, `Builds_with_no_integer_are_written_as_an_empty_list_not_an_object` |
| RELNOTES-R4 | IF the catalog is missing, unreadable or malformed, or has no releases, THEN the system SHALL return `{"releases": []}` with 200 | never an error | Must | Test: U `A_missing_file_serves_the_fallback`, `A_catalog_without_releases_gives_an_empty_list`, `A_file_that_is_not_a_json_object_or_list_serves_the_fallback` |
| RELNOTES-R5 | The route SHALL need no sign-in | an old build may hold an expired token | Must | Test: H (no auth header in any case) |

## 4. Quality requirements (ISO/IEC 25010)
| ID | Characteristic | Requirement (measurable) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|---|
| RELNOTES-Q1 | Compatibility | Same body as the PHP API for the shared synthetic catalog | store-live builds | Must | Demonstration: `tools/platform-contract.sh parity` and `dev` |

## 5. Rules and permissions
None: public (`security: []`).

## 6. Interfaces
`GET /release-notes` (`spec/api.yaml`); setting `TSR_APP_VERSIONS_FILE`. No events.

## 7. Data
The catalog file only. No PII.

## 8. Decisions in force
| ID | Decision | Reason |
|---|---|---|
| RELNOTES-D1 | An empty `builds` stays `[]` (parity), not `{}` | changing it is a behaviour change for a separate PR; a typed client must read both shapes |

## 9. Known limitations, gaps and open questions
- Test gaps: none known.
