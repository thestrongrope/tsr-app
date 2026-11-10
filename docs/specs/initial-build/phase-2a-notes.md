# Phase 2a notes: access to parity (2026-11-10)

## Built
`Permissions` (`CanAsync(caller, action, target)`, `ReachAsync`, `ForUserAsync`), pure rules in `AccessEngine`, `RuleMatcher`,
`PermissionSets`, `LegacyPermissions`; port `IClassScopes` with default `NoClasses`; tables (roles, permissions, role_permissions,
user_permissions + PHP's reason/revoked_by/revoke_reason, user_roles, class_access_rules + conditions); the three routes; Hurl
contract (3 files, 77 requests) identical on PHP and the new API. Platform's feedback handler now asks `feedback:create`.

## Catalog: how derived, how to regenerate
Source of truth is tsr-account's migrations. The parity DB's reference seed (exported from PHP) lags them: 101 names, no
`quiz:reset:all`. `tools/access-catalog/export.sh` applies PHP's idempotent `2026_10_22_quiz_reset_permission.sql` to the parity DB,
dumps `permissions` and `role_permissions` (102 names; roles 1/3/4/5/7 = 38/18/18/13/1, as the recon says), fails if any name in
a PHP migration is missing from the dump, and prints SQL. That SQL is the body of migration `CatalogFromPhp`. When PHP adds
permissions: run it, diff, put only new rows in a NEW migration. Order: ordinal (MariaDB order for these names, proven by Hurl).

## Decisions and assumptions (correct me)
1. **Role move.** `identity.users` has no role column: the first migration's `roleid` is dropped by identity's own migration, and the role
   lives in `access.user_roles` (no row means role 0; `user_id` is a plain id, no foreign key to identity). No migration reads another
   domain's table, so no data is copied; the production move fills both tables from PHP's one table (a later plan). `Caller` lost `RoleId`.
2. **Gender.** access needs no gender from identity: PHP derives the gender scope from the role (3 gents, 4 ladies), never
   `users.gender`. Nothing added to `Caller`; `users.gender` stays for membership (phase 3).
3. **Port shape.** `IClassScopes`: `MembershipsAsync(token)` (taught, MCQ-flagged, enrolled active class ids), `ActiveClassAsync(id)`,
   `ActiveClassesAsync()` (rules are matched in access, so the matching rules stay here). Unbounded by class count; fine at TSR size.
4. A database error is a 500 (PHP denies and logs). Unknown action throws (PHP too).
5. All three routes use `RequireMember(createsMember: true)` as PHP's `api_authenticate(true)`.
6. `/user/permissions` class facts come from the port, not PHP's own counts (see capability, section 9).
7. Public types added (PublicSurfaceTests): AccessTarget, Reach, UserAccess, AccessScopes, IClassScopes, ClassMemberships, ClassFacts.
8. TDD honesty: the engine tests and implementation were written in one pass and first ran green; I proved the tests bite by
   mutating `AssignedGenders` (the quirk test failed). The db tests also first ran green. Not the strict red-first order.

## Quirks
Tested as "Quirk": assigned-scope gender check; inactive class refused with scope all; legacy derived roles grant nothing.
Not in access, reported: token 1001 (only `models/classes.php`, a classes rule); `'1'` vs `'Male'` (`genderOf` in
entityaccess/classaccess serves membership and class-access management; access's `can()` never reads it; a test pins that the
gender scope comes from the role).

## Recon unknowns
The 5 `unknown` cells (children.php row filtering) were not resolved: they are model SQL outside the permission engine.

## Not done
Grant and rule admin routes; class-dependent paths against PHP (fixtures have no classes; unit tested only); web/Flutter untouched.

## Commands
`tools/access-contract.sh dev|parity`; fixtures: `db/synthetic/seed.sql` (dev) and the same script (PHP, which also asserts no
fixture touches a class). Hurl cannot compare array literals: lists are asserted by count plus index.
