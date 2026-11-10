# Phase 2 design: access and identity (proposal, 2026-11-10)

For Asif to approve before any phase 2 build. Facts are from `phase-2-permissions-recon.md`,
`permission-map.csv` (211 operations over 191 paths) and `phase-2-identity-recon.md`, all read from
tsr-account's `develop` code. The aim is parity, so the shapes below copy PHP; they do not improve it.

## access

**Interface other domains call** (replaces today's `CanAsync(caller, name)`):

| Call | Copies PHP | Use |
|---|---|---|
| `CanAsync(caller, action, target)` | `can()` | allow or deny. `action` is `resource:action`; `target` is none, a class, a gender, or a teacher gender |
| `ReachAsync(caller, action)` | `managedReach`, `searchReach`, `genderLock`, `assignedOnlyIds` | what a list may show: all, one gender, or a set of class ids. The owning domain applies it to its own query |
| `ForUserAsync(caller)` | `forUser` | the permissions and scopes behind `GET /me/permissions` |

**What access owns:** roles, the 102 permission names, role permissions, individual grants, each
user's role, and the class access rules (city, country, level and tag conditions). The three PHP
constant sets (member, own class, taught class) become constants in `access`.

**The one hard part.** `can()` needs class facts: which classes a user teaches, is enrolled in or
is MCQ admin of, and each class's gender and status. Those tables belong to `classes`, and `classes`
itself depends on `access`. Proposed: `access` defines a small port, `IClassScopes`, and `classes`
supplies it. Until `classes` is built the port answers "no classes", which is true of the new API
today. So phase 2 builds the engine with role, grant and gender scopes; class targets arrive with
`classes` in phase 3. It is one interface, at a boundary between two domains that would otherwise
form a cycle.

Alternative: `classes` publishes a database view and `access` reads it. No interface, but a
cross-schema read that only a test could police. Not recommended.

## identity

- **Verify** the Firebase token with ASP.NET Core's built-in JWT bearer support against Google's
  keys (issuer, audience, subject, expiry), with an emulator mode set by configuration. To check:
  that it works with the NativeAOT build.
- **Find the user** by Firebase id, then by email (case-insensitive through `citext`), verified
  emails only; create the row on first sign-in as PHP does.
- **Reproduce every failure exactly:** 401 "Not authenticated", 401 "Invalid auth token", 404 "User
  not found", 403 "Registration incomplete", 403 for a deleted account, 403 "Account deletion pending".
- **Keep the write on every request** (last sign-in, IP, device, app version). PHP does it.
- The dev stack gets the same auth emulator as the parity stack, so one Hurl file signs in the same
  way on both sides. The dev-header verifier is then removed.

## The `users` table is split by owner

PHP has one `users` table for everything. One owner per table means:

| New table | Owner | Holds |
|---|---|---|
| `identity.users` | identity | id, token, Firebase id, email, sign-in tracking, deletion status |
| `access.user_roles` | access | the user's role |
| profile (name, gender, city ...) | membership, in phase 3 | everything else |

The data move joins them back from the one PHP table. API responses keep their shape.

## Quirks: copied as they are, listed for later

Parity first; each of these is a separate change after the baseline, never a silent fix now.

- With only `assigned` scope, a gender check passes for every gender the user has an assigned class in.
- `users.gender` holds both `'1'` and `'Male'`; some PHP code reads `'Male'` as 0.
- Token 1001 is always an eligible teacher.
- A class target is refused for an inactive class even with scope `all`.

## How parity is proven in phase 2

`GET /me/permissions` returns a user's permissions and scopes, so it shows the whole engine. Synthetic
users, one per role plus a guest and one with individual grants, are asked on PHP and on the new API;
the answers must be identical. The sign-in failures get one Hurl case each, run on both sides.

## Build tasks after approval

| Task | Who | Done when |
|---|---|---|
| 2a access engine, catalog seeded from PHP's source, the three permission routes | Sonnet | `/me/permissions` identical on both sides for every fixture user |
| 2b identity verifier, user lookup, failure table, emulator in the dev stack | Sonnet | sign-in Hurl cases pass on both sides |
| Review | `qa`, `security`; GPT on serious findings | findings settled |

Not in phase 2: the outbox relay (nothing consumes events yet; build it with the first consumer) and
gateway changes (none needed until production).

## Decisions

1. The `IClassScopes` port (recommended) or the database view.
2. The `users` split above.
3. Quirks copied as they are.
4. Outbox relay deferred until something consumes an event.
