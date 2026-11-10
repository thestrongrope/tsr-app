# Phase 3a design: platform (proposal, 2026-11-10)

For Asif to approve before any build. Facts are in `phase-3-platform-recon.md` (read from tsr-account's
PHP source) and `operation-domains.csv` (all 211 operations given a domain and a first-guess size). The
aim is parity: the shapes copy PHP, quirks included.

## Size of phase 3

| Domain | Operations | Small | Medium | Large |
|---|---|---|---|---|
| platform | 9 (2 built) | 6 | 2 | 1 |
| identity | 10 | 5 | 5 | 0 |
| access | 13 | 7 | 6 | 0 |
| membership | 26 | 11 | 10 | 5 |
| notifications | 25 | 10 | 11 | 4 |
| assessment | 43 | 7 | 19 | 17 |
| classes | 81 | 12 | 43 | 26 |
| content | 3 | 1 | 0 | 2 |
| search | 1 | 1 | 0 | 0 |

Sizes are a guess from the route and path, not from reading every model.

## What is built now: five operations

| Batch | Operations | Proof |
|---|---|---|
| A | `GET /app-version`, `GET /release-notes` (public, read one JSON file) | Hurl on both sides with one shared file; the validation cases as unit tests |
| B | `GET /geo/countries`, `POST /geo/postal`, `POST /geo/cities` (signed in, no permission, rate limited) | Hurl on both sides with the same synthetic geo rows; the 61st call as a unit test |

Also in this batch: a platform migration that removes its two foreign keys into `identity.users`
(open item from checkpoint 2), so the guard test's allow-list becomes empty.

## What waits: the two access-log operations

`GET /admin/access-log` and its download are not built now, for three reasons:

- They show each member's name, and no domain in the new API stores a name yet (it arrives with
  `membership`).
- The log is written by nine admin routes in other domains; until one of them exists the log is empty.
- The download needs the xlsx and PDF generator that every report in every domain uses. Choosing that
  library is its own decision, best made with the first real report.

They are built after `membership`, together with the interface other domains use to write the log.

## Decisions

1. **Accent- and case-insensitive text for geo.** MariaDB finds "Zürich" for "zur" and sorts accented
   names among plain ones; `citext` ignores case only. Proposed: the geo name and postal columns use
   one ICU collation that ignores case and accents, as a written exception to "every text column is
   `citext`" (it is still case-insensitive, so the rule's intent holds). The build agent first proves
   on PostgreSQL 18 that prefix search and ordering work under that collation on accented synthetic
   names; if not, it stops and reports. This also settles the long-open accent question for name
   searches in later domains.
2. **Rate limit in memory, per process** (60 calls a minute per member, counting calls that fail
   validation, as PHP does). PHP keeps it in files on one host. Weaker if the API ever runs as several
   instances; noted, not solved now.
3. **`app_versions.json` stays a file,** read from a configured path, with the same fail-open rules as
   PHP (a bad file never returns an error). One source file serves both sides in tests.
4. **Quirks copied:** an empty `builds` is `[]` not `{}`; a quoted `"12"` is not a number; a postal code
   of exactly `0` is never looked up; an unknown country is "not found", not an error.
5. **Geo data:** the dev seed holds a small synthetic set. The full GeoNames load (171,000 cities, 1.1
   million postal codes; public data, CC BY 4.0, not member data) is a loader run at the rehearsal.
6. **The access log waits** as described above.

## Tasks after approval

| Task | Who | Done when |
|---|---|---|
| 3a-1 batch A | Sonnet | Hurl passes on both sides; unit tests cover every validation case in the recon |
| 3a-2 collation proof, then batch B and the foreign-key migration | Sonnet | proof recorded; Hurl passes on both sides |
| Review | `qa`, `security` | findings settled |

Budget: 600,000 subagent tokens for build, review and fixes. Next after this: `membership`, with its
own recon and design.
