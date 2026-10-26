import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { registerSW } from 'virtual:pwa-register';
import App from './App';
import { seedSamplesIfEmpty } from './lib/importers';
import { startSyncLoop } from './lib/sync';
import './styles.css';

// Service worker: caches the app shell + dictionary shards so the app opens offline.
registerSW({ immediate: true });

// Ask the browser not to evict our IndexedDB data under storage pressure.
void navigator.storage?.persist?.();

window.addEventListener('unhandledrejection', (e) => console.error('[unhandled]', e.reason));

seedSamplesIfEmpty()
  .catch((e) => console.error('[seed]', e))
  .finally(() => {
    createRoot(document.getElementById('root')!).render(<StrictMode><App /></StrictMode>);
    startSyncLoop();
  });
