# Lane access: notes for the test phase

Ten admin routes of the access domain, ported from PHP (build-out mode: no Hurl, no database tests, nothing run against a stack). PHP files: `routes/permission_grants.php` (PG),
`routes/class_access.php` (CA), `models/permissiongrants.php` (PGM), `models/classaccess.php` (CAM). All ten routes are `create` in the catalog (PHP calls `api_authenticate(true)`).

## Routes

| # | Route | PHP | Slice (`domains/access/api/features/`) | Reads | Writes |
|---|---|---|---|---|---|
| 1 | GET /admin/permissions/members | PG:71, PGM::searchMembers | `admin-permission-members` | `membership.v_members`, `identity.v_users` | none |
| 2 | GET /admin/permissions/members/{token} | PG:80, PGM::forMember | `admin-permission-member` | v_members, `access.permissions`, `role_permissions`, `user_permissions`, `user_roles`, class facts (through the engine) | none |
| 3 | POST /admin/permissions/members/{token}/grants | PG:88, PGM::grant | `admin-permission-grant` | as 2 | `access.user_permissions` (+ outbox `access.permission_granted`) |
| 4 | POST /admin/permissions/grants/{id}/revoke | PG:108, PGM::revoke | `admin-permission-revoke` | `user_permissions`, `identity.v_users` | `user_permissions` (+ `access.permission_revoked`) |
| 5 | GET /admin/class-access/members | CA:206, CAM::searchMembers | `class-access-members` | v_members | none |
| 6 | GET /admin/class-access/members/{token} | CA:218, CAM::forMember | `class-access-member` | v_members, `class_access_rules`, `..._conditions`, `user_roles`, `IClassScopes.ActiveClassesAsync` | none |
| 7 | GET /admin/class-access/options | CA:229 | `class-access-options` | `classes.v_class_levels` (new), `IClassScopes` | none |
| 8 | POST /admin/class-access/preview | CA:253, CAM::preview | `class-access-preview` | as 7 | none |
| 9 | POST /admin/class-access/members/{token}/rules | CA:272, CAM::grant | `class-access-grant` | as 6 | `class_access_rules`, `class_access_rule_conditions`, `user_roles` (role 0 to 5) (+ `access.class_access_rule_created`) |
| 10 | POST /admin/class-access/rules/{id}/revoke | CA:297, CAM::revoke | `class-access-revoke` | as 6 | `class_access_rules`, `user_roles` (role 5 to 0) (+ `access.class_access_rule_revoked`) |

