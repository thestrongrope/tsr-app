# Submit feedback (screen: "Send feedback")

Owner domain: `platform` · Status: live (sample slice)

<!-- Living document: describes TODAY. Rewrite in every PR that changes behaviour. Template: docs/templates/capability.md -->

## 1. Purpose
A signed-in member sends a short message to the TSR team from the app. Each message is stored once, even
when the app has to resend it because a reply was lost, so the team sees every message exactly once.

## 2. Actors and scope
- **Actors:** member (sends), the app (resends safely), reviewer (reads later; not built).
- **In scope:** sending one message; safe resend; limits and errors.
- **Out of scope:** reviewing and marking feedback handled (issue 891); attachments; replies to the member.

## 3. Requirements (current behaviour)
Locations: `C` = `spec/tests/SubmitFeedbackContractTests.cs`, `U` = `api/domain/<Name>.Tests.cs`,
`A` = `app/test/submit_feedback_view_model_test.dart`.

**API**

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| FEEDBACK-R1 | WHEN a permitted member sends a valid client id and text THEN the system SHALL store the message and return 201 with its id | the core action | Must | Test: C `A_member_sends_feedback_and_gets_201_with_an_id` |
| FEEDBACK-R2 | WHEN the same member sends again with a client id already stored for them THEN the system SHALL return 201 with the stored id and SHALL NOT store a second message | a lost reply must not duplicate a message | Must | Test: C `A_replay_with_the_same_clientId_returns_the_same_id` |
| FEEDBACK-R3 | WHEN a resend carries different text THEN the system SHALL keep the stored text and ignore the new text | the first stored version is the message | Should | Test: none yet (section 9) |
| FEEDBACK-R4 | WHEN a different member sends a client id that another member already used THEN the system SHALL store a new message for them | client ids are unique per member, not globally | Must | Test: none yet (section 9) |
| FEEDBACK-R5 | IF the caller is not signed in THEN the system SHALL return 401 with a `{"detail"}` body | the app shows one error shape | Must | Test: C `Without_sign_in_it_is_401_with_a_detail` |
| FEEDBACK-R6 | IF the caller lacks `feedback:create:self` THEN the system SHALL return 403 with a `{"detail"}` body | permissions go through `access` | Must | Test: none yet (section 9) |
| FEEDBACK-R7 | IF the client id is missing, or after trimming is not 1-36 of `[A-Za-z0-9-]`, THEN the system SHALL return 422 with detail "clientId is required" | the id must be usable as a stored key | Must | Test: C `A_missing_clientId_is_422`; U `ClientId` `Other_ids_are_refused`, `Uuid_like_ids_are_accepted` |
| FEEDBACK-R8 | IF the text is empty or only spaces after trimming THEN the system SHALL return 422 and store nothing | an empty message has no value | Must | Test: C `Empty_text_is_422`; U `FeedbackText` `Empty_text_is_refused` |
| FEEDBACK-R9 | IF the text after trimming is longer than 2000 characters, counted per FEEDBACK-D1, THEN the system SHALL return 422 | bounded storage and review effort | Must | Test: C `Text_over_2000_characters_is_422`; U `FeedbackText` `Exactly_the_limit_is_accepted`, `One_over_the_limit_is_refused`, `Arabic_marks_count_as_code_points_like_php`, `An_emoji_counts_once` |
| FEEDBACK-R10 | The system SHALL store the text with surrounding spaces trimmed | stray spaces are not content | Should | Test: U `FeedbackText` `Text_is_trimmed` |
| FEEDBACK-R11 | IF a resend carries invalid text THEN the system SHALL return 422, even though the client id is already stored | validation runs before the stored-message lookup | Could | Test: none yet (section 9) |
| FEEDBACK-R12 | WHEN a new message is stored THEN the system SHALL publish `platform.feedback_submitted` | other domains react without reading this table | Must | Test: none yet (section 9) |
| FEEDBACK-R13 | WHEN a resend returns a stored message THEN the system SHALL NOT publish an event | one event per message | Must | Test: none yet (section 9) |

**App**

