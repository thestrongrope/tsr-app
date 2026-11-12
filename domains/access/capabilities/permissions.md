# Permissions (who may do what)

Owner domain: `access` · Status: built (engine, the three read routes, the grant and class access routes)

## 1. Purpose
Every handler asks `access` what the caller may do, so a rule is enforced on the server and never only in an app.
The app also reads the caller's own permissions to show or hide screens, keeps that answer, and asks again only when its revision has moved.

## 2. Actors and scope
- **Actors:** member, gender admin, class coordinator, super admin, finance; any domain's handler.
- **In scope:** roles, the permission catalog, named grants, scopes, class access rules (tables and matching), `can`/reach/`forUser`, the three read routes (with the navigation facts and the revision of `GET /me/permissions`), the grant and class access routes.
- **Out of scope:** class facts (`classes`, behind `IClassScopes`), sign-in (`identity`).

## 3. Requirements (current behaviour)
| ID | Requirement (EARS) | Rationale | Priority | Verification |
|---|---|---|---|---|
| PERM-R1 | The system SHALL give every registered member (token above 0) the 21 member-set permissions. | Parity with PHP. | Must | Test: `domains/access/api/domain/PermissionSets.Tests.cs`; `AccessEngine.Tests.cs` `A_member_holds_the_member_set_and_nothing_else` |
| PERM-R2 | The system SHALL add the role's grants and the user's live named grants, and drop names the catalog lacks. | Parity. | Must | Test: `db/tests/AccessTests.cs` `A_live_named_grant_is_held_and_a_revoked_one_is_not`; `AccessEngine.Tests.cs` |
| PERM-R3 | WHILE a user teaches an active class or holds an MCQ flag, the system SHALL add the own set; WHILE they teach, also the taught set. | Parity. | Must | Test: `AccessEngine.Tests.cs` `The_own_set_is_held...`, `The_taught_set_is_held_only_while_teaching...` |
| PERM-R4 | WHEN a check has no target, the system SHALL allow it if the action is held at any scope. | Parity. | Must | Test: `AccessEngine.Tests.cs` `No_target_allows...` |
| PERM-R5 | WHEN a check names a class, the system SHALL allow it only if the class is active and a held scope covers it. | Parity. | Must | Test: `AccessEngine.Tests.cs` class-target tests |
| PERM-R6 | WHEN a check names a gender or a teacher gender, the system SHALL allow it by the scope rules (all both, gender the admin's, assigned the assigned classes' genders; teacher rule widened). | Gender segregation. | Must | Test: `AccessEngine.Tests.cs` gender tests |
| PERM-R7 | The gender scope SHALL come from the role (3 gents, 4 ladies), never from the profile gender. | Parity. | Must | Test: `AccessEngine.Tests.cs` `A_gender_admin_role_gives_the_gender_scope`, `...not_the_profile_gender` |
| PERM-R8 | The system SHALL answer a list's reach (all, gender, class ids) from the all, gender and assigned scopes only. | Parity (managedReach). | Must | Test: `AccessEngine.Tests.cs` `Reach_reports...` |
| PERM-R9 | A class access rule SHALL reach the active classes matching its gender and conditions (ORed within a field, ANDed across fields, negations exclude, missing values fail a negation, text ignores case). | Parity. | Must | Test: `RuleMatcher.Tests.cs` |
| PERM-R10 | IF the caller is a guest (token 0), THEN the system SHALL hold nothing for them. | Parity. | Must | Test: `db/tests/AccessTests.cs` `A_guest_holds_nothing...`; Hurl `me-permissions.hurl` (guest 403) |
| PERM-R11 | IF a handler asks about an action the catalog lacks, THEN the system SHALL throw. | A caller bug must not look like a refusal. | Must | Test: `db/tests/AccessTests.cs` `CanAsync_for_an_unknown_action_throws...` |
| PERM-R12 | WHEN a signed-in caller requests `GET /me/permissions`, the system SHALL return exactly six members: version 5, `issued_at`, the permissions in catalog order, the scopes, `navigation` and `revision`, identical to PHP apart from the time. | The app reads it. | Must | Test: Hurl `me-permissions.hurl` (PHP and new API); `db/tests/AccessTests.cs` `Me_permissions_has_PHPs_keys_with_a_null_gender_and_a_microsecond_issued_at` |
| PERM-R13 | WHEN a caller requests `GET /me/permissions/{permission}`, the system SHALL return the scopes held, or 404 `Unknown permission`. | Parity. | Must | Test: Hurl `me-permission.hurl` |
| PERM-R14 | WHEN a caller requests `GET /user/permissions`, the system SHALL return PHP's legacy answer, including that the derived roles grant no pages. | The router still reads it. | Must | Test: Hurl `user-permissions.hurl`; `LegacyPermissions.Tests.cs` |
| PERM-R15 | IF a member with `permissions:manage` grants a named permission to themself, THEN the system SHALL refuse with 422 `You cannot grant a permission to yourself`, after the permission check and before any write, with no event. | Owner decision 12 Nov 2026 (stricter than PHP). | Must | Test: `db/tests/TestGrantsTests.cs` `A_grant_to_oneself_is_refused_with_422_and_writes_no_row_and_no_event`; Hurl `admin-permission-self-new-api.hurl` |
| PERM-R16 | IF an operator who is not a super admin adds a class access rule to, or removes one from, a member who holds the super admin or a gender admin role, THEN the system SHALL refuse with 403 `You do not have permission to do that`, both before and again inside the member lock. | Owner decision 12 Nov 2026. | Must | Test: `TestGrantsTests.cs` `A_gender_admin_cannot_add_a_rule_to_or_remove_a_rule_from_a_gender_admin_or_a_super_admin`, `A_super_admin_may_add_a_rule_to_a_gender_admin_and_remove_a_rule_it_did_not_grant`; Hurl `class-access-peers-new-api.hurl`, `class-access-revoke-new-api.hurl` |
| PERM-R17 | IF an operator who is neither a super admin nor the one who granted a class access rule removes it, THEN the system SHALL refuse with 403 `You do not have permission to do that`. | Owner decision 12 Nov 2026. | Must | Test: `TestGrantsTests.cs` `A_rule_may_be_removed_only_by_the_operator_who_granted_it_or_a_super_admin`; Hurl `class-access-revoke-new-api.hurl` |
| PERM-R18 | The system SHALL report `navigation.classes` true when the member attends, teaches, owns or is assigned an active class, or holds `classes:read` for a gender or for every class, and `navigation.manage` true when they hold one of the 18 admin module permissions (broadcast, send and syllabus update only at scope `all`). | The app's tab bar and router read the two facts instead of deriving them from scopes. | Must | Test: `domains/access/api/domain/PermissionsSnapshot.Tests.cs` navigation tests; `AccessTests.cs` `Me_permissions_says_which_tabs_the_member_has`, `Every_admin_module_permission_is_an_action_of_the_catalog`; Hurl `me-permissions.hurl` |
| PERM-R19 | The system SHALL give `revision` as 16 lowercase hex characters that change when the version, the permissions, the scopes or the navigation change, and at no other time (not with `issued_at`, not with a revoked row, not with a rule that reaches no class). | The app refetches only when the revision it saved differs. | Must | Test: `PermissionsSnapshot.Tests.cs` revision tests; `db/tests/TestGrantsTests.cs` `The_revision_changes_with_a_grant_and_returns_with_its_revoke`, `The_revision_changes_with_the_role`, `The_revision_changes_with_a_class_access_rule_that_reaches_a_class_and_not_with_one_that_reaches_none` |
| PERM-R20 | WHEN `GET /me/permissions` answers 200 or 304, the system SHALL send `ETag` (the revision in double quotes), `Cache-Control: private, no-cache` and `Vary: Authorization`. | One member's answer: no shared cache may keep it, and the app may still ask conditionally. | Must | Test: `AccessTests.cs` `Me_permissions_carries_its_revision_as_the_ETag_and_is_private_to_the_member`; Hurl `me-permissions.hurl` |
| PERM-R21 | WHEN `If-None-Match` names the current tag (alone, in a comma-separated list, marked weak with `W/`, or as `*`), the system SHALL answer 304 with no body; any other value gets the full answer. | Saves the body when nothing changed. | Must | Test: `domains/access/api/features/me-permissions/MePermissions.Tests.cs`; `AccessTests.cs` `Me_permissions_is_304_with_no_body_when_If_None_Match_names_the_tag`, `Me_permissions_is_the_full_answer_when_If_None_Match_names_another_tag`; Hurl `me-permissions.hurl` |
| PERM-R22 | IF a member's permissions cannot be loaded (the database fails while they are resolved), THEN `GET /me/permissions` and the three named-grant routes that show a member's view SHALL answer 503 `Permissions could not be loaded. Try again.`, with no ETag, never 304 and never an empty answer. | Unknown must not look like "holds nothing": the app would hide every screen. | Must | Test: `AccessTests.cs` `Me_permissions_is_503_with_no_ETag_when_the_permissions_cannot_be_loaded_even_for_a_matching_tag`; `TestGrantsTests.cs` `The_grant_routes_are_503_when_the_members_permissions_cannot_be_loaded` |

