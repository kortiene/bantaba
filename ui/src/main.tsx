import { createRoot } from 'react-dom/client';
import App from './App';
import { createClient } from './lib/client';
import './styles.css';

// One client for the whole app lifetime (WebSocket or VITE_MOCK=1 fixtures).
const client = createClient();

createRoot(document.getElementById('root')!).render(<App client={client} />);
