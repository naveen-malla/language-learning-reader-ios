// Sync engine: offline-first, last-write-wins per row.
//
//   push: send rows with _dirty=1  ->  server keeps whichever copy has the newer updatedAt
//   pull: ask for rows with serverVersion > cursor  ->  apply unless our unsynced copy is newer
//
// serverVersion is a per-user counter the server bumps on every accepted write (a logical clock).
// Using it instead of timestamps avoids bugs from device clocks that disagree.
import { db, getMeta, setMeta, SYNCED_TABLES, type ReaderDB, type SyncedTable } from './db';
import { auth, isBackendConfigured, request } from './api';
import { onLocalChange } from './repo';

type Row = { updatedAt: string; _dirty?: 0 | 1 } & Record<string, unknown>;
export type Changes = Record<SyncedTable, Row[]>;

export interface PullResponse { changes: Changes; cursor: number; hasMore: boolean }
export interface PushResponse { applied: number; stale: number; cursor: number }

export interface Transport {
  push(changes: Changes): Promise<PushResponse>;
  pull(since: number): Promise<PullResponse>;
}

export const httpTransport: Transport = {
  push: (changes) => request<PushResponse>('/api/v1/sync/push', { method: 'POST', body: JSON.stringify(changes) }, 30000),
  pull: (since) => request<PullResponse>(`/api/v1/sync/pull?since=${since}`, {}, 30000),
};

const PUSH_BATCH = 500;
const strip = ({ _dirty, ...rest }: Row) => rest;

function emptyChanges(): Changes {
  return { documents: [], vocab: [], ignored: [], stats: [] };
}

export async function pushDirty(transport: Transport, d: ReaderDB = db): Promise<number> {
  let pushed = 0;
  for (const table of SYNCED_TABLES) {
    const t = d.table(table);
    for (;;) {
      const rows = (await t.where('_dirty').equals(1).limit(PUSH_BATCH).toArray()) as Row[];
      if (!rows.length) break;
      const changes = emptyChanges();
      changes[table] = rows.map(strip) as Row[];
      await transport.push(changes);
      // Clear the flag only if the row was not edited again while the request was in flight.
      await d.transaction('rw', t, async () => {
        for (const r of rows) {
          const pk = t.schema.primKey.keyPath as string;
          const cur = (await t.get(r[pk] as string)) as Row | undefined;
          if (cur && cur.updatedAt === r.updatedAt) await t.put({ ...cur, _dirty: 0 });
        }
      });
      pushed += rows.length;
      if (rows.length < PUSH_BATCH) break;
    }
  }
  return pushed;
}

export async function applyRemote(table: SyncedTable, rows: Row[], d: ReaderDB = db): Promise<number> {
  const t = d.table(table);
  const pk = t.schema.primKey.keyPath as string;
  let applied = 0;
  await d.transaction('rw', t, async () => {
    const locals = (await t.bulkGet(rows.map((r) => r[pk] as string))) as (Row | undefined)[];
    const toPut: Row[] = [];
    rows.forEach((remote, i) => {
      const local = locals[i];
      if (local && local._dirty === 1 && local.updatedAt > remote.updatedAt) return; // our edit is newer; push will win
      toPut.push({ ...remote, _dirty: 0 });
    });
    await t.bulkPut(toPut);
    applied = toPut.length;
  });
  return applied;
}

export async function pullAll(transport: Transport, d: ReaderDB = db): Promise<number> {
  let since = Number((await getMeta('sync.cursor', d)) ?? 0);
  let applied = 0;
  for (let guard = 0; guard < 1000; guard++) {
    const res = await transport.pull(since);
    for (const table of SYNCED_TABLES) applied += await applyRemote(table, res.changes[table] ?? [], d);
    since = res.cursor;
    await setMeta('sync.cursor', String(since), d);
    if (!res.hasMore) break;
  }
  return applied;
}

// ---- runtime scheduler + observable status for the UI ----

export type SyncState = { status: 'off' | 'idle' | 'syncing' | 'error' | 'offline'; lastSyncedAt: string | null; error: string | null };
let state: SyncState = { status: 'off', lastSyncedAt: null, error: null };
const subs = new Set<(s: SyncState) => void>();
const set = (patch: Partial<SyncState>) => { state = { ...state, ...patch }; subs.forEach((f) => f(state)); };
export const getSyncState = () => state;
export const subscribeSync = (f: (s: SyncState) => void) => { subs.add(f); return () => { subs.delete(f); }; };

let running: Promise<void> | null = null;

export function syncNow(transport: Transport = httpTransport): Promise<void> {
  if (!isBackendConfigured() || !auth.token) { set({ status: 'off' }); return Promise.resolve(); }
  if (!navigator.onLine) { set({ status: 'offline' }); return Promise.resolve(); }
  if (running) return running;
  set({ status: 'syncing', error: null });
  running = (async () => {
    try {
      await pushDirty(transport);
      await pullAll(transport);
      set({ status: 'idle', lastSyncedAt: new Date().toISOString() });
    } catch (e) {
      console.error('[sync] failed', e);
      set({ status: 'error', error: e instanceof Error ? e.message : String(e) });
    } finally {
      running = null;
    }
  })();
  return running;
}

let debounce: ReturnType<typeof setTimeout> | undefined;
export function startSyncLoop() {
  const soon = () => { clearTimeout(debounce); debounce = setTimeout(() => void syncNow(), 1500); };
  onLocalChange(soon);
  window.addEventListener('online', () => void syncNow());
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') void syncNow(); });
  setInterval(() => { if (document.visibilityState === 'visible') void syncNow(); }, 60_000);
  void syncNow();
}

export async function resetSyncCursor() {
  await setMeta('sync.cursor', '0');
}
