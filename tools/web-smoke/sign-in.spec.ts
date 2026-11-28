import { expect, test, type Page, type Response } from '@playwright/test';

// Sign-in check of the web copy of the member app. Settings come from the environment only; nothing defaults to production.
function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is not set. Set WEB_SMOKE_APP_URL, WEB_SMOKE_EMAIL and WEB_SMOKE_PASSWORD (see tools/web-smoke/README.md).`);
  }
  return value;
}

const appUrl = required('WEB_SMOKE_APP_URL');
const email = required('WEB_SMOKE_EMAIL');
const password = required('WEB_SMOKE_PASSWORD');
// A fixed value that is not the member's password, so a failed attempt never carries a near copy of the real one.
const wrongPassword = 'web-smoke-not-the-password';

const SIGNED_OUT_INVITE = 'Sign in or register';
const PROFILE_SCREEN = 'Complete Your Profile';
const SIGN_IN_SERVICE_PATH = 'accounts:signInWithPassword';
const PAUSE_AFTER_FOCUS_MS = 500;
const KEY_DELAY_MS = 40;

// The member calls the API makes once it has a signed-in user.
const AUTHENTICATED_PATHS = ['/me', '/me/permissions'];

async function openSignedOutHome(page: Page): Promise<void> {
  await page.goto(appUrl);
  // Flutter draws on a canvas; the semantics tree (what getByRole reads) is off until this hidden placeholder is activated.
  await page.locator('flt-semantics-placeholder').waitFor({ state: 'attached', timeout: 20_000 });
  await page.locator('flt-semantics-placeholder').evaluate((el: HTMLElement) => el.click());
  await expect(page.getByRole('button', { name: SIGNED_OUT_INVITE })).toBeVisible({ timeout: 15_000 });
}

// Flutter drops keys typed into a field that has only just been focused, and keys typed too fast. So: click, pause, type
// key by key, then check how many characters arrived (a count only: the value is never read back into a message).
async function typeInto(page: Page, label: string, text: string): Promise<void> {
  const field = page.getByRole('textbox', { name: label });
  await field.click({ timeout: 10_000 });
  await page.waitForTimeout(PAUSE_AFTER_FOCUS_MS);
  await page.keyboard.type(text, { delay: KEY_DELAY_MS });
  const typed = (await field.inputValue()).length;
  if (typed !== text.length) {
    throw new Error(`The ${label} field holds ${typed} characters after typing ${text.length}: the keystrokes were not all taken.`);
  }
}

async function submitCredentials(page: Page, pass: string): Promise<void> {
  await page.getByRole('button', { name: SIGNED_OUT_INVITE }).click({ timeout: 10_000 });
  await typeInto(page, 'Email', email);
  await typeInto(page, 'Password', pass);
  await page.getByRole('button', { name: 'Sign In' }).click({ timeout: 10_000 });
}

function isAuthenticatedApiCall(response: Response): boolean {
  const url = new URL(response.url());
  return AUTHENTICATED_PATHS.includes(url.pathname) && new URL(appUrl).origin !== url.origin;
}

test('the app opens signed out, and signing in with email and password signs the member in', async ({ page }) => {
  await openSignedOutHome(page);

  // The API call is waited for before the click, so a fast answer cannot be missed. The predicate reads the header and keeps no value.
  const signInAnswer = page.waitForResponse((response) => response.url().includes(SIGN_IN_SERVICE_PATH), { timeout: 30_000 });
  const apiCall = page.waitForResponse(
    async (response) => isAuthenticatedApiCall(response) && ((await response.request().allHeaders())['authorization'] ?? '').startsWith('Bearer '),
    { timeout: 30_000 },
  );
  // If the sign-in service refuses first, this wait would only add a second, noisy error at the end of the test; the first one is the real one.
  apiCall.catch(() => undefined);
  await submitCredentials(page, password);

  const serviceStatus = (await signInAnswer).status();
  expect(serviceStatus, `the sign-in service answered ${serviceStatus} (400 is a wrong email or password)`).toBe(200);
  const response = await apiCall;
  expect(response.status(), `${new URL(response.url()).pathname} answered ${response.status()}`).toBeLessThan(300);
  expect(response.status()).toBeGreaterThanOrEqual(200);

  // Signed in on screen: the guest invitation is gone and the app shows content. For a member with no profile that is profile completion.
  await expect(page.getByRole('button', { name: SIGNED_OUT_INVITE })).toBeHidden({ timeout: 15_000 });
  await expect(page.getByRole('button', { name: 'Sign In' })).toBeHidden({ timeout: 15_000 });
  await expect.poll(async () => (await page.locator('flt-semantics-host').innerText()).trim().length, { timeout: 15_000 }).toBeGreaterThan(0);
});

test('a wrong password does not sign the member in', async ({ page }) => {
  await openSignedOutHome(page);

  const authenticatedCalls: string[] = [];
  page.on('response', (response) => {
    if (isAuthenticatedApiCall(response)) authenticatedCalls.push(new URL(response.url()).pathname);
  });
  const refusal = page.waitForResponse((response) => response.url().includes(SIGN_IN_SERVICE_PATH), { timeout: 30_000 });
  await submitCredentials(page, wrongPassword);

  expect((await refusal).status(), 'the sign-in service refuses the wrong password').toBe(400);

  // The app answers a refusal by going back to the signed-out Home, or by staying on the form. Either way the member is not signed in.
  await expect(page.getByRole('button', { name: SIGNED_OUT_INVITE }).or(page.getByRole('button', { name: 'Sign In' }))).toBeVisible({ timeout: 15_000 });
  await expect(page.getByText(PROFILE_SCREEN)).toBeHidden();
  await page.waitForTimeout(2_000);
  expect(authenticatedCalls, 'no authenticated API call was made').toEqual([]);
});
