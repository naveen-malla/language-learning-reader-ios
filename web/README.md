# Language Reader: web app

The installable web version of the iOS app (Library, Reader, Vocab, Flashcards), synced through `../backend`.

## Run locally
```bash
cd web
npm install
cp .env.example .env.local      # VITE_API_URL=http://localhost:8000 (or empty = local-only)
npm run dev                     # http://localhost:5173, plus a LAN URL for your iPhone
npm test                        # unit + sync tests
npm run build                   # production build in dist/
```
To open it on your iPhone during development, use the "Network" URL that `npm run dev` prints (same Wi-Fi).
The service worker and "Add to Home Screen" only work on HTTPS, so do that after deploying.

## Layout
- `src/lib/models.ts`: types mirroring `Document.swift` / `VocabEntry.swift` (same field names)
- `src/lib/text.ts`, `dictionary.ts`, `flashcards.ts`: logic ported from Swift, covered by `core.test.ts`
- `src/lib/db.ts`, `repo.ts`: IndexedDB (local source of truth); every write goes through `repo.ts`
- `src/lib/sync.ts`: push/pull engine, covered by `sync.test.ts` (two simulated devices)
- `src/views/*`: screens
- `public/dict/de/`: 256 dictionary shards built from the iOS SQLite file (`npm run build:dict`)
