# Docs cleanup, pass 1: assessment, membership, access

The three domain `CLAUDE.md` files were trimmed to what an agent needs to act. No build or test was run (documentation only).
Each removal below was either confirmed in the named file (opened and read in this pass) or is dated history.

| File | Before | After |
|---|---|---|
| `domains/assessment/CLAUDE.md` | 12326 bytes | 9748 bytes |
| `domains/membership/CLAUDE.md` | 11535 bytes | 9794 bytes |
| `domains/access/CLAUDE.md` | 10606 bytes | 9790 bytes |

The 5 to 6 KB target was not reached. What remains is the events, the published views, the interfaces and commands, and rules
that no slice header, contract or capability document states (see "Why not smaller").

## What was removed

| File | What was removed (short) | Where the fact still lives (path), or "history only" |
|---|---|---|
| assessment | "27 operations with a slice (12 Nov 2026)", "batch A1 and 9 of batch A2 are proven", "built: 9 of its 12", "the last eight routes", lane names, "PROVEN in test lane quizwrites" | history only |
| assessment | The route of each slice (35 method and path pairs written out) | the `// Slice:` header of each file under `domains/assessment/api/features/`; `domains/assessment/spec/api.yaml` (35 operations). Slice names kept by group |
| assessment | Fixture id ranges (tokens 902401 to 902499 and 902501 to 902512, classes 9621 to 9624 and 9631 to 9637, quizzes 962401 to 962499 and 963401 up, standard MCQs `A2S-*`) | header of `db/synthetic/assessment-a1-fixtures.sql` and `assessment-a2-fixtures.sql`; `tools/assessment-contract.sh` line 7. Note: both say tokens 902501 to 902513, the old text said 902512 |
| assessment | What each `domain/` helper holds (scoring, by-code state machine, per-response date rule, body rules of an edit, ...) | the `<summary>` header of each file in `domains/assessment/api/domain/` (19 read). File names kept |
| assessment | "(unit tested)" on `QuizRules`, `QuizEdit` | the `*.Tests.cs` files beside them |
| assessment | Answered quiz: the 409 text, "after the permission check and the body rules, no write, no event", the check runs in the edit's transaction after `select ... for update` | header of `domains/assessment/api/features/manage-update/ManageUpdate.cs`; `domain/QuizLock.cs`. The rule, the two locks and the two Hurl files kept |
| assessment | "`tools/assessment-contract.sh` runs it on PHP only" (the php-only file) | `tools/assessment-contract.sh` lines 85 to 87; kept as a general line in "Where things are" |
| assessment | Quiz code: cryptographic draw, `insert ... on conflict (code) do nothing`, up to 20 draws, citext so case does not matter, the conflict clause never aborts the caller's transaction | `domains/assessment/api/domain/QuizCode.cs`, `NewQuiz.cs` (`MaxAttempts = 20`) |
| assessment | `ISheets`: "read a range, write a range" | `domains/assessment/api/domain/ISheets.cs` |
| assessment | `quiz_state` documents by name, "Reset clears five (...)", `winners_replaced` append only | `domains/assessment/api/domain/QuizStateStore.cs` |
| assessment | Dates on the owner's decisions (12 Nov 2026) | history only (the decisions are kept); the date is also in the header of `ManageUpdate.cs` |
| assessment | "(lane sheets, build-out)", "Dependencies added", "Notes for the test phase" wording | history only (the dependencies, readers and note paths are kept) |
| membership | "built (task 3b-2)", "PHP parity proven by the Hurl files on both stacks", batch names B4b, B5b, B5d as headings | history only |
| membership | The slice names of the ten first operations and the route list of each batch | folder names under `domains/membership/api/features/`, each file's `// Slice:` header, `domains/membership/spec/api.yaml`. Counts by group and the later slice names kept |
| membership | Fixture id ranges (tokens 9011xx, 9018xx, 9021xx, classes 9561 to 9563), the coordinator `b5d_coord` | headers of `db/synthetic/membership-b4b-fixtures.sql`, `membership-b5b-fixtures.sql`, `membership-b5d-fixtures.sql`; `tools/membership-contract.sh` |
| membership | Published commands: what each writes in detail (no row gets an Accepted one, any row keeps it; name only when given, mobile always overwritten, every profile row; name, gender as the class's number, mobile may be empty, nothing else; throws for an unknown token; the two events) | doc comments in `domains/membership/api/MembershipCommands.cs`; the events are still in the Events table. Signatures, limits, users and tests kept |
| membership | "Slices are internal and never call each other" | `domains/CLAUDE.md` rule 1 and "Enforced by tests" |
| membership | `PhpText`, `PhpValue`, `JsonBody` named as files of `api/domain/` | `domains/CLAUDE.md` rule 6 (they are in `shared/api`; `ls` confirms none is in `domains/membership/api/domain/`). `JsonBody` is still named in the body rule |
| membership | Counts in the check comments ("the nineteen operations", "the 20 Hurl files (19 on parity)"), "the ten slices" | history only (old counts) |
| membership | Placeholders section | kept as one clause in Status ("no `api/Planned.cs`") |
| membership | "`MembershipModule.Dependencies` is unchanged (`access`, `identity`, `platform`)" at the end | same file, Dependencies section |
| access | "Hurl contract proven identical on PHP for version 4", "is now PHP's version 5 ... (12 Nov 2026)", "built and proven" | history only |
| access | `GET /me/permissions`: how the revision is computed (sha256 of the key-sorted compact JSON, first 16 hex, `issued_at` not in it), ETag, `Cache-Control: private, no-cache`, `Vary: Authorization`, 304 on `If-None-Match`, 503 when unreadable | `domains/access/capabilities/permissions.md` PERM-R12, R19 to R22, PERM-D5 |
| access | Header: where it appears (200, 304, a download, the route's own 403, 404, 409, 422, 503; a member being deleted; the member a create route made), "as PHP (`lib/auth.php` ...)", the value is the revision before the route runs | `permissions.md` PERM-R23, PERM-D6; header comment of `domains/access/api/PermissionsRevisionHeader.cs` |
| access | Second mention of `PermissionsRevisionHeaderTests.cs` ("Pinned by") | same file, one mention kept |
| access | Stricter than PHP: roles 1, 3, 4 by number, `class_access_rules.granted_by`, the 403 text, "checked again inside the member lock", the date | `permissions.md` PERM-R15 to R17, PERM-D4; `domains/access/api/domain/ClassAccessOperator.cs` |
| access | "`tools/contract-grants.sh` runs the `*-php-only.hurl` files on PHP only and the `*-new-api.hurl` files on the new API only" (shortened) | `tools/contract-grants.sh` lines 9, 41 to 52 |
| access | Placeholders section | kept as one clause in Status |

Counts: 24 items confirmed elsewhere (some rows hold several), 7 history only.

## Kept, unsure

| File | Text kept | Why unsure |
|---|---|---|
| assessment | "Production had no duplicate and no empty code" | a data observation found in no other file |
| assessment | "Not verified against a real service: the Google client" | status, not re-checked |
| membership | `v_registrations`: "columns to re-check in B4" | an open note from a finished batch; nothing says it was done |
| membership | "Deferred: the search touch of `PATCH /me`, erasure on account deletion" | `MembershipCommands.cs` now has `EraseMemberAsync`, which the file does not list. Not added (a trim adds no fact); the owner should decide |
| membership | "`classes` is not a dependency: it will supply `IClassEnrolments`" | future tense; `classes` is built |
| access | "`RuleMatcher` ... has no classes to match until `classes` exists" | `classes` exists now |
| access | Header "Hurl cases not yet run" | `spec/tests/me-permissions.hurl` holds header cases; whether they were run is not recorded |
| access | "Known open difference ... settle it when `classes` is built and class fixtures exist" | `classes` is built; the difference may still be open |
| access | Check `tools/access-contract.sh dev` (Hurl on the dev stack) | the root `CLAUDE.md` says Hurl runs only on the test stack because dev may hold real data; the script also takes `test`. Left as written, for the owner to decide |

## Moved, not removed

- assessment: the two settings into a Settings table; the two sheet events into the Events table; the lock, quiz state and
  Google rules into "Rules for this domain"; `tools/contract-quizwrites.sh` and `tools/contract-sheets.sh` into Checks.
- membership: `TSR_PUBLIC_WEB_BASE` into a Settings table; the tables into "Owns"; the reader paragraph into Dependencies.
- access: `tools/contract-grants.sh` into Checks; the database test files into "Where things are".

## Word for word

Not changed: membership's "Reach copied exactly" paragraph (the waiting list is gender only, which is the owner's decision,
so no correction was needed), assessment's answer key and member data sentences, access's "How a check works".

## Why not smaller

- Events and published views are the contract other domains read; they are about a third of each file.
- access: the quirks, the header's cost and `Permissions.Forget` rule, and the scope list are in no capability or code comment.
- membership: the schema quirks (raw gender text, citext CHECKs, no keys) are in no capability document.
- A second pass could move the events' payloads to a machine-readable spec and the schema quirks into the capability documents.
