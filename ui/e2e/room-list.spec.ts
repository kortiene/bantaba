import { expect, test, MOCK_ROOMS, HOMONYM_ROOM } from './fixtures';

// Searchable, stateful room list (issue #64): search by name and short id,
// lifecycle filtering that separates Left/Removed without losing them, device-
// local pin/archive that survives nav + reload, and the device-local unread dot
// wired to the #63 evidence primitives. Runs unchanged on every viewport.

function search(page: import('@playwright/test').Page) {
  return page.getByRole('searchbox', { name: 'Search rooms by name or short id' });
}

test('search narrows the list by name and clearing restores it', async ({ app, page }) => {
  await app.gotoRoomsList();

  await search(page).fill('design');
  await expect(app.roomItem(MOCK_ROOMS.design)).toHaveCount(1);
  await expect(app.roomItem(MOCK_ROOMS.workspace)).toHaveCount(0);

  // An unmatched query is a distinct state from an empty account: the list says
  // so and offers a way back, without ever claiming "no rooms".
  await search(page).fill('nothing matches this');
  const nav = page.getByRole('navigation', { name: 'Rooms' });
  await expect(nav.getByText('No rooms match', { exact: false })).toBeVisible();
  await nav.getByRole('button', { name: 'Clear' }).click();
  await expect(search(page)).toHaveValue('');
  await expect(app.roomItem(MOCK_ROOMS.workspace)).toHaveCount(1);
});

test('search by short id isolates one homonymous room', async ({ app, page }) => {
  await app.gotoRoomsList();

  // Both Bug Triage rows show a short id while both are visible.
  await expect(app.roomItem(HOMONYM_ROOM)).toHaveCount(2);
  const disambig = (await app.roomItem(HOMONYM_ROOM).first().locator('.room-disambig').innerText()).trim();

  // Searching that room's leading hex — the id the user reads, not the wire
  // namespace — isolates it from its twin and from unrelated rooms.
  await search(page).fill(disambig.slice(0, 4));
  await expect(app.roomItem(HOMONYM_ROOM)).toHaveCount(1);
  await expect(app.roomItem(MOCK_ROOMS.design)).toHaveCount(0);

  // With its twin filtered out it is no longer a homonym, so the disambiguator
  // that named it is gone — the short-id set is recomputed over the visible
  // subset (docs/room-workbench.md, decision 6).
  await expect(app.roomItem(HOMONYM_ROOM).locator('.room-disambig')).toHaveCount(0);
});

test('lifecycle filter separates Left/Removed without losing them', async ({ app, page }) => {
  await app.gotoPopulated();

  // Make a departed room the honest way: leave one.
  await app.openRoom(MOCK_ROOMS.review);
  await app.goToRoomDest('People');
  await app.rightPanel.getByRole('button', { name: 'Leave', exact: true }).click();
  await page.getByRole('dialog').getByRole('button', { name: 'Leave room' }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0, { timeout: 10_000 });
  await app.showRoomsList();

  // Active filter hides the left room…
  await app.filterChip('Active').click();
  await expect(app.roomItem(MOCK_ROOMS.review)).toHaveCount(0);
  await expect(app.roomItem(MOCK_ROOMS.design)).toHaveCount(1);

  // …but it is not lost: the Left & removed filter shows it, expanded, disabled.
  await app.filterChip('Left & removed').click();
  await expect(app.roomItem(MOCK_ROOMS.review)).toBeVisible();
  await expect(app.roomItem(MOCK_ROOMS.review)).toBeDisabled();
  await expect(app.roomItem(MOCK_ROOMS.review)).toContainText('Left');
  await expect(app.roomItem(MOCK_ROOMS.design)).toHaveCount(0);

  // Under All it tucks into the collapsed disclosure, still reachable.
  await app.filterChip('All').click();
  await expect(app.roomItem(MOCK_ROOMS.review)).toHaveCount(0);
  await app.showDeparted();
  await expect(app.roomItem(MOCK_ROOMS.review)).toBeVisible();
});

test('pinning floats a room and persists across navigation and reload', async ({ app, page }) => {
  await app.gotoRoomsList();

  await page.getByRole('button', { name: `Pin ${MOCK_ROOMS.design}` }).click();
  const pinned = page.locator('.room-section-pinned');
  await expect(pinned).toContainText(MOCK_ROOMS.design);
  await expect(page.getByRole('button', { name: `Unpin ${MOCK_ROOMS.design}` })).toBeVisible();

  // Survives a room round-trip…
  await app.openRoom(MOCK_ROOMS.main);
  await app.showRoomsList();
  await expect(page.locator('.room-section-pinned')).toContainText(MOCK_ROOMS.design);

  // …and a full reload (device-local, jeliya.rooms.v1).
  await page.reload();
  await expect(app.sidebar).toBeVisible();
  await expect(page.locator('.room-section-pinned')).toContainText(MOCK_ROOMS.design);

  // And it reverses.
  await page.getByRole('button', { name: `Unpin ${MOCK_ROOMS.design}` }).click();
  await expect(page.locator('.room-section-pinned')).toHaveCount(0);
});

test('archiving tucks a room into a reversible bucket', async ({ app, page }) => {
  await app.gotoRoomsList();

  await page.getByRole('button', { name: `Archive ${MOCK_ROOMS.workspace}` }).click();
  // Out of the main list…
  await expect(app.roomItem(MOCK_ROOMS.workspace)).toHaveCount(0);
  // …into the Archived disclosure, restorable.
  await page.getByRole('navigation', { name: 'Rooms' }).getByRole('button', { name: /Archived/ }).click();
  await expect(app.roomItem(MOCK_ROOMS.workspace)).toBeVisible();
  await page.getByRole('button', { name: `Restore ${MOCK_ROOMS.workspace}` }).click();
  await expect(app.roomItem(MOCK_ROOMS.workspace)).toBeVisible();
});

test('an unread dot marks activity newer than this device last saw, and clears on view', async ({ app, page }) => {
  await app.gotoRoomsList();
  // Freshly seeded: nothing has changed since the baseline, so nothing is unread.
  await expect(page.locator('.unread-dot')).toHaveCount(0);

  // Simulate a returning user: rewind every last-seen mark, so the rooms' real
  // recency now sits past it. This exercises isRoomUnread honestly — no faked
  // state, no receipt implied.
  await page.evaluate(() => {
    const marks = JSON.parse(localStorage.getItem('jeliya.lastSeen') ?? '{}');
    for (const id of Object.keys(marks)) marks[id] = 1;
    localStorage.setItem('jeliya.lastSeen', JSON.stringify(marks));
  });
  await page.reload();
  await expect(app.sidebar).toBeVisible();

  // The Design System row now shows the unread dot with its accessible label.
  await expect(app.roomItem(MOCK_ROOMS.design).locator('.unread-dot')).toHaveCount(1);
  await expect(app.roomItem(MOCK_ROOMS.design)).toContainText('Unread');

  // Viewing it clears the dot (the mark advances to the newest event seen).
  // Wait for the room's content to actually load — the mark only advances once
  // room.open has returned the timeline, so a bounce-out before it loads keeps
  // the room honestly unread.
  await app.openRoom(MOCK_ROOMS.design);
  await expect(app.timeline.getByText('Tokens v2 exploration lives here.')).toBeVisible();
  await app.showRoomsList();
  await expect(app.roomItem(MOCK_ROOMS.design).locator('.unread-dot')).toHaveCount(0);
});
