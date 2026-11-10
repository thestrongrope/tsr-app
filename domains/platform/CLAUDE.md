# domains/platform/

The domain for things every member touches but no other domain owns: health, feedback, and
(later) app version, release notes, geo, lookups and the audit log. This is the **one implemented
example**: copy its layout when you build another domain (`domains/CLAUDE.md`).

## Status

| Slice | Route | State |
|---|---|---|
| `health` | `GET /health` | built; process is up, does not check the DB |
| `submit-feedback` | `POST /feedback` | built; mirrors the PHP route in tsr-account, contract tests pass |
| review feedback (issue 891) | not designed | `feedback:review:all` exists in the catalog; no slice yet |
| app version, release notes, geo, lookups, audit log | - | not started; PHP still serves them |

## What it owns

- Table `feedback`, in schema `platform` (`api/PlatformContext.cs`; migrations in `api/Migrations/`).
- Permissions `feedback:create:self`, `feedback:review:all`
  (seeded by access's first migration; the catalog itself belongs to `access`).
- Event `platform.feedback_submitted`.
- Also, as platform tables with no domain: `outbox`, `outbound_messages`, `schema_migrations`,
  `admin_access_log`. `outbox` is mapped by `PlatformContext` (schema `platform`) and written inside the caller's transaction by `shared/api/Outbox.cs`.

## Dependencies

`access` only (`PlatformModule.Dependencies`), for `Permissions.CanAsync`. The caller comes from
`identity`'s middleware through `HttpContext.GetCaller()`; that is shared plumbing, not a
dependency.

## Where things are

| Need | File |
|---|---|
| Words to use (Feedback, Client id, Replay ...) | `spec/glossary.md` |
| The HTTP contract, field shapes and limits | `spec/api.yaml` |
| Events this domain publishes | "Events" below |
| Behaviour over HTTP, any implementation | `spec/tests/*.hurl` (needs the dev stack up) |
| Module: registration, routes, dependencies | `api/PlatformModule.cs` |
| One use case end to end | `api/features/submit-feedback/SubmitFeedback.cs` |
| Rules shared by slices | `api/domain/` (`ClientId`, `FeedbackText`) |
| The feedback screen (Flutter) | `app/lib/features/submit_feedback/` |

## Events

Written to the `outbox` table in the same transaction as the change (`shared/api/Outbox.cs`).
Nothing relays or reads them yet (the relay comes with the foundation step), so this table replaces an AsyncAPI file
until a consumer exists. Payloads are camelCase JSON, like the API, and carry ids, never member text.

| Event type | When | Payload |
|---|---|---|
| `platform.feedback_submitted` | A new feedback row commits. A replay of the same `clientId` publishes nothing. | `feedbackId` (int ≥ 1), `userId` (int ≥ 1, `users.id`), `submittedAt` (UTC date-time, the API's clock) |

## Rules specific to this domain

1. **Feedback text counts Unicode code points**, like PHP `mb_strlen`, so both implementations
   accept and refuse the same messages. Do not switch to `string.Length` or grapheme counts.
2. **A replay is not a duplicate.** Same member + same `clientId` returns the stored id with 201.
   The unique key `(user_id, client_id)` is what makes this safe under concurrent sends.
3. **Events carry no message text.** `FeedbackSubmitted` has ids and a time only; the text is
   member content and stays in the `feedback` table.
4. If you change a limit, an error or a field, change `spec/` and `spec/tests` in the same edit,
   and check the PHP route still passes the contract tests.

## Checks

```
dotnet test domains/platform/api/tests            # unit
dotnet test db/tests                              # feedback row + outbox row in one transaction (Docker)
hurl --test --variable base_url=http://localhost:8088 --variable auth_header=X-Dev-Token --variable auth_value=900001 domains/platform/spec/tests/submit-feedback.hurl   # contract, stack up (:8088)
flutter analyze domains/platform/app && (cd domains/platform/app && flutter test)
```
