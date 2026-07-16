import { expect, test } from './fixtures';

// The top-level Agent Fleet dashboard.

test('shows the agent fleet with honest liveness', async ({ app, page }) => {
  await app.gotoPopulated();
  await app.navigate('Agents');

  const fleet = page.getByRole('region', { name: 'Agents fleet' });
  await expect(fleet).toBeVisible();
  await expect(fleet.getByRole('heading', { level: 1, name: 'Agents' })).toBeVisible();

  // Fixture agents are aggregated across rooms.
  await expect(fleet.getByText('Backend Agent').first()).toBeVisible();
  await expect(fleet.getByText('QA Agent').first()).toBeVisible();
  await expect(fleet.getByText('Research Agent').first()).toBeVisible();
});

test('searching filters the fleet list', async ({ app, page }) => {
  await app.gotoPopulated();
  await app.navigate('Agents');

  const fleet = page.getByRole('region', { name: 'Agents fleet' });
  await fleet.getByLabel('Search agents').fill('Research');
  await expect(fleet.getByText('Research Agent').first()).toBeVisible();
  await expect(fleet.getByText('Backend Agent')).toHaveCount(0);
});