## 4. Quality requirements
| ID | Characteristic | Requirement | Rationale | Priority | Verification |
|---|---|---|---|---|---|
| PERM-Q1 | Reliability | A database failure SHALL surface as an error, never as a silent deny or allow: 503 on the routes of PERM-R22, 500 on a permission check. | PHP's check denies and logs; a hidden failure is worse. | Must | Inspection: `Permissions.cs`; Test: as PERM-R22 |
| PERM-Q2 | Maintainability | Decision rules SHALL be testable without a database. | Fast tests. | Should | Test: `domains/access/api/tests` |

## 5. Rules and permissions
The three read routes need a sign-in only. Gender segregation is a scope applied by each domain to its own data (`ReachAsync`).

## 6. Interfaces
- **Code:** `Permissions` (`CanAsync`, `ReachAsync`, `ForUserAsync`) and the port `IClassScopes`. Navigation and revision: `api/domain/PermissionsSnapshot.cs` (no database).
- **API:** `spec/api.yaml`; contract in `spec/tests/`.
- **Events:** the four grant and rule events listed in `domains/access/CLAUDE.md`.

## 7. Data
Schema `access`: `roles`, `permissions`, `role_permissions`, `user_permissions`, `user_roles`, `class_access_rules`, `class_access_rule_conditions`. Rows reference users by id or token only; no personal data.

