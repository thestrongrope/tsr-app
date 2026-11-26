# domains/access/

AuthZ: what a caller may do, and in which scope. Parity first: PHP's `PermissionsModel` is copied as it behaves,
quirks included (facts: `docs/specs/initial-build/phase-2-permissions-recon.md`, `permission-map.csv`; notes and gaps:
`phase-2a-notes.md`). Capability: `capabilities/permissions.md` (requirements PERM-R1 to R25, each with its test).

## Status

Every operation is built (no `api/Planned.cs`). Each slice's header comment names its route; shapes: `spec/api.yaml`.

| Part | State |
|---|---|
| Interface `Permissions`: `CanAsync(caller, action, target)`, `ReachAsync(caller, action)` (managedReach, searchReach, genderLock, assignedOnlyIds in one `Reach`), `ForUserAsync(caller)`, `RoleIdAsync(caller)` (the role id for GET /me) | built; `api/Permissions.cs`, rules in `api/domain/AccessEngine.cs` |
| Catalog (102 permissions, 7 roles, role grants), seeded from PHP | built; migration `CatalogFromPhp`; regenerate: `tools/access-catalog/export.sh` |
| User roles (`access.user_roles`), named grants, class access rules (tables) | built; written only by the ten admin routes below |
| Class access rule matching (`RuleMatcher`) | built, unit tested; has no classes to match until `classes` exists |
| Port `IClassScopes` (default `NoClasses`) | built; `classes` supplies the real one (`ClassFacts` also carries code and name, for the class access screens) |
| Read routes `GET /me/permissions` (PHP's version 5), `GET /me/permissions/{permission}`, `GET /user/permissions` | built (slices `me-permissions`, `me-permission`, `user-permissions`) |
| Grant routes (`permissions:manage`): member search, member view, grant, revoke; class access routes (`class-access:manage`): member search, member view, options, preview, grant a rule, revoke a rule | built (slices `admin-permission-*`, `class-access-*`); notes `docs/specs/initial-build/lane-access-notes.md`, `test-grants-notes.md` |
| Header `X-Permissions-Revision` on signed-in responses | built, database tested, Hurl cases not yet run |
| Data access | converted (issue 99): plain SQL through the data source (`Sql`, `DbTx`, `DbRow`, `shared/api`), no Entity Framework call at run time; `AccessContext` and `Migrations/` stay for the migrate job (`AccessModule.AddAccessMigrations`, called by the host in migrate mode only) |

## Owns

- Schema `access`: `roles`, `permissions`, `role_permissions`, `user_permissions` (named grants), `user_roles` (one row per
  user whose role is not 0; `user_id` is a plain id, no foreign key to identity), `class_access_rules` and `class_access_rule_conditions`.
- The three constant sets (`api/domain/PermissionSets.cs`: member 21, own 8, taught 2).

## Dependencies

None (`AccessModule.Dependencies`); the admin routes read `membership.v_members`, `identity.v_users` and `classes.v_class_levels` in SQL only (published views), and classes through the port. Every other domain lists `access`. The one thing flowing the
other way is the port `IClassScopes`, which `classes` implements: it is the only interface between domains that
would otherwise form a cycle. Do not add another.

## How a check works

An action is `resource:action` (no scope). The caller holds names from: the member set (token above 0), the role's
`role_permissions`, live named grants (`revoked_at` null), the own set (teaches or MCQ-flagged an active class), the
taught set (teaches one), all intersected with the catalog. Scopes: `all`, `gender` (role 3 gents, 4 ladies, never
the profile gender), `assigned` (class access rules), `own`, `taught`, `enrolled`, `self`. No target: any held scope
allows. Class target: the class must be active, then any scope matching. Gender target: `all` both, `gender` the
admin's, `assigned` any gender of an assigned class, others none. Teacher gender: widened (ladies in the set gives
both). A guest (token 0) holds nothing. An unknown action throws (a bug in the caller); PHP's "storage unreadable
means deny" is not copied, a database error is a 500. The exception: the routes that show a member what they hold
(`GET /me/permissions`, the named-grant member view, grant and revoke) answer 503 `Permissions could not be loaded. Try again.`
as PHP does (`Permissions.ForUserOrUnavailableAsync`, the route filter `AnswersUnavailable`).

## The answer of GET /me/permissions (version 5)

`navigation`, `revision`, the ETag and the 304: capability PERM-R12 and R18 to R22, decision PERM-D5; the pure rules are in
`api/domain/PermissionsSnapshot.cs`. The revision must stay PHP's value for the same answer: the gateway sends some paths to PHP and some here.

## The header X-Permissions-Revision (every domain's signed-in responses)

`api/PermissionsRevisionHeader.cs`, middleware the host adds with `app.UsePermissionsRevision()` right after `app.UseIdentity()`
(the rule is here; the host has that one line). What it promises: capability PERM-R23 to R25, PERM-D6, PERM-Q3. What an agent must know beyond that:

- No header: a request refused at sign-in (401, `User not found`,
  `Registration incomplete`, `Account deletion pending`, recently deleted, a `precheck:` refusal), a route without `RequireMember`
  (public reads, `/health`, `/auth/debug-token`), and permissions that cannot be loaded (logged as a warning; the request goes on). An unhandled error (500) has no header.
