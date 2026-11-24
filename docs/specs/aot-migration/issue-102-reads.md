# Issue 102: each converted read of `identity` and the test in which it returns a row

TC-IDN-R1-03 (inspection). `DbRow` checks a row's shape on the first row, so a read that never returns a row in a test checks nothing (#96).
Counted by reading every `ListAsync` and `ScalarAsync` in `domains/identity/api` that belongs to `UserDirectory`, `MemberDirectory`, `DeletionRequests` and the slices
(not `Migrations/`, not tests): **18 reads**. The writes run through `ExecuteAsync` and are not listed. `IdentityCommands` and `TokenAllocation` are not in this table.
Golden scenarios are in `db/tests/IdentityGoldenScenarios.cs` and `IdentityGoldenTests.cs`, their answers in `db/tests/golden/identity/`. Made by opening each golden file, not by its name.

| # | Read | File:line | Returns a row in |
|---|---|---|---|
| 1 | users of one token | `UserDirectory.cs:31` | `UserDirectoryTests.A_shared_token_returns_every_user_oldest_first` (token 900207, two rows) |
| 2 | users of several tokens | `UserDirectory.cs:47` | `UserDirectoryTests.Several_tokens_return_every_holder_in_id_order_and_an_unknown_token_adds_nothing` |
| 3 | users by id | `UserDirectory.cs:64` | `UserDirectoryTests.Users_are_found_by_id_and_a_missing_id_is_left_out` |
| 4 | the member by `firebase_uid` | `domain/MemberDirectory.cs:119` | golden `signin-tracking` (`POST /feedback as uid-900113`), and `race-one-account` (the re-read after the unique violation) |
| 5 | the member by email | `domain/MemberDirectory.cs:29` | golden `signin-claim` (`uid-claim-a`, a member with no uid claimed by a verified address) |
| 6 | the live deletion status | `domain/MemberDirectory.cs:64` | golden `signin-live-deletion` (a pending request and one held for a prize answer 403 with the status) |
| 7 | deleted in the last 2 h (the exists) | `domain/MemberDirectory.cs:73` | golden `signin-recently-deleted` (the create route answers 403 because the exists is true) |
| 8 | the new member's id (the insert's `returning id`) | `domain/MemberDirectory.cs:152` | golden `signin-first` and `race-one-account` (a first sign-in stores a row) |
| 9 | requests with their member | `domain/DeletionRequests.cs:62` | golden `admin-list` (every status) and `me-get` (`GET /me/deletion-request as 900102`) |
| 10 | the count per status | `domain/DeletionRequests.cs:91` | golden `admin-list` (`counts`: pending 9, awaiting_prize_delivery 1, completed 3, cancelled 1) |
| 11 | the demo members' tokens | `domain/DeletionRequests.cs:100` | golden `admin-complete-refused` (request 9800007 is refused as the demo cohort) |
| 12 | the contact of the caller | `features/deletion-request-create/DeletionRequestCreate.cs:53` | golden `write-create-cancel` (`POST /me/deletion-request as 900102` answers 202) |
| 13 | the token for an email | `features/admin-deletion-raise/AdminDeletionRaise.cs:80` | golden `write-raise` (`M900102@EXAMPLE.INVALID` raises a request, 201) |
| 14 | the member of that token | `features/admin-deletion-raise/AdminDeletionRaise.cs:89` | golden `write-raise` (the same request) |
| 15 | a completed request of the caller | `features/deletion-request-cancel/DeletionRequestCancel.cs:67` | golden `me-cancel-refused` (`DELETE /me/deletion-request as 900121` answers 409, "already been deleted") |
| 16 | the rows of a token | `features/admin-deletion-complete/AdminDeletionComplete.cs:170` | golden `write-complete-target`, `write-complete-pair` (a completion) |
| 17 | an email held by another token | `features/admin-deletion-complete/AdminDeletionComplete.cs:250` | golden `admin-complete-refused` (request 9800008 answers 409); `TestDeletionTests.A_row_with_no_stored_uid_whose_email_another_token_also_holds_is_refused_409_...` |
| 18 | a uid held by another token | `features/admin-deletion-complete/AdminDeletionComplete.cs:253` | `TestDeletionTests.An_email_lookup_that_returns_the_uid_of_another_tokens_row_is_refused_409_...` |

All 18 return a row in a deterministic test.
