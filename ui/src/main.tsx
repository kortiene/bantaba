import { createRoot } from 'react-dom/client';
import App from './App';
import { createClient } from './lib/client';
import { L10nProvider } from './l10n/strings';
import './styles.css';

// One client for the whole app lifetime (WebSocket or VITE_MOCK=1 fixtures).
const client = createClient();

// Surface which transport this build runs against (the same honest string
// diagnostics reports). The browser regression suite refuses to drive
// anything but the mock transport — this is its guard rail against silently
// attaching to a dev server that talks to a real daemon.
document.documentElement.dataset.jeliyaTransport = client.describe();

// The provider sits ABOVE the app so every consumer — including the dialogs
// that render through portals — resolves copy from the same locale, and so a
// language switch reaches all of them on the next render (docs/i18n.md, rule 1:
// copy is resolved at render time, never captured into state).
createRoot(document.getElementById('root')!).render(
  <L10nProvider>
    <App client={client} />
  </L10nProvider>,
);
