import { defineConfig, devices } from '@playwright/test';

// Browser-level UX regression harness (issue #51). Runs the real app against
// the VITE_MOCK=1 fixture client — no daemon, no network — so every flow is
// deterministic. Four viewport projects cover the responsive contract:
// the two desktop grids (wide + narrowed columns) and the two compact
// (max-width: 900px) phone layouts the mockups target.
//
// Run with `npm run test:e2e` (boots its own dev server on 4173).

const PORT = 4173;

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  // No retries: a test that only passes on retry is a regression this harness
  // exists to catch, not to paper over.
  retries: 0,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : [['list']],
  use: {
    baseURL: `http://127.0.0.1:${PORT}`,
    // Failures must preserve the full evidence trail (screenshot, trace,
    // console errors — the latter attached by the fixture in e2e/fixtures.ts).
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'desktop-1440x900',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } },
    },
    {
      name: 'desktop-920x800',
      use: { ...devices['Desktop Chrome'], viewport: { width: 920, height: 800 } },
    },
    {
      name: 'mobile-390x844',
      use: { ...devices['Desktop Chrome'], viewport: { width: 390, height: 844 }, hasTouch: true },
    },
    {
      name: 'mobile-320x568',
      use: { ...devices['Desktop Chrome'], viewport: { width: 320, height: 568 }, hasTouch: true },
    },
  ],
  webServer: {
    command: `npm run dev -- --host 127.0.0.1 --port ${PORT} --strictPort`,
    url: `http://127.0.0.1:${PORT}`,
    env: { VITE_MOCK: '1' },
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
  },
});
