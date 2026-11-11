# domains/access/

AuthZ: what a caller may do, and in which scope. Parity first: PHP's `PermissionsModel` is copied as it behaves,
quirks included (facts: `docs/specs/initial-build/phase-2-permissions-recon.md`, `permission-map.csv`; notes and gaps:
`phase-2a-notes.md`). Capability: `capabilities/permissions.md`.

## Status

| Part | State |
|---|---|
| Interface `Permissions`: `CanAsync(caller, action, target)`, `ReachAsync(caller, action)` (managedReach, searchReach, genderLock, assignedOnlyIds in one `Reach`), `ForUserAsync(caller)`, `RoleIdAsync(caller)` (the role id for GET /me) | built; `api/Permissions.cs`, rules in `api/domain/AccessEngine.cs` |
| Catalog (102 permissions, 7 roles, role grants), seeded from PHP | built; migration `CatalogFromPhp`; regenerate: `tools/access-catalog/export.sh` |
| User roles (`access.user_roles`), named grants, class access rules (tables) | built; nothing writes grants or rules yet (PHP serves the admin routes) |
| Class access rule matching (`RuleMatcher`) | built, unit tested; has no classes to match until `classes` exists |
| Port `IClassScopes` (default `NoClasses`) | built; `classes` supplies the real one in phase 3 |
| Routes `GET /me/permissions`, `GET /me/permissions/{permission}`, `GET /user/permissions` | built; Hurl contract proven identical on PHP |
| Grant and rule admin routes, `permissions:manage`, `class-access:manage` | not started; PHP serves them |

## Owns

- Schema `access`: `roles`, `permissions`, `role_permissions`, `user_permissions` (named grants), `user_roles` (one row per
  user whose role is not 0; `user_id` is a plain id, no foreign key to identity), `class_access_rules` and `class_access_rule_conditions`.
- The three constant sets (`api/domain/PermissionSets.cs`: member 21, own 8, taught 2).
- Dependencies: none (`AccessModule.Dependencies`). Every other domain lists `access`. The one thing flowing the
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
means deny" is not copied, a database error is a 500.

## Quirks kept on purpose (each has a test named Quirk)

Assigned scope passes a gender check for every gender the user has an assigned class in; a class target is refused
when the class is inactive, even with scope `all`; the legacy `/user/permissions` lists the two derived roles but never
grants their pages. Not in access: token 1001 is always an eligible teacher (`classes.php`, a classes rule) and
`users.gender` holding `'1'` and `'Male'` (membership; access never reads it).

## Known open difference

Rule text (city, country, tag) matches ordinal ignore-case; PHP's `LOWER()=LOWER()` under MariaDB's accent-insensitive collation
also treats `Zürich` and `Zurich` as equal. Not built; settle it when `classes` is built and class fixtures exist
(`docs/specs/initial-build/php-parity-feedback.md`). A class two rules reach is listed twice in `assigned`, as PHP's view does.

## Where things are

| Need | File |
|---|---|
| The interface and loader | `api/Permissions.cs`, `api/AccessTypes.cs` |
| Decision rules, no database | `api/domain/AccessEngine.cs`, `RuleMatcher.cs`, `PermissionSets.cs`, `LegacyPermissions.cs` |
| The classes port | `api/IClassScopes.cs` |
| Tables, migrations | `api/AccessContext.cs`, `api/Migrations/` |
| Words, contract, behaviour | `spec/glossary.md`, `spec/api.yaml`, `spec/tests/*.hurl` |

## Checks

```
dotnet test domains/access/api/tests       # rules, no database
dotnet test db/tests                       # catalog, stored roles and grants, the three routes (Docker)
tools/access-contract.sh dev               # Hurl contract on the dev stack
tools/access-contract.sh parity            # the same files on PHP (parity stack up, tools/parity-php/README.md)
```

## Placeholders

Operations of this domain not built yet are 501 placeholders in `api/Planned.cs` (after the sign-in check; they create nothing). Building one deletes its line there and flips its state in `docs/specs/initial-build/operations.csv`.
