# Schema phase design (proposal, 2026-11-10)

For Asif to approve before any build. Facts: `schema-phase-recon.md` and `schema-phase-tables.csv`
(read from tsr-account's `develop` code; no database was read). Order agreed in `plan.md`, Checkpoint 4.

## Where the schema stands

| | Tables |
|---|---|
| PHP tables verified | 70 (732 columns) |
| Already in PostgreSQL | 15 in full, 2 partly (`users`, `account_deletion_requests`) |
| To port in this phase | 36: classes 16, notifications 8, assessment 7, platform 4, content 1 |
| Proposed to leave behind | 15 (no API, web page or worker reads them) |
| Derived, not ported | 2 (`class_access`, `calendar_table`) |

## What is built

| Task | What | Done when |
|---|---|---|
| S1 Schema | Modules and contexts for `classes`, `assessment`, `notifications` (no routes yet); the 36 tables as EF migrations in their owners' schemas; the rest of `users` and `account_deletion_requests`; synthetic seed rows for every table | build 0 warnings; the guard tests pass (citext, no cross-schema foreign key, public surface); the 21 Hurl files still pass |
| S2 Load | One script, MariaDB to PostgreSQL: export each table to CSV, copy into a staging schema, then SQL that converts types and splits `users` three ways. It reports row counts and orphaned references per table; it never fails on an orphan | run against the synthetic PHP database: counts match per table, and the 21 Hurl files pass on a dev database filled by the load in place of `seed.sql` |
| S3 Surface | Every one of the 211 operations routed in its domain, taken from `web/api-docs.json` and `operation-domains.csv`; unbuilt ones answer 501 `{"detail": "Not implemented"}` after the sign-in check | a test compares the route table with the spec: 211 of 211, each marked built or 501 |
| Review | `qa` and `security`, unanchored, over S1 to S3 and the unreviewed phase 3b | findings settled |

The real data move is run by you with the S2 script and your own connection settings. I only ever
run it against the synthetic PHP database.

## Rules applied to every table (already the project's)

Text is `citext` with a length CHECK; enums and SETs become text with a CHECK; no foreign key crosses a
domain schema, and references to a user stay plain integers (`users.token` is not unique, so they
could not be keys anyway); JSON kept as text stays text.

## Decisions

1. **Leave 15 unread tables behind** and keep one offline MariaDB dump as the archive. Three of them hold
   old member data (quiz responses and registrations, event registrations). Recommended.
2. **Dates become `timestamptz`, read as UTC,** as the 17 ported tables already do. Wall-clock columns
   (a reminder's send time, a session's date) stay without a zone. This needs one fact from you: that the
   PHP server and MariaDB run in UTC.
3. **`tinyint` flags become `smallint`,** not boolean, so a stray value above 1 survives the load and
   the JSON stays as PHP emits it. Recommended.
4. **`class_access` is not ported.** `access` already matches the rules in C#. Before the real move,
   someone must confirm production has completed that cutover. Recommended.
5. **`genders` and `languages` stay as their own tables in `platform`.** The recon suggests folding them
   into `platform.lookups`; I recommend against it for now: other tables store their ids, so a straight
   copy is simpler and safer. `age_ranges` is left behind (web only).
6. **The three notifier tables are ported now;** the Node worker keeps its own connection setting
   until `notifications` is filled. Recommended.
7. **The 501 surface uses the spec for routes only.** `api-docs.json` matches the PHP router exactly
   (191 paths, 211 operations) but describes no request bodies and leaves 27 responses empty, so
   request and response types are written per domain during the fill phase. Recommended.

Taken as the recon recommends unless you say otherwise: `classes` owns `class_students`, levels, tags,
teachers and training; `notifications` owns `user_devices` and the scheduled notifications;
`assessment` owns spot quizzes; `outbound_messages` stays beside `platform.outbox`; the 8 `users`
columns nobody reads are dropped.

## Risks

- **The schema sources are stale.** The schema-only dump lacks 2 tables that migrations add, and two
  training tables and `surveys` are unverified. S1 first regenerates the schema from migrations on the
  synthetic PHP stack and compares.
- **Accents and trailing spaces.** `citext` ignores case only; MariaDB also ignored accents. Accepted,
  except the two columns an access rule matches on (`city`, `country`), which get the ICU collation.
- **The load is proven on synthetic rows only.** Real data will show values the synthetic set lacks
  (zero dates, bad JSON, orphans). The script reports these; expect one or two fix rounds on your run.

## Budget

900,000 tokens: S1 300,000, S2 250,000, S3 150,000, reviews and fixes 200,000. The recon used 263,000
outside it. I report after each task and stop at the cap.
