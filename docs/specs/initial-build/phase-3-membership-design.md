# Phase 3b design: membership, first half (proposal, 2026-11-10)

For Asif to approve before any build. Facts are in `phase-3-membership-recon.md` (26 operations:
S 11, M 10, L 5), read from tsr-account's `develop` code. Parity first: PHP behaviour is copied.

## What is built now, and what waits

About half of membership cannot answer as PHP does until `classes` exists (waiting list, placing,
reports, cards, a child's classes). So this phase builds only what can be proven on both sides today.

| Batch | Operations | Count |
|---|---|---|
| E. Registration form | `GET /registration`, `POST /registration` | 2 |
| B. Guardian self-service | `GET /me/children/links`, `GET` and `POST /me/children/link/{code}`, `DELETE /me/children/{child_token}/link`, `GET /me/parents`, `DELETE /me/parents/{parent_token}` | 6 |
| A. Profile | `GET /me`, `PATCH /me` | 2 |

Ten operations. The other 16 are built with `classes`: `GET /me/children` (3), the five staff
parent-link operations (10 to 14: only two of their five scopes work without classes, so they are
not half-built now), waiting list, place, reject, the three downloads, donors and the two cards.

**One gap inside the ten:** `PATCH /me` refuses a gender change for a member enrolled in a class.
That rule is built behind a port and tested in NUnit, but has no parity proof until `classes`.

## Tables (schema `membership`)

| Table | Notes |
|---|---|
| `member_profiles` | the profile columns of PHP `users`, keyed by identity's user id (plain integer, no foreign key). Created on first read or write; `GET /me` shows PHP's defaults for a missing row |
| `class_registrations`, `class_registrations_languages`, `interest_options`, `student_interests` | as PHP, duplicates per token allowed, plus an index on `token` |
| `user_guardians` | as PHP: keyed by token, no foreign keys |

`identity.users.gender` is dropped by a new identity migration once the profile holds it.
`lookups` (7 types the registration form checks against) is platform's table: platform gets the
migration, the seed and a read interface.

## New interfaces

| Interface | Owner | Why |
|---|---|---|
| `UserDirectory` (id, token, email by token or ids) | identity | membership needs user ids and emails without reading identity's table |
| `IProfileSink` port (name and picture on sign-in) | declared by identity, supplied by membership | PHP writes the name during sign-in. A port keeps identity free of a dependency on membership (membership already depends on identity) |
| `IClassEnrolments` port ("is enrolled in a class") | declared by membership, supplied by classes later | the gender lock; answers "no" until classes exists |
| `Geo` (country by name, postal lookup) and `Lookups` | platform | `PATCH /me` and `POST /registration` validation |
| `MemberNames` (name by user ids) | membership | the access log and, later, classes and assessment |
| per-member rate limiter | moves from platform to `shared/api` | guardians need the same limiter with their own wording |

## Decisions

1. **Scope:** the ten operations above now, sixteen with `classes`. Recommended.
2. **`place` and the class picker move to `classes`** (they write and read classes' tables); membership
   keeps the waiting list and reject. Recommended; it only changes `operation-domains.csv` now.
3. **Gender stays as PHP's raw text** (`'1'`, `'2'`, `'Male'`, `'Female'`, empty, null) so all five PHP
   behaviours stay identical. Normalising is a separate change after the baseline. Recommended.
4. **Name and picture on sign-in** through the `IProfileSink` port, in the same request. Recommended.
   The alternative (an event) can show an empty name straight after sign-in.
5. **Guardian rules are guarded by a lock only** (`pg_advisory_xact_lock` on the child), as PHP guards
   in code. No new unique index: old data may hold a duplicate pair. Recommended.

Taken as the recon recommends unless you say otherwise: registration duplicates copied as they are;
`first_name` and `last_name` kept; both rate-limit wordings copied; the invite link base is a new
setting `TSR_PUBLIC_WEB_BASE` that fails closed in Production.

## Not in this phase

- Erasure of membership's data on account deletion (identity's deletion command is not built).
- The access log: `MemberNames` unblocks its list; the download still needs the xlsx/PDF generator.
  Both operations are built together with the first report batch.
- The search touch on `PATCH /me` (search is not built): the outbox row is written, nothing reads it.

## Build tasks after approval

| Task | Who | Done when |
|---|---|---|
| 3b-1 interfaces and tables: `UserDirectory`, ports, platform `Lookups` and `Geo`, shared limiter, migrations, synthetic seed (each gender form, a shared token, guardians in every status, duplicate registrations) | Sonnet | build 0 warnings; existing 173 Hurl requests still pass |
| 3b-2 batches E, B, A, tests first | Sonnet | a Hurl file per slice passes on dev and on PHP |
| Review | `qa`, `security`, unanchored; serious findings verified | findings settled |

Budget: 600,000 tokens (recon already spent 214,000 outside it). Stop and report at the cap.