## 8. Decisions in force
| ID | Decision | Reason |
|---|---|---|
| PERM-D1 | Classes reach access through one port, `IClassScopes`; the default answers "no classes". | `classes` depends on access; the port breaks the cycle. |
| PERM-D2 | Catalog ordering is ordinal; the catalog is a PHP copy (`tools/access-catalog/export.sh`). | Equals MariaDB's order for these names. |
| PERM-D3 | Quirks are copied, each with a test named Quirk. | Parity first; fixes are separate changes. |
| PERM-D4 | The grant and class access routes are stricter than PHP in the three ways of PERM-R15 to R17 (findings 10 and 11). Their Hurl cases that pin PHP are in `*-php-only.hurl` files, the new behaviour in `*-new-api.hurl`. | Owner decision, 12 Nov 2026. |
| PERM-D5 | The revision is PHP's value for the same answer: the first 16 hex characters of the sha256 of the compact JSON `{navigation, permissions, scopes, version}` with keys sorted (PHP `json_encode`). Two values computed by PHP are pinned in `PermissionsSnapshot.Tests.cs`. | The app compares the revision it saved from `GET /me/permissions` with PHP's `X-Permissions-Revision` header on other responses, and the gateway sends some paths to PHP and some here; different values would make it refetch on every call. |

## 9. Known limitations, gaps and open questions
- PHP now sends `X-Permissions-Revision` (the member's revision) on every signed-in response of every route. The new API does not: it is one filter for all domains, outside `access` (owner decision pending). Until then the app learns of a change only from `GET /me/permissions`.
- The revision's JSON equals PHP's only while permission names are plain ASCII without `/` (PHP and .NET escape other characters differently); `AccessTests.cs` `Catalog_names_are_plain_so_the_revision_equals_PHPs` guards it.
- Class-dependent paths (own, taught, enrolled, assigned with real classes) are unit tested but not yet proven on PHP: the contract fixtures have no classes.
- `/user/permissions` class counts come from the port (active, current); PHP counts every row. Equal while there are no classes; revisit in phase 3.
- Accent-insensitive text matching of rule values (MariaDB collation) is not copied; `classes` decides.
