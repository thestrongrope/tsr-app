# web-smoke

One Playwright check (Chromium only) that signs in on the web copy of the member app through the real page. Same code for a lane and for production.

## Settings (environment only, none has a default)

`WEB_SMOKE_APP_URL` (the app's address), `WEB_SMOKE_EMAIL`, `WEB_SMOKE_PASSWORD`. A missing one stops the run at once and names it. The password is never printed; trace, video, screenshots and the HTML report are off, and the only reporter is the console list.

## Run

```
cd tools/web-smoke && npm ci && npx playwright install chromium
WEB_SMOKE_APP_URL=... WEB_SMOKE_EMAIL=... WEB_SMOKE_PASSWORD=... npx playwright test
```

On a lane (synthetic member and emulator account): `docs/testing.md`, "Web sign-in check".

## What is asserted

1. Test "signing in": the app opens, shows the signed-out Home (the "Sign in or register" button); sign-in by email and password; the sign-in service answers 200; the browser then calls `/me` or `/me/permissions` on another origin than the app's, with a `Bearer` Authorization header, and gets 2xx; the guest invitation and the Sign In button are gone and the app shows content. Which signed-in screen appears is not asserted (a member with no profile sees profile completion).
2. Test "wrong password": the sign-in service answers 400, the member is not on profile completion, and no authenticated API call is made.

## What the member sees after a wrong password

Nothing. The app drops back to the signed-out Home within about half a second. No message, no snackbar, and nothing in the accessibility announcements (watched every 300 ms, plus a screenshot). Seen on the lane build (Flutter 3.47.2 profile build); the test therefore asserts only "not signed in". Finding for the owner: a failed sign-in gives no feedback.

## How the page is driven

- Flutter Web draws on a canvas. The test clicks the hidden `flt-semantics-placeholder` element, which turns the semantics tree on; then `getByRole` finds the buttons and the two text boxes ("Email", "Password").
- `fill` is not used. Keys are typed with `keyboard.type` (40 ms apart) after a 500 ms pause once the field is focused: typed at once, Flutter dropped characters (28 typed, 27 or fewer kept). The test checks the character count and fails with a clear message if keys were lost.

## Production

Run by the owner or CI with the three variables supplied from outside. The wrong-password test makes one failed attempt per run (two with the retry) against the real account's email; the password it sends is a fixed string, never the real one. Failed output files live in `test-results/` (ignored by git) and can hold the email.
