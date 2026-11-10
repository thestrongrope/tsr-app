# Permissions (who may do what)

Owner domain: `access` · Status: partial (engine and read routes live; grant and rule administration still in PHP)

## 1. Purpose
Every handler asks `access` what the caller may do, so a rule is enforced on the server and never only in an app.
The app also reads the caller's own permissions to show or hide screens.

## 2. Actors and scope
- **Actors:** member, gender admin, class coordinator, super admin, finance; any domain's handler.
- **In scope:** roles, the permission catalog, named grants, scopes, class access rules (tables and matching), `can`/reach/`forUser`, the three read routes.
- **Out of scope:** granting or revoking permissions and rules (PHP routes, later), class facts (`classes`, behind `IClassScopes`), sign-in (`identity`).

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
| PERM-R12 | WHEN a signed-in caller requests `GET /me/permissions`, the system SHALL return version 4, `issued_at`, the permissions in catalog order and the scopes, identical to PHP. | The app reads it. | Must | Test: Hurl `me-permissions.hurl` (PHP and new API) |
| PERM-R13 | WHEN a caller requests `GET /me/permissions/{permission}`, the system SHALL return the scopes held, or 404 `Unknown permission`. | Parity. | Must | Test: Hurl `me-permission.hurl` |
| PERM-R14 | WHEN a caller requests `GET /user/permissions`, the system SHALL return PHP's legacy answer, including that the derived roles grant no pages. | The router still reads it. | Must | Test: Hurl `user-permissions.hurl`; `LegacyPermissions.Tests.cs` |

## 4. Quality requirements
| ID | Characteristic | Requirement | Rationale | Priority | Verification |
|---|---|---|---|---|---|
| PERM-Q1 | Reliability | A database failure SHALL surface as an error (500), never as a silent deny or allow. | PHP denies and logs; a hidden failure is worse. | Must | Inspection: `Permissions.cs` |
| PERM-Q2 | Maintainability | Decision rules SHALL be testable without a database. | Fast tests. | Should | Test: `domains/access/api/tests` |

## 5. Rules and permissions
The three routes need a sign-in only. Gender segregation is a scope applied by each domain to its own data (`ReachAsync`).

## 6. Interfaces
- **Code:** `Permissions` (`CanAsync`, `ReachAsync`, `ForUserAsync`) and the port `IClassScopes`.
- **API:** `spec/api.yaml`; contract in `spec/tests/`.
- **Events:** none.

## 7. Data
Schema `access`: `roles`, `permissions`, `role_permissions`, `user_permissions`, `user_roles`, `class_access_rules`, `class_access_rule_conditions`. Rows reference users by id or token only; no personal data.

## 8. Decisions in force
| ID | Decision | Reason |
|---|---|---|
| PERM-D1 | Classes reach access through one port, `IClassScopes`; the default answers "no classes". | `classes` depends on access; the port breaks the cycle. |
| PERM-D2 | Catalog ordering is ordinal; the catalog is a PHP copy (`tools/access-catalog/export.sh`). | Equals MariaDB's order for these names. |
| PERM-D3 | Quirks are copied, each with a test named Quirk. | Parity first; fixes are separate changes. |

## 9. Known limitations, gaps and open questions
- Class-dependent paths (own, taught, enrolled, assigned with real classes) are unit tested but not yet proven on PHP: the contract fixtures have no classes.
- `/user/permissions` class counts come from the port (active, current); PHP counts every row. Equal while there are no classes; revisit in phase 3.
- Accent-insensitive text matching of rule values (MariaDB collation) is not copied; `classes` decides.
