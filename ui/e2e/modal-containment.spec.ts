import { expect, test, MOCK_ROOMS, AppDriver } from './fixtures';
import type { Page } from '@playwright/test';

// Issue #56: create/join/leave dialogs must contain their in-flight
// operation — no dismissal path (Escape, backdrop, ✕, re-submit) may hide a
// pending non-cancellable request whose result would later mutate state —
// and destructive dialogs must never give the destructive action first focus.

const TICKET_SUFFIX = 'e2econtainmentticket00000000000000000000';

function modal(page: Page) {
  return page.getByRole('dialog');
}

async function openLeaveDialog(app: AppDriver, page: Page, room: string): Promise<void> {
  await app.openRoom(room);
  // The Members surface hosts Leave; its tab strip is part of the panel on
  // every breakpoint (compact reaches the panel through Files).
  await app.navigate('Files');
  await page.getByRole('tab', { name: 'Members', exact: false }).click();
  await app.rightPanel.getByRole('button', { name: 'Leave', exact: true }).click();
  await expect(modal(page)).toBeVisible();
}

test('create: success creates exactly one room and navigates once', async ({ app, page }) => {
  await app.gotoPopulated();
  if (app.compact) await app.mobileTab('Rooms').click();
  await page.getByRole('button', { name: 'Create Room', exact: true }).click();

  await modal(page).getByLabel('Room name').fill('Containment Test Room');
  await modal(page).getByRole('button', { name: 'Create room' }).click();

  await expect(modal(page)).toHaveCount(0);
  // Exactly one room of that name exists (no duplicate request fired) and it
  // was opened exactly once (compact stays on the rooms pane by design).
  await expect(app.roomItem('Containment Test Room')).toHaveCount(1);
  await expect(app.roomItem('Containment Test Room')).toContainText('Active');
  if (!app.compact) {
    await expect(
      page.getByRole('heading', { level: 1, name: 'Containment Test Room' }),
    ).toBeVisible();
  }
});

test('create: a pending request cannot be dismissed or duplicated', async ({ app, page }) => {
  await app.gotoPopulated({ mock_delay: 'room.create:1500' });
  if (app.compact) await app.mobileTab('Rooms').click();
  await page.getByRole('button', { name: 'Create Room', exact: true }).click();

  await modal(page).getByLabel('Room name').fill('Pending Room');
  const submit = modal(page).getByRole('button', { name: 'Create room' });
  await submit.click();

  // In flight: submit reflects it and every dismissal path is contained.
  await expect(modal(page).getByRole('button', { name: 'Creating…' })).toBeDisabled();
  await page.keyboard.press('Escape');
  await expect(modal(page)).toBeVisible();
  await page.locator('.modal-backdrop').click({ position: { x: 5, y: 5 } });
  await expect(modal(page)).toBeVisible();
  await expect(modal(page).getByRole('button', { name: 'Close' })).toBeDisabled();

  // Success still lands exactly once.
  await expect(modal(page)).toHaveCount(0, { timeout: 10_000 });
  await expect(app.roomItem('Pending Room')).toHaveCount(1);
});

test('create: failure keeps an actionable error in the dialog', async ({ app, page }) => {
  await app.gotoPopulated({ mock_fail: 'room.create:1' });
  if (app.compact) await app.mobileTab('Rooms').click();
  await page.getByRole('button', { name: 'Create Room', exact: true }).click();

  await modal(page).getByLabel('Room name').fill('Doomed Room');
  await modal(page).getByRole('button', { name: 'Create room' }).click();

  // The failure surfaces inside the dialog and interaction is restored.
  await expect(modal(page).locator('.error-note')).toBeVisible();
  await expect(modal(page).getByRole('button', { name: 'Create room' })).toBeEnabled();
  await expect(app.roomItem('Doomed Room')).toHaveCount(0);

  // No longer busy: Escape dismisses again.
  await page.keyboard.press('Escape');
  await expect(modal(page)).toHaveCount(0);
});

