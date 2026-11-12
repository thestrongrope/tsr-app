# Review: identity (account deletion) and access (permission administration)

Independent, read-only review (Opus, `security` agent) of `dotnet-11` at `bcf02bc` against `build/parity-php/src/web`, by the brief in `review-brief.md`. Received 12 Nov 2026. The reviewer ran no build, test or network call. Nothing here has been verified or fixed yet.

**Verdict:** no authorization, row-scope, data-exposure or injection hole looser than PHP. One irreversible-action defect that PHP does not have (S1).

## Should-fix

**S1. A completion can get stuck for good after Firebase has already been deleted.** (reviewer: high confidence, traced from the code)
- Where: `domains/identity/api/features/admin-deletion-complete/AdminDeletionComplete.cs:192-199`, `domains/platform/api/PlatformCommands.cs:59,79`, `domains/notifications/api/NotificationsErasure.cs:11,25`.
- Trigger: a member registers 1000 or more distinct device ids (`POST /devices` has no cap per member and no rate limit: `domains/notifications/api/features/device-register/DeviceRegister.cs:23,61-68`), has a mobile number, and raises a deletion request.
- What happens: `EraseDevicesAsync` returns at most 1000 ids; with the mobile that is 1001 recipients; `RedactRecipientsAsync` throws `ArgumentOutOfRangeException`; the transaction rolls back; the route answers 500. Firebase was deleted BEFORE the transaction, and every retry fails the same way, so the profile is never erased while the request stays live. Separately, with more than 1000 devices, queued pushes to the devices past 1000 are never redacted.
- PHP (`models/accountdeletion.php:675-697`) has no bound: it selects every device and redacts them all.
- Fix direction: redact in chunks; do not cap the ids `EraseDevicesAsync` returns. Consider a cap or rate limit on device registration per member.

**S2. A completion that has already committed can be reported as a 500.** (medium confidence; note-grade)
- Where: `AdminDeletionComplete.cs:107`: `PurgeExpiredContactDetailsAsync` runs after the commit with no handling around it. A database error there shows the operator a failure for an erasure that did happen.
- PHP (`accountdeletion.php:656-659`) is just as wrong: it rolls back an already committed transaction and answers 409.

## Notes

- N1. Two completions at once on separate instances can both reach Firebase: `MemberRateLimit` counts in memory per process (`shared/api/MemberRateLimit.cs:11-14`). The guarded status update still erases the database once, and a second Firebase delete of one uid is harmless. PHP's `rate_limit_allows` store was not checked.
- N2. A cancellation can land between the Firebase delete and the transaction (`AdminDeletionComplete.cs:167-176`): the request is left cancelled and the profile intact, but the Firebase sign-in is gone. PHP's unguarded `where id = :id` would have completed regardless. Arguably safer; pinned by `TestDeletionTests.cs:242`. The operator only sees "no longer live", not that Firebase was already deleted.
- N3. The erasure port fails open: `IMemberErasure` defaults to `NoMemberErasure` (`IdentityModule.cs:51`). If membership were left out of the composition, completions would "succeed" without erasing profiles. Membership registers the real one today (`MembershipModule.cs:50`). A host test asserting the resolved type would close this.
- N4. Case sensitivity, stricter than PHP, not a hole: the class-access member search compares `m.gender::text = any({texts})` case-sensitively (`AdminMembers.cs:121`); MariaDB's `gender in (...)` also finds 'male'/'MALE', and those rows then fail PHP's strict `genderOf` with a 403 anyway.
- N5. Sound, matches PHP: the class-access write path re-checks the operator guard and the version inside the member lock; the preview hash is recomputed on the server, so a forged or stale hash can only fail; grants and revokes take effect on the next request (`Permissions` is scoped per request, no longer-lived cache).
- N6. Sound: `debug-token` answers 404 in Production, including when no environment is set; elsewhere it echoes only the caller's own email, uid and name and touches no database. It is on the deletion allow list, as in PHP.
- N7. The Firebase client logs no credential, token, email or response body; every call has a 10 second timeout; it is stricter than PHP (a lookup error that is not "not found" refuses the completion, where PHP skips the delete and erases anyway). Unproven against real Google.

## PHP looseness that was copied (decisions for the owner)

- Shared tokens: every user row of the token is anonymised, but Firebase and feedback deletion target only the lowest-id row. A second person sharing the token loses their profile and keeps their sign-in.
- Deleting Firebase by email when no uid is stored can delete another person's Firebase account if this row's email is that person's address (legacy rows can share emails across tokens; Firebase matches email without case; with "multiple accounts per email" on, the first result is arbitrary). `ChangeEmailAsync` refuses addresses another user row holds, but not addresses that exist only in Firebase. Pinned as PHP behaviour (`TestDeletionTests.cs:168`).
- Recipient redaction by value also redacts another member's queued messages to a shared mobile number or device id.
- One operator can delete any member alone: a holder of `deletion-requests:manage` can raise by email, stamp the confirmation and complete, with no second person and no protection for operators or admins (only demo members are protected).
- Grants: a super admin may grant to themselves; `deletion-requests:manage:all` and every other scope-`all` permission except the three excluded ones are grantable; any holder of `permissions:manage` may revoke any grant.
- Class access: a gender admin may add rules to, or remove rules from, a super admin or another gender admin of their gender.
- The admin routes use `createsMember: true`, so a stranger's sign-in creates a row before the 403.

## Guards no test would catch if deleted

- The second guard check inside the lock: `op.GuardAsync` after `MemberLock` in `ClassAccessGrant.cs:142` and `ClassAccessRevoke.cs:105` (reachable only by a race in which the operator's or member's gender or role changes).
- The live-status condition on the hold update (`AdminDeletionHold.cs:74`) against a completion that lands at the same moment; the tests cover only sequential refusals.
- The 1000 caps in `EraseDevicesAsync` and `RedactRecipientsAsync` (see S1): no test uses more than a handful of devices.
- The fallback when the post-write view cannot be read: `ClassAccessStore.SavedAsync` answers `saved: true` with nulls.

Tests do cover: the demo refusal, the token-0 409, the rate limit, the self guard, the never-grantable list, the Finance refusal, the "reaches no class" refusal, the cancellation race, concurrent grants and revokes, and the deletion gate per route.

## Not checked by the reviewer

The real Google Identity Toolkit request and response shapes; PHP's `rate_limit_allows` backing store; the internals of `AccessEngine` and `RuleMatcher`; `MemberDirectory.FindAsync` / `RecordSignInAsync` and whether a re-sign-in after the Firebase deletion re-links the row (N2); whether `contact_email` comparisons in `RecentlyDeletedAsync` are typed as citext. No build or test was run.
