import type { NavKey } from './Sidebar';

/** Bottom tab bar shown only on narrow (mobile) viewports — mirrors
 *  mockups/mobile-*.png (Rooms / Agents / Pipes / Files / Settings). It drives
 *  the same navigation state as the desktop left rail. */
const TABS: { key: NavKey; label: string; glyph: string }[] = [
  { key: 'rooms', label: 'Rooms', glyph: '▦' },
  { key: 'agents', label: 'Agents', glyph: '✦' },
  { key: 'pipes', label: 'Pipes', glyph: '⤳' },
  { key: 'files', label: 'Files', glyph: '▤' },
  { key: 'settings', label: 'Settings', glyph: '⚙' },
];

export function MobileTabBar({ active, onNav }: { active: NavKey; onNav(key: NavKey): void }) {
  return (
    <nav className="mobile-tabbar" aria-label="Primary (mobile)">
      {TABS.map((tab) => {
        // The chat sub-view lives under the Rooms tab, so keep Rooms highlighted
        // while a room is open.
        const on = active === tab.key || (tab.key === 'rooms' && (active === 'home' || active === 'calls'));
        return (
          <button
            key={tab.key}
            type="button"
            className={`mtab${on ? ' active' : ''}`}
            aria-current={on ? 'page' : undefined}
            onClick={() => onNav(tab.key)}
          >
            <span className="mtab-glyph" aria-hidden="true">
              {tab.glyph}
            </span>
            <span className="mtab-label">{tab.label}</span>
          </button>
        );
      })}
    </nav>
  );
}
