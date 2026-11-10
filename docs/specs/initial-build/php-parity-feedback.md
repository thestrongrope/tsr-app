# PHP parity: POST /feedback

Run against tsr-account `develop` at commit `ed72cd98a1a9ed8f185ae031b6f29c9877e4cabf` (a clean
`git archive` in `build/parity-php/src/`), on synthetic data only. All PHP paths below are in that copy.
Stack, ports and rules: `tools/parity-php/README.md`.

## How to run
From the repo root. `P` is shorthand for the compose command (the env file feeds the compose variables).
```
P() { docker compose -p tsr-parity -f tools/parity-php/compose.parity.yml --env-file tools/parity-php/parity.env "$@"; }
mkdir -p build/parity-php/src && git -C ../tsr-account archive develop | tar -x -C build/parity-php/src   # first time only
P build api
P up -d --wait db firebase-emulator
P --profile load run --rm synth-build        # loads schema + synthetic members (about 1 min)
P up -d --wait api                           # PHP API on http://127.0.0.1:18091
```
Get a synthetic token (written to a gitignored file, never printed). Pick any member with token above 0,
a `.invalid` email, role 0, and no pending deletion request (the SQL gives one):
```
EMAIL=$(P exec -T db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" tsr_synth -N -e "select email from users u where token>0 and roleid=0 and email like \"%.invalid\" and token not in (select token from account_deletion_requests) order by token limit 1"')
tools/parity-php/mint-token.sh "$EMAIL"      # writes build/parity-php/token.vars
```
Run the file (PHP, then the new API; the new API takes its dev header):
```
hurl --test --variable base_url=http://127.0.0.1:18091 --variables-file build/parity-php/token.vars domains/platform/spec/tests/submit-feedback.hurl
hurl --test --variable base_url=http://localhost:8088 --variable auth_header=X-Dev-Token --variable auth_value=900001 domains/platform/spec/tests/submit-feedback.hurl
```

## Results
| Case | PHP | New API |
|---|---|---|
| 1 No sign-in is 401 + detail | pass | pass (earlier run) |
| 2 Member gets 201 + id | pass | pass (earlier run) |
| 3 Replay returns same id | pass | pass (earlier run) |
| 4 Empty text 422 | pass | pass (earlier run) |
| 5 Whitespace text 422 | pass | pass (earlier run) |
| 6 Text over 2000 is 422 | pass | pass (earlier run) |
| 7 Missing clientId 422 + detail | pass | pass (earlier run) |
| 8 Replay with upper-case clientId returns same id | pass (2026-11-10) | pass (2026-11-10) |

PHP: 10 of 10 requests pass (8 cases), run 2026-11-10 from `submit-feedback.hurl`. New API: the same file passes
(10 of 10) on the dev stack on 2026-11-10; "earlier run" in cases 1 to 7 is the previous recorded result.
Case 8 uses a fixed clientId (Hurl has no upper-case filter), so a rerun is itself a replay. PHP treats a
clientId in other case as the same message: no difference to record.

## Confirmed differences (response bodies seen on the PHP run)
1. Auth: PHP wants `Authorization: Bearer <Firebase token>`; the new API takes `X-Dev-Token`. Hurl variables cover both.
2. Auth failures beyond 401. No token: 401 "Not authenticated" (`web/api/mobile/lib/auth.php:110`). Bad token: 401
   "Invalid auth token" (:124). Valid token, no member row: 404 "User not found" (:149). Guest (token 0):
   403 "Registration incomplete" (:159). `api.yaml` lists 401/403/422 only; no 404.
3. Missing or non-string `clientId` or `text`, or a body that is not an object: 422 "clientId and text are required"
   (`web/api/mobile/routes/feedback.php:19`). FEEDBACK-R7 and `api.yaml` say "clientId is required".
4. Malformed `clientId` (bad characters, over 36): 422 "clientId is required" (`web/models/feedback.php:27`).
5. Empty or whitespace text: 422 "text is required" (:32). Over 2000: 422 "text must be at most 2000
   characters" (:35). Exactly 2000 is accepted (201).
6. Unparseable JSON: 422 "Invalid JSON body" (`web/api/mobile/bootstrap.php:67`).
7. Earlier claim withdrawn: no permission-name difference at HTTP level. The route asks for `feedback:create`
   (routes/feedback.php:13) and the catalog holds `feedback:create:self` (`web/models/permissions.php:38`),
   which is action plus scope; a role-0 member got 201.

Not testable over HTTP: same clientId from another member, outbox events (PHP route has none). Not run on the
new API: non-string `clientId` (not yet a case) and `{"clientId": 123}` (spike-learnings suspects 400); add both once it is up.

## Suggestion
Follow PHP for status codes and the 401/403/404 set: the live app already sees them. Add 404 to `api.yaml`.
Keep the tests asserting "a non-empty detail" rather than exact wording, and make the new API's 422 detail
"clientId and text are required" if exact text matters to the app. Keep `X-Dev-Token` as dev-only.
