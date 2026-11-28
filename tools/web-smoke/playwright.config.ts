import { defineConfig, devices } from '@playwright/test';

// Chromium only. Nothing that records typed text is on: no trace, no video, no screenshot, no HTML report.
// One retry at most; every wait has its own bound (see the spec) and the whole run is capped.
export default defineConfig({
  testDir: '.',
  testMatch: 'sign-in.spec.ts',
  fullyParallel: false,
  workers: 1,
  retries: 1,
  timeout: 40_000,
  globalTimeout: 110_000,
  expect: { timeout: 15_000 },
  reporter: [['list']],
  use: {
    ...devices['Desktop Chrome'],
    trace: 'off',
    video: 'off',
    screenshot: 'off',
    actionTimeout: 10_000,
    navigationTimeout: 20_000,
  },
  projects: [{ name: 'chromium', use: { browserName: 'chromium' } }],
});