| ID | Requirement (EARS, one behaviour) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|
| FEEDBACK-R14 | IF the text is empty THEN the app SHALL NOT send it | save a pointless round trip | Should | Test: A `empty text cannot be sent and never reaches the API` |
| FEEDBACK-R15 | IF the text is over the limit (FEEDBACK-R9) THEN the app SHALL NOT send it | immediate feedback to the member | Should | Test: A `text over the limit cannot be sent` |
| FEEDBACK-R16 | WHEN a send gets no answer and the member retries THEN the app SHALL reuse the same client id | makes the retry a safe resend (FEEDBACK-R2) | Must | Test: A `a retry after no answer reuses the same client id, so it is a safe replay` |
| FEEDBACK-R17 | WHEN a message is sent THEN the app SHALL clear the text and thank the member | confirms success | Should | Test: A `a sent message clears the text and thanks the member` |
| FEEDBACK-R18 | WHEN a message is sent THEN the app SHALL use a new client id for the next message | the next message is a new message | Must | Test: A `the next message after a sent one gets a new client id` |
| FEEDBACK-R19 | WHEN the API refuses a message THEN the app SHALL show the API's detail | the member sees why | Should | Test: A `a refusal shows the API detail` |

## 4. Quality requirements (ISO/IEC 25010)
| ID | Characteristic | Requirement (measurable) | Rationale | Priority | Verification: method, location |
|---|---|---|---|---|---|
| FEEDBACK-Q1 | Security | Checks run in this order: signed in (401), permitted (403), client id valid (422), text valid (422), then lookup or store | no information leaks to unauthorised callers | Must | Inspection: `api/features/submit-feedback/SubmitFeedback.cs` `HandleAsync` |
| FEEDBACK-Q2 | Privacy | The message text never appears in events, logs or telemetry; the event carries only `feedbackId`, `userId`, `submittedAt` | the text is member-written and may hold personal data | Must | Inspection: `SubmitFeedback.cs` `FeedbackSubmitted`; Test: none yet for logs/telemetry (section 9) |
| FEEDBACK-Q3 | Reliability | Two simultaneous sends with the same member and client id store one message | concurrent retries happen on poor networks | Must | Inspection: `SubmitFeedback.cs` `StoreOnceAsync` (unique key plus duplicate-key recovery); Test: none yet (section 9) |
| FEEDBACK-Q4 | Reliability | The event exists if and only if the message was stored (same transaction) | no lost or phantom events | Must | Inspection: `SubmitFeedback.cs` `InsertAsync`, `shared/api/Outbox.cs` |
| FEEDBACK-Q5 | Compatibility | Store-live app builds keep working: no field or route removed or renamed; errors stay `{"detail"}` | installed apps cannot be updated at once | Must | Test: every case in C passes against each release |

## 5. Rules and permissions
- Sending needs `feedback:create:self` (held by every registered member).
- Reviewing needs `feedback:review:all` (role 1); no capability uses it yet.

## 6. Interfaces
- **Screen:** Send feedback (`app/lib/features/submit_feedback/`).
- **API:** `POST /feedback` `{clientId, text}` → 201 `{id}`; errors per FEEDBACK-R5 to R9. Contract tests: `spec/tests/`.
- **Events:** publishes `platform.feedback_submitted` `{feedbackId, userId, submittedAt}` through the outbox.

## 7. Data
- **Table:** `feedback` (owned by `platform`): `user_id`, `client_id`, `message`, `created_at`, `handled_at`, `handled_by`;
  unique `(user_id, client_id)`.
- **PII:** `message` is member-written free text and may contain personal data.
- **Account deletion:** `user_id` and `handled_by` are plain integers, not foreign keys (a domain never references another
  domain's tables), so deleting the `identity.users` row does not touch the message. Clearing `user_id` and the text is the job
  of identity's erasure event, which platform does not handle yet (see section 9).

## 8. Decisions in force
| ID | Decision | Reason |
|---|---|---|
| FEEDBACK-D1 | Text length is counted in Unicode code points | matches PHP `mb_strlen`, so both implementations accept the same messages |
| FEEDBACK-D2 | Resends are recognised by an app-generated client id | the app can resend safely without an extra round trip |
| FEEDBACK-D3 | Missing or malformed fields return 422, never 400 | one error shape for the app |

## 9. Known limitations, gaps and open questions
- **Test gaps:** FEEDBACK-R3, R4, R6, R11, R12, R13; Q2 (automated PII check of logs and telemetry); Q3 (concurrent sends).
- **Open (privacy):** account deletion does not yet erase or anonymise a member's feedback: `user_id` and the text stay (no foreign key clears it any more; domains/CLAUDE.md rule 11 says the erasure event must). Erase it, or keep it as
  anonymised feedback? The text itself may identify the member.
- **Not built:** review and handled state (issue 891).
