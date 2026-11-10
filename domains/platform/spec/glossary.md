# platform: glossary

Use these words in code, tests, screens and messages. If a word is missing, add it here first.

| Term | Meaning | In code |
|---|---|---|
| **Feedback** | One message a member sends to the TSR team from the app. Stored once, read later by a reviewer. | table `feedback`; `SubmitFeedback*` |
| **Text** | The words of one feedback message. Trimmed; 1 to 2000 characters, counted as Unicode code points (an Arabic mark counts as one). | `FeedbackText`; JSON `text`; column `message` |
| **Client id** | An id the app makes (a UUID) for one message before it sends it. 1 to 36 letters, digits or hyphens. | `ClientId`; JSON `clientId`; column `client_id` |
| **Replay** | A second send of the same message by the same member with the same client id, usually because the first reply was lost. It returns the stored id; it never stores a second row. | `StoreOnceAsync` |
| **Submitted** | The moment a new feedback row commits. A replay is not a new submission and publishes nothing. | event `platform.feedback_submitted` |
| **Handled** | A reviewer has dealt with the feedback. Not built yet (issue 891). | columns `handled_at`, `handled_by` |
| **Reviewer** | Someone holding `feedback:review:all` (role 1 by default). | permission |
| **Member** | A signed-in user. Defined by `identity` and `membership`; platform only sees the caller's user id. | `Caller.UserId` |
| **Health** | Whether the API process is up. Says nothing about the database. | `GET /health` |

## Words we do not use

- "Complaint", "ticket", "support request": it is **feedback**.
- "Message" for the JSON field: the field is **text** (the column is `message` for PHP's sake).
- "Duplicate" for a replay: a replay is expected and correct.
