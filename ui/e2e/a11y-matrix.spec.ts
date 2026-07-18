import AxeBuilder from '@axe-core/playwright';
import { expect, test } from './fixtures';
import type { Page } from '@playwright/test';
import type { AppDriver } from './fixtures';
import { MOCK_ROOMS } from './fixtures';

/** The enforced accessibility gate (issue #76).
 *
 *  `a11y.spec.ts` proves the specific contracts issue #72 named. This file is
 *  the standing gate underneath it: EVERY axe rule, across every destination,
 *  at every viewport in the matrix — failing on any CRITICAL or SERIOUS
 *  violation.
 *
 *  The two are deliberately separate. A named-contract failure should say which
 *  contract broke; a sweep failure should say what regressed anywhere. Folding
 *  them together would mean every future rule addition edits the same file that
 *  documents #72's decisions.
 *
 *  Severity, not rule identity, is the bar. axe grades each violation
 *  critical / serious / moderate / minor; the criterion is "no critical or
 *  serious", so moderate and minor findings are REPORTED (attached to the test
 *  result) without failing the build. That keeps the gate honest — it neither
 *  blocks on cosmetics nor silently discards them.
 */

/** Rules excluded from the sweep, each with a reason that must stay true.
 *
 *  This list is a liability, not a convenience: every entry is a thing the gate
 *  cannot see. It is empty today, and the criterion is that any future entry
 *  carries a linked rationale rather than a shrug. */
const DOCUMENTED_FALSE_POSITIVES: { rule: string; why: string }[] = [];

const BLOCKING = new Set(['critical', 'serious']);

interface Destination {
  name: string;
  go: (app: AppDriver, page: Page) => Promise<void>;
}

/** Every destination the criterion names, reached the way a user reaches it. */
const DESTINATIONS: Destination[] = [
  { name: 'onboarding', go: async (app) => app.gotoFresh() },
  { name: 'rooms', go: async (app) => app.gotoRoomsList() },
  {
    name: 'room workbench (activity)',
    go: async (app) => {
      await app.gotoPopulated();
      await app.openRoom(MOCK_ROOMS.main);
    },
  },
  {
    name: 'room workbench (files)',
    go: async (app) => {
      await app.gotoPopulated();
      await app.openRoom(MOCK_ROOMS.main);
      await app.roomTab('Files').click();
      await expect(app.rightPanel).toBeVisible();
    },
  },
  {
    name: 'fleet',
    go: async (app, page) => {
      await app.gotoPopulated();
      await app.navigate('Agent Fleet');
      await expect(page.getByRole('main', { name: 'Agent Fleet' })).toBeVisible();
    },
  },
  {
    name: 'settings',
    go: async (app, page) => {
      await app.gotoPopulated();
      await app.navigate('Settings');
      await expect(page.getByRole('main', { name: 'Settings' })).toBeVisible();
    },
  },
  {
    name: 'dialog (join with a ticket)',
    go: async (app, page) => {
      await app.gotoRoomsList();
      await page.getByRole('button', { name: 'Join with a ticket' }).first().click();
      await expect(page.getByRole('dialog', { name: 'Join with a ticket' })).toBeVisible();
    },
  },
  {
    name: 'recoverable error (room not on this device)',
    go: async (app, page) => {
      await app.gotoPopulated();
      await page.goto('/rooms/blake3:0000000000000000000000000000000000000000000000000000000000000000/activity');
      await expect(page.getByRole('heading', { name: /isn’t on this device/ })).toBeVisible();
    },
  },
];

for (const dest of DESTINATIONS) {
  test(`no critical or serious accessibility violations: ${dest.name}`, async ({ app, page }, testInfo) => {
    await dest.go(app, page);

    let builder = new AxeBuilder({ page });
    for (const { rule } of DOCUMENTED_FALSE_POSITIVES) builder = builder.disableRules(rule);
    const { violations } = await builder.analyze();

    const format = (v: (typeof violations)[number]) =>
      `${v.id} (${v.impact}) — ${v.help}\n      ${v.nodes.map((n) => n.target.join(' ')).join('\n      ')}\n` +
      `      ${v.helpUrl}`;

    // Moderate and minor findings are recorded on the run, not thrown away, so
    // a reviewer can see what the gate chose not to block on.
    const advisory = violations.filter((v) => !BLOCKING.has(v.impact ?? ''));
    if (advisory.length > 0) {
      await testInfo.attach(`axe-advisory-${dest.name}`, {
        body: advisory.map(format).join('\n\n'),
        contentType: 'text/plain',
      });
    }

    const blocking = violations.filter((v) => BLOCKING.has(v.impact ?? ''));
    if (blocking.length > 0) {
      await testInfo.attach(`axe-violations-${dest.name}`, {
        body: blocking.map(format).join('\n\n'),
        contentType: 'text/plain',
      });
    }

    expect(
      blocking.length,
      `${dest.name} has ${blocking.length} critical/serious accessibility violation(s):\n\n    ` +
        blocking.map(format).join('\n\n    '),
    ).toBe(0);
  });
}

test('every documented false positive still carries a reason', () => {
  // The escape hatch cannot become a dumping ground. A rule may only be
  // excluded from the sweep with a rationale a reader can check.
  for (const { rule, why } of DOCUMENTED_FALSE_POSITIVES) {
    expect(why.length, `axe rule "${rule}" is excluded with no rationale`).toBeGreaterThan(30);
    expect(why, `axe rule "${rule}" needs a linked rationale (an issue or a spec URL)`).toMatch(/https?:\/\/|#\d+/);
  }
});
