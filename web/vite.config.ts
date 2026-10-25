import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';
import pkg from './package.json' with { type: 'json' };

export default defineConfig({
  define: { __APP_VERSION__: JSON.stringify(pkg.version) },
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['icon-180.png'],
      manifest: {
        name: 'Language Reader',
        short_name: 'Reader',
        description: 'Read, look up and review German words. Synced across devices.',
        theme_color: '#0d1420',
        background_color: '#0d1420',
        display: 'standalone',
        start_url: '/',
        icons: [
          { src: '/icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: '/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any maskable' },
        ],
      },
      workbox: {
        // App shell is precached; dictionary shards are cached on first use (they never change per build).
        globPatterns: ['**/*.{js,css,html,png,svg}'],
        navigateFallbackDenylist: [/^\/api\//],
        runtimeCaching: [
          {
            urlPattern: ({ url }) => url.pathname.startsWith('/dict/'),
            handler: 'CacheFirst',
            options: { cacheName: 'dictionary', expiration: { maxEntries: 600 } },
          },
        ],
      },
    }),
  ],
  test: {
    environment: 'node',
    setupFiles: ['./src/test/setup.ts'],
  },
});
