# Fill phase 1 design: `classes` and the rest of `membership` (proposal, not approved)

Scope: 99 planned operations (classes 85, membership 14). Facts: `fill-classes-recon-a.md` (47 class operations),
`-b.md` (15 admin, 11 membership), `-c.md` (reports, cross-domain reads, events). Judged against the north star in
the root `CLAUDE.md`: every choice below is there to lower the cost per verified change.

## Why the earlier way is too dear

Membership 3b cost 741,000 tokens for 10 operations (74,000 each). The recon shows why it would get worse: PHP is
one application over one `users` table, and the nine-schema split turns its ordinary joins into interfaces. About
40 of the 99 operations need a member's name, mobile or gender by token; four write another domain's table; PHP
uses three different "is enrolled" rules; ten reports filter on another domain's data across thousands of rows.

## Decisions

| # | Decision | Replaces |
|---|---|---|
| D1 | **The database is the integration surface for reads.** A domain publishes views named `v_*` in its own schema, created by its own migration. Any domain's query may join another domain's `v_*` views in SQL, and nothing else of that domain. | "never read another domain's tables" (root rule 3, domains rule 2, 3, 10); read models; new batch interfaces |
| D2 | **A cross-domain write is a published command of the owner:** a public static method in the owning domain that runs on the caller's connection and transaction (for example `MembershipCommands.RecordAcceptedRegistrationAsync`). Four are needed: accepted registration, create member (bulk add), edit member contact, admin audit row. | events with consumers, or a second transaction |
| D3 | **One file per slice, one static class:** route, guard chain, validation, SQL, response record. No handler class, no mapping layer. Reads are parameterised SQL (`SqlQuery<T>`), ported from PHP's SQL; writes use EF entities or `ExecuteSql`, whichever is shorter. | endpoint class + handler class; LINQ rewrites of PHP SQL |
| D4 | **A helper moves to `domain/` only when two slices use it.** The PHP-emulation helpers (`PhpValue`, `PhpText`, `JsonBody`) move once to `shared/api`, because classes needs the same rules. | per-domain copies |
| D5 | **Every state-changing command writes one outbox row** with `Outbox.WriteAsync` in its transaction. Event names and fields are a table in the domain `CLAUDE.md`. No consumer, relay, version scheme or event sourcing in the baseline. | per-event specs |
| D6 | **PHP is the oracle.** A slice is done when its Hurl file passes on PHP and on the new API. Unit tests only for rules with real branching (class code and link generation, conduction validation, deactivation, week arithmetic, training flags). | a unit test file per helper |
| D7 | **Keep EF Core for the schema and migrations** (58 tables exist and are loaded). Views are added with `migrationBuilder.Sql`. The 21 built slices and their interfaces are not rewritten. | a move to plain SQL migrations |
| D8 | **Parity bar:** same status, body and permission for valid and ordinary invalid input. Quirks listed in the recon are copied; PHP writes that are not atomic become one transaction, and each such difference is recorded in `php-parity-feedback.md`. | chasing exotic cases |

### D1 in detail

First views (each lists only columns another domain may see):

| View | Columns | Used for |
|---|---|---|
| `identity.v_users` | user id, token, email, created on, has Firebase link | token to id, email filters |
| `membership.v_members` | token, user id, name, mobile, gender (raw text), city, state, country, zip (joins `identity.v_users`) | every name, contact and gender read |
| `membership.v_registrations`, `membership.v_guardian_links` | as PHP reads them | waiting list, children routes |
| `classes.v_classes`, `classes.v_enrolments` | class header; enrolment rows with both status columns, so each of PHP's three rules is a `where` | membership's waiting list and gender lock, assessment reports |
| `assessment.v_quiz_results` | class id, token, quiz, correct, max | performance and student reports |
| `content.v_quran`, `platform.v_genders` | lookup rows | conduction, class header |

- **Enforced by a test:** `hosts/api/tests` scans every domain's SQL and fails if it names another schema's object that is not `v_*` (or `platform.outbox`).
- **What stays:** commands write only their own tables. Permissions still go through `access` in C#, never through a view.
- **What it costs:** a view is a contract, so changing one is a cross-domain change; splitting a domain into its own database later would mean replacing its views. For one PostgreSQL database this is the cheaper trade.

### Test stack (needs your approval: it adds containers)

The dev database holds production data, so Hurl files cannot run there. Add a compose profile `test`: a second
PostgreSQL (`db-test`, synthetic seed) and a second API (`api-test`, port 8089). The contract scripts gain a `test`
target; the `dev` stack is not touched. Reports are also read against the production-loaded dev API by hand (row
counts and timings only; nothing copied out).

## Build order

| Batch | Operations | Content |
|---|---|---|
| B0 | 0 | views, published commands, helper move, slice template, test stack, the SQL-boundary test |
| B1 | 22 | class reads: levels, list, detail, sessions, syllabus, guides, my attendance and performance, children routes |
| B2 | 19 | class management and enrolment: create, update, schedule, add, bulk add, remove, restore, transfer, join, place, deactivate, teachers |
| B3 | 6 | conduction (teacher records a session; the largest single write) |
| B4 | 26 | admin (syllabus, transfers, member enrolment, donors, teacher training) and the 11 membership operations |
| B5 | 26 | reports: 23 classes, 3 membership; xlsx, PDF and CSV export |

Each batch: build (Sonnet `developer`), one unanchored `qa` + `security` review, fix round, my re-run, report.
The sign-in label in `operations.csv` is corrected per slice (PHP uses the member-creating sign-in on most of these).

## Measure and budget

| Batch | Target per operation | Budget |
|---|---|---|
| B0 | n/a | 250,000 |
| B1 | 15,000 | 450,000 (build 330,000 + review and fixes 120,000) |
| B2 to B5 | re-estimated from B1's actual figure | given with each batch report |

If B1 lands near its target, the 99 operations cost roughly 2.5 million tokens; at the 3b rate they would cost
7.3 million. I stop and report at each batch's cap. Recon for this phase used 867,000 against 300,000 planned.

## Open risks

- **Export libraries (B5):** PHP uses PhpSpreadsheet and Dompdf. Decided in `docs/specs/dotnet-stack.md` (Asif, 9 Nov 2026; confirmed 11 Nov 2026): **ClosedXML** for xlsx and a **Gotenberg** container (HTML to PDF over HTTP) for PDF. Byte-equal files are not the bar, same rows and columns are.
- **Bulk add (B2)** creates members in identity and membership from classes, under a lock; it is the hardest published command.
- **Duplicate rows:** `class_students` has no unique key and `users.token` is not unique, so some PHP joins repeat rows. SQL ported from PHP repeats them the same way; no fix in the baseline.
- **Not determined by recon:** the PHP `calendar_table` week numbering, whether API calls reach PHP's admin audit log behind the gateway, and how MariaDB compares text gender to a number for odd values.
- **Slow PHP reports** (summary without its 12-month cap, four with a query per class) are ported as one query each where that keeps the output equal; timings are reported against the loaded data.