test('join: a pending join is contained, then applies its transition once', async ({
  app,
  page,
}) => {
  await app.gotoPopulated({ mock_ticket: TICKET_SUFFIX, mock_delay: 'room.join:1500' });
  if (app.compact) await app.mobileTab('Rooms').click();
  await page.getByRole('button', { name: 'Join with a ticket' }).click();

  await modal(page).getByLabel('Ticket').fill(`roomtkt1${TICKET_SUFFIX}`);
  await modal(page).getByRole('button', { name: 'Join room' }).click();

  await expect(modal(page).getByRole('button', { name: 'Joining…' })).toBeDisabled();
  await page.keyboard.press('Escape');
  await expect(modal(page)).toBeVisible();
  await page.locator('.modal-backdrop').click({ position: { x: 5, y: 5 } });
  await expect(modal(page)).toBeVisible();
  await expect(modal(page).getByRole('button', { name: 'Close' })).toBeDisabled();

  // Success: the dialog closes and the joined room opens, exactly once.
  await expect(modal(page)).toHaveCount(0, { timeout: 10_000 });
  if (app.compact) {
    await app.roomItem(MOCK_ROOMS.main).click();
  }
  await expect(page.getByRole('heading', { level: 1, name: MOCK_ROOMS.main })).toBeVisible();
  await expect(app.timeline).toBeVisible();
});

test('join: failure restores interaction with a real error', async ({ app, page }) => {
  await app.gotoPopulated();
  if (app.compact) await app.mobileTab('Rooms').click();
  await page.getByRole('button', { name: 'Join with a ticket' }).click();

  await modal(page).getByLabel('Ticket').fill(`roomtkt1${'x'.repeat(90)}`);
  await modal(page).getByRole('button', { name: 'Join room' }).click();

  await expect(modal(page).locator('.error-note')).toBeVisible();
  await expect(modal(page).getByRole('button', { name: 'Join room' })).toBeEnabled();
  await page.keyboard.press('Escape');
  await expect(modal(page)).toHaveCount(0);
});

test('leave: initial focus is Cancel and immediate Enter cannot leave', async ({ app, page }) => {
  await app.gotoPopulated();
  await openLeaveDialog(app, page, MOCK_ROOMS.review);

  // Safe initial focus: Cancel, never the destructive submit.
  await expect(modal(page).getByRole('button', { name: 'Cancel' })).toBeFocused();
  await page.keyboard.press('Enter');

  // Enter activated Cancel: dialog closed, membership untouched.
  await expect(modal(page)).toHaveCount(0);
  await expect(app.rightPanel.getByRole('button', { name: 'Leave', exact: true })).toBeVisible();
  if (app.compact) await app.mobileTab('Rooms').click();
  await expect(app.roomItem(MOCK_ROOMS.review)).not.toContainText('Left');
});

test('leave: a pending leave is contained, then applies once', async ({ app, page }) => {
  await app.gotoPopulated({ mock_delay: 'room.leave:1500' });
  await openLeaveDialog(app, page, MOCK_ROOMS.review);

  await modal(page).getByRole('button', { name: 'Leave room' }).click();
  await expect(modal(page).getByRole('button', { name: 'Leaving…' })).toBeDisabled();
  await expect(modal(page).getByRole('button', { name: 'Cancel' })).toBeDisabled();
  await page.keyboard.press('Escape');
  await expect(modal(page)).toBeVisible();
  await page.locator('.modal-backdrop').click({ position: { x: 5, y: 5 } });
  await expect(modal(page)).toBeVisible();
  await expect(modal(page).getByRole('button', { name: 'Close' })).toBeDisabled();

  // The departure lands exactly once: dialog closed, room marked Left,
  // navigation reset to the rooms surface.
  await expect(modal(page)).toHaveCount(0, { timeout: 10_000 });
  await expect(app.roomItem(MOCK_ROOMS.review)).toBeDisabled();
  await expect(app.roomItem(MOCK_ROOMS.review)).toContainText('Left');
  if (!app.compact) {
    await expect(page.getByText('Select a room')).toBeVisible();
  } else {
    await expect(app.sidebar).toBeVisible();
  }
});

test('leave: failure keeps the dialog actionable', async ({ app, page }) => {
  await app.gotoPopulated({ mock_fail: 'room.leave:1' });
  await openLeaveDialog(app, page, MOCK_ROOMS.review);

  await modal(page).getByRole('button', { name: 'Leave room' }).click();

  await expect(modal(page).locator('.error-note')).toBeVisible();
  await expect(modal(page).getByRole('button', { name: 'Leave room' })).toBeEnabled();
  await modal(page).getByRole('button', { name: 'Cancel' }).click();
  await expect(modal(page)).toHaveCount(0);
  // Still a member — the failure was real, nothing was applied.
  if (app.compact) await app.mobileTab('Rooms').click();
  await expect(app.roomItem(MOCK_ROOMS.review)).not.toContainText('Left');
});