- Cost: the request's one resolution, 2 commands (PHP: 7): one on access's tables (role, catalog, stored names, whether a live class
  access rule exists: `Permissions.StoredAsync`) and one through the port (`IClassScopes.MembershipsAsync`); a member with class access
  rules pays 4 more (rules, conditions, active classes and their tags). Paid on every signed-in request and kept by `Permissions`, so the route's own
  checks read nothing again; a route that checks no permission pays it only for the header, as in PHP.
- Because that resolution is
  kept, a route that changes what its caller holds and then asks `Permissions` about the caller must call `Permissions.Forget` first
  (the grant routes do).

Tests: `db/tests/PermissionsRevisionHeaderTests.cs`.

## Quirks kept on purpose (each has a test named Quirk)

Assigned scope passes a gender check for every gender the user has an assigned class in; a class target is refused
when the class is inactive, even with scope `all`; the legacy `/user/permissions` lists the two derived roles but never
grants their pages. Not in access: token 1001 is always an eligible teacher (`classes.php`, a classes rule) and
`users.gender` holding `'1'` and `'Male'` (membership owns it; the admin routes read it from `membership.v_members` and map it with `AdminMembers.GenderOf`).

## Stricter than PHP, on purpose (owner decision)

Three rules, capability PERM-R15 to R17 and PERM-D4: a grant to oneself is 422 (`admin-permission-grant`); only a super admin changes the class access rules of a super admin or gender admin; a rule is removed only by who granted it or a super admin (`ClassAccessOperator.GuardAsync`, `RevokeGuardAsync`). Hurl cases that pin PHP's
looseness are in `*-php-only.hurl`, the new rules in `*-new-api.hurl` (`admin-permission-self`, `class-access-peers`, `class-access-revoke`); `tools/contract-grants.sh` runs each kind on its own side only.

## Known open difference

Rule text (city, country, tag) matches ordinal ignore-case; PHP's `LOWER()=LOWER()` under MariaDB's accent-insensitive collation
also treats `Zürich` and `Zurich` as equal. Not built; settle it when `classes` is built and class fixtures exist
(`docs/specs/initial-build/php-parity-feedback.md`). A class two rules reach is listed twice in `assigned`, as PHP's view does.

## Where things are

| Need | File |
|---|---|
| The interface and loader | `api/Permissions.cs`, `api/AccessTypes.cs` |
| The revision header on signed-in responses | `api/PermissionsRevisionHeader.cs`, `AccessModule.UsePermissionsRevision` |
| Decision rules, no database | `api/domain/AccessEngine.cs`, `RuleMatcher.cs`, `PermissionSets.cs`, `LegacyPermissions.cs`, `PermissionsSnapshot.cs` (navigation, revision) |
| The classes port | `api/IClassScopes.cs` |
| Tables, migrations (the migrate job only; no run-time code names the context, `hosts/api/tests/RunTimeEfUseTests.cs`) | `api/AccessContext.cs`, `api/Migrations/`, `AccessModule.AddAccessMigrations` |
| Data access: `NpgsqlDataSource` or `DbTx` (a read route opens a short transaction; no path holds two connections) | `api/Permissions.cs`, `api/domain/PermissionGrants.cs`, `AdminMembers.cs`, `ClassAccessStore.cs`, the writes in `features/*/` |
| JSON: answers `AccessJson.Answers` (the host's options, relaxed encoder), events `AccessJson.Default` | `api/domain/AccessJson.cs` |
| The grant and class access rules | `api/domain/GrantRules.cs`, `ClassAccessRules.cs` (no database), `ClassAccessStore.cs`, `ClassAccessOperator.cs`, `MemberLock.cs` |
| Words, contract, behaviour | `spec/glossary.md`, `spec/api.yaml`, `spec/tests/*.hurl` |
| Database tests | `db/tests/AccessTests.cs`, `TestGrantsTests.cs`, `PermissionsRevisionHeaderTests.cs`, `AccessRuleConditionTests.cs`, `AccessFailureTests.cs`, `AccessPoolTests.cs` |

## Checks

```
dotnet test domains/access/api/tests       # rules, no database
dotnet test db/tests                       # catalog, stored roles and grants, the routes (Docker)
tools/access-contract.sh test              # Hurl contract on the test stack (never dev: it may hold real data)
tools/access-contract.sh parity            # the same files on PHP (parity stack up, tools/parity-php/README.md)
tools/contract-grants.sh test              # the grant and class access routes (spec/tests/admin-permission-*.hurl, class-access-*.hurl); also parity
```

## Advisory locks

| Lock | Use |
|---|---|
| class 6001 (`pg_advisory_xact_lock(6001, token)`, `MemberLock`) | every write to one member's named grants, role or class access rules; PHP's `UPDATE users SET roleid = roleid` row lock. No other code may use class 6001. |

## Events

| Event | Payload | Written by |
|---|---|---|
| `access.permission_granted` | grantId, token, permission, grantedBy | POST /admin/permissions/members/{token}/grants |
| `access.permission_revoked` | grantId, token, permission, revokedBy | POST /admin/permissions/grants/{id}/revoke |
| `access.class_access_rule_created` | ruleId, token, gender, grantedBy | POST /admin/class-access/members/{token}/rules |
| `access.class_access_rule_revoked` | ruleId, token, revokedBy | POST /admin/class-access/rules/{id}/revoke |

Consumed: none. A write drops the member's cached answers (`Permissions.Forget`) before it answers with their refreshed view; the class access version is not stored (the member's role id and a fingerprint of their live rule ids).