Shared code (`api/domain/`): `GrantRules` (pure), `PermissionGrants` (the member view), `AdminMembers` (find, search, gender text), `ClassAccessRules` (pure), `ClassAccessInput`
(request shapes), `ClassAccessOperator` (who may do what), `ClassAccessStore` (reads, the member view, the saved answer), `ClassAccessMessages`, `MemberLock`, `Refusal`.
Other changes: view `classes.v_class_levels` (migration `20261112110000_ClassLevelsView`, listed in classes' CLAUDE.md); `ClassFacts` of the port gained `Code` and `Name` (defaults, so existing callers compile), filled by
`classes/api/ClassScopes.cs`; `Permissions.Forget(userId)`.

## The `UPDATE users` strings in PHP (answered)

- `UPDATE users SET roleid = roleid WHERE id = ?` (CAM::lockedMember) is a pure row lock, the first statement of the write transaction. Replaced by `pg_advisory_xact_lock(6001, token)` (`MemberLock`, 5 second lock timeout), registered in `domains/access/CLAUDE.md`.
- `UPDATE users SET roleid = 5 WHERE id = ? AND roleid = 0` (writeGrant) and `... SET roleid = 0 WHERE ... roleid = 5 AND NOT EXISTS (live rule)` (writeRevoke) change the member's role. Here the role is `access.user_roles` (no row = role 0): grant inserts `(user_id, 5)` when there is no row; revoke deletes the row when it is role 5 and no live rule is left.
- There is NO stored version. `version` is `roleid + ':' + first 16 hex of sha256(sorted live rule ids joined by ',')` (CAM::versionOf), recomputed on every read and write. Ported as `ClassAccessRules.VersionOf`. Nothing was missing, so routes 9 and 10 are built.

## Rules ported exactly

Permissions (PG/PGM)
- Guard on every route: signed in (401), `permissions:manage` with no target (403, detail "Only super admins can manage permissions"). Only role 1 holds `permissions:manage:all`.
- Grantable = catalog names whose last `:` part is `all`, not held in any way (role, live grant, the member set), and not one of `permissions:manage:all`, `class-access:manage:all`, `members:enrol-by-token:all`. A held name is 409 even when excluded (PHP order: grantable list first, then held, else 422).
- The client's permission text is only compared with the catalog, never passed to `CanAsync` (an unknown action would throw).
- Reason: trimmed, 1 to 300 code points (422). A reason of the wrong JSON type is 422 "reason must be text". The grant checks the member (404) AFTER the reason, then grantability, then (in the transaction) a live duplicate (409). `granted_by`/`revoked_by` are the caller's user id. Revoke: 404 unknown grant (also when its user has no `identity.v_users` row), 409 already revoked (read, and again on the update).
- Member search: needs 2 or more code points; matches lower(name), lower(email), mobile (LIKE, `!` escape), or the token for an all-digit term; at most 20; `order by name, token`; name and token only.

Class access (CA/CAM)
- Guard on every route: signed in (401), `class-access:manage` with no target (any scope), 403 "You do not have permission to do that". Scope `all` (super admin) manages both genders; scope `gender` (role 3 or 4) only their own (the engine decides, `can()` with a gender target).
- `mayManage(gender)`; `mayManageRule(g)`: g null needs both genders. `guardOperator(member, ruleGender)`: (1) the member's token is the operator's token: 422 "You cannot change your own access"; (2) the rule's gender not manageable: 403 "This member belongs to the other gender"; (3) the member's gender (`genderOf`: 1, '1', 'Male' is 1; 2, '2', 'Female' is 2; anything else is unknown) unknown or not manageable: 403. So a gender admin can only give or remove rules of their own gender on members of their own gender; a rule of either gender, and a member with no recorded gender, are super admin only (a member with no gender is not even viewable by a gender admin).
- City, country and tag values must be ones the operator is OFFERED (the values of the active classes of the genders they manage, case-insensitive, then given the offered spelling): 422 "Choose a city from the list". Levels are not restricted by gender (any existing level), but the rule's gender restricts what it reaches.
- Conditions of a new rule: at least one; fields `city`, `country`, `level`, `tag` (case-sensitive); `negate` must be false; level a positive whole number that exists (422 "Unknown level"); text values collapsed (`\s+` to one space), trimmed, 1 to 300 code points; repeats dropped (case-insensitive key), ordered naturally by the key; at most 50 per field.
- Write transaction (9): lock, member read again (404), `guardOperator` again, then `version` (409 `member_changed`), role 7 Finance (422), same gender and condition set already live (409 `already_has_access`), reaches no class (422), `previewHash` differs (409 `preview_changed` with `classes` (at most 200), `classCount`, `previewHash`). Then the rule (note built from the conditions, `granted_by`, reason) and conditions are inserted, and a role-0 member becomes role 5 (roles 1, 3, 4, 5, 6 stay).
- Revoke (10): reason 422; rule or its member missing 404 "Rule not found"; `guardOperator(member, rule's gender)`; already removed 409; transaction: lock, member again, guard again, `version` (409), update `where revoked_at is null` (409 if 0 rows), role 5 to 0 when no live rule is left.
- Views (6 and the write answers): only rules whose gender the operator manages are listed, but the `version` covers ALL live rules. `fromRole` is "Every class" or "Classes of their own gender" from the member's `classes:read` reach, else null. Classes per rule come from `RuleMatcher` (the engine's matcher, one code path) over `IClassScopes.ActiveClassesAsync`; at most 200 listed, the count is the total. After a commit, a view that cannot be read still answers `{saved: true, member: null, version: null, fromRole: null, rules: []}`.
- Write answers: a database failure before the commit is 500 `{"detail": "Nothing was changed"}` (PHP).
- The preview hash: first 16 hex (lower case) of sha256 of the sorted class ids joined by `,`, over ALL reached classes. Compared in constant time.

## Assumptions

1. A: member lookup by token takes the lowest user id when two members share a token (PHP: whichever row the database returns).
2. A: the permission cache is per request (`Permissions` is scoped). Every write here ends with the view of the member, so `Forget(member)` runs before it reads; no other cache exists. PHP reads live rows every time, so the effect is the same.
3. A: the grant route takes the same member lock (class 6001) as class access. PHP has no lock there, so two grants at once can both insert; here they cannot. Stricter, not looser.
4. A: datetimes are sent as `Y-m-dTH:i:s` in UTC (PHP sends the server's local time). Check against the parity database timezone.
5. A: `Cast.Text` keeps PHP's quirk that an empty non-nullable `text` field becomes the number 0 (a member with an empty name, a permission with no description). Check against the parity fixtures.
6. A: ordering by `name, token` and the sort of cities (ASCII case-insensitive) uses PostgreSQL's and .NET's order, not MariaDB's collation; accents and NULL names may order differently. Offered values are de-duplicated ordinal-first-wins, then capped at 500 before de-duplication.
7. A: natural ordering of conditions is a small `strnatcmp` approximation (digit runs compare as numbers); it only affects the stored order and the value order inside a note.
8. A: matching uses the engine's ordinal ignore-case comparison, so `Zurich` and `Zürich` are different (the known open difference in `domains/access/CLAUDE.md`); the preview, the stored rule views and the engine agree with each other.
9. A: a rule gender of 3 or a gender above int range is the 422 range message; a level above int range is "Unknown level".
10. A: `q` containing a NUL byte is 422 "q must be text" (PHP finds nobody); a reason or note with a NUL byte is 422 (PHP stored it).
11. A: the `ActiveClassesAsync` port returns at most 10000 classes (the classes domain's cap); a preview or view over more would be wrong. There are about a few hundred classes today.
12. A: a lock timeout or any database error before the commit on the two class access writes is 500 "Nothing was changed"; on the permission writes it is the host's default 500.

13. A: `db/tests/PublishedViewsTests.cs` lists the published views; `classes.v_class_levels` is not in that list yet (not edited in build-out mode). The API role reads it through the schema's default privileges.
14. A: the engine's `Permissions.LiveRulesAsync` does not lower-case a stored condition `field`, but the rule views here do (the column is citext). A migrated row stored as `City` would show classes in the view that the engine does not grant. Not fixed (engine, not this lane); check the migrated data.

## Flags: anything that looks like an escalation or privacy hole (copied, not fixed)

1. **A super admin can grant any grantable permission to themselves or to anyone, with no role hierarchy and no cap on how many.** Grantable is every unheld `:all` permission except three. That includes every other powerful `:all` permission (for example `donors:read:all`, `registrations:*:all`, report reads, `quiz:admin:all`). It is by design (super admin only), but one stolen or mis-assigned super admin session is the whole catalog.
2. **The three excluded names are held by name, not by purpose.** A different permission that lets a member grant themselves access (none is known) would bypass the exclusion list; the list was not audited for others.
3. **A held excluded name answers 409 "already holds", an unheld one 422 "cannot be granted".** This tells a super admin which of the three a member holds; harmless, copied.
4. **A gender admin can add and remove rules on ANOTHER class admin or gender admin of their own gender**, including another gender admin's own scope grants only through rules; the only self-guard is the operator's own token. Copied.
5. **Level conditions are not restricted by gender or city.** A gender admin can give a member of their gender a rule `gender: own, level: 3` that reaches every class of level 3 of their gender in every city. The "offered" restriction covers city, country and tag only. Copied.
6. **Role change as a side effect.** The first rule turns a role-0 member into class admin (role 5) with its role permissions (`role_permissions` of role 5); removing the last rule turns them back to 0. A member who also holds role 6 or 1 is untouched. Anything that sets `user_roles` by another route (identity, a future admin route) while rules exist is not reconciled here. The role-5 permissions are what a rule-less member must NOT hold; the test phase should check what role 5 grants.
7. **Revoke authority is by gender of the rule AND member, but not by who granted it.** Any operator of the right gender can remove a rule another operator gave; a super admin can remove anything.
8. **Member search (permissions) matches email and mobile**, so a super admin can confirm whether an address or number belongs to a member (only name and token come back). Super admin only; copied.
9. **Revoke of a grant by id leaks the existence of grant ids** (404 vs 409) to a super admin only. Harmless.
10. **Revoke of a grant for a user with token 0 commits and then answers 404 "Member not found"** (PHP quirk, the view is read by token).
11. **Error detail of the class access screens reveals the other gender** ("This member belongs to the other gender", also for a member with no recorded gender): an operator learns the gender of any token by trying it. Copied.
12. **The preview answers class codes and names of classes of the operator's genders only** (a rule of either gender needs both genders), so no leak across genders for a gender admin; but a level or tag with no class of the operator's gender is not offered, while a level can still be typed by id (a level id existence oracle). Copied.
13. **`version` is a fingerprint, not a lock.** Two operators loading the same version race; the member lock plus the version check settles it (the second gets 409 `member_changed`). A role change by another route changes the version (the role id is in it), a changed gender does not.
14. **The preview hash proves "the same classes", not "the same rule".** Between the preview and the grant the operator can still change `reason`, and (within the same reached classes) nothing else; the grant recomputes the reach from the rule it is given, so a client that previews rule A and grants rule B reaching the same class set is accepted. Copied.

## What the test phase must prove

Tick each with a Hurl file (against PHP and the new API) or a database test.

Permissions
- [ ] 401 without sign-in; 403 for every non-super-admin (member, gender admin, class admin, finance) on all four routes, with the detail "Only super admins can manage permissions".
- [ ] A `permissions:manage` GRANT to a member never works: `permissions:manage:all`, `class-access:manage:all`, `members:enrol-by-token:all` are 422; a scope other than `all` is 422; an unknown name is 422; a held permission is 409; a name sent with a path-like or very long text is 422 (never 500, never a thrown "unknown permission").
- [ ] A grant takes effect at once (`GET /me/permissions` of the member shows it) and a revoke removes it at once; `granted_by` and `revoked_by` are the operator; the reason is stored trimmed; a 301-character reason, an empty reason, a reason with a NUL byte, a number as the reason are 422.
- [ ] Two grants of the same permission at once: one 200, one 409, one row.
- [ ] A revoked grant cannot be revoked again (409); an unknown or huge id is 404; the member view of a guest token (0), a negative token and a text token are 404.
- [ ] Search: under 2 characters is empty; `%` and `_` match themselves; a NUL byte is 422; at most 20 rows; no email or mobile in the answer.
- [ ] Outbox: exactly one `access.permission_granted` or `access.permission_revoked` row per success, none per refusal, ids and tokens only.

Class access
- [ ] **An operator cannot widen their own reach:** a gender admin and a super admin changing their own token (grant and revoke) get 422 "You cannot change your own access", and nothing is written.
- [ ] **A gender admin cannot reach the other gender:** a rule of the other gender, a rule of either gender (null), a member of the other gender, a member with no recorded gender, are 403 on preview, grant and revoke, and the member view; the rules list for a gender admin never shows a rule of either gender; the options list shows only the operator's genders and only cities, countries and tags of their classes.
- [ ] A city, country or tag the operator is not offered is 422 (also for a value that exists only in the other gender's classes); a value is stored with the offered spelling; a NOT IN (`negate: true`) condition is 422; an unknown field (also `City`) is 422; a level that does not exist is 422; 51 values for one field is 422; a level as text is 422; `gender` 0, 3, 1.5, a string are 422.
- [ ] A rule that reaches no class is 422 and writes nothing; the same gender and condition set twice is 409 `already_has_access`; a Finance member is 422; a stale `version` is 409 `member_changed`; a changed class set is 409 `preview_changed` with the new classes, count and hash; a wrong or missing `previewHash` or `version` is 422/409, never a write.
- [ ] After a grant the member has role 5 (`GET /me` roleid) and the rule shows in `GET /me/permissions` scopes; the matched classes of the view equal what the engine's `assigned` scope gives (one matcher). After the last revoke the member is back to role 0; a member with role 3, 4, 1 or 6 keeps it through both.
- [ ] Two operators granting or revoking at once on one member: one succeeds, the other 409 `member_changed` (the lock), one rule row only; a lock wait over 5 seconds is a 500 "Nothing was changed" and nothing was written.
- [ ] `granted_by`, `revoked_by`, the reason (300 limit, NUL byte 422) are stored; the note reads like "Gents, levels 3-5, Pune"; one outbox row per success (`access.class_access_rule_created` / `_revoked`), none per refusal.
- [ ] The view after a write matches `GET /admin/class-access/members/{token}`; the 200-class cap with `classCount` the total; the preview hash is the same for the same class set in any order.
- [ ] The same Hurl files give the same status and body on PHP and the new API (parity), except the documented differences: datetime time zone, name ordering for non-ASCII, `Zürich` versus `Zurich`.
- [ ] Security review: every SQL here is parameterised (no string building); regex digits are `[0-9]`; no member contact detail in any answer or log; the log lines carry only the exception type.
