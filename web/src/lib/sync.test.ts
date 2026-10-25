// Integration-style tests for the sync engine: two simulated devices + an in-memory fake server
// that applies the same last-write-wins rule as the real backend.
import { describe, expect, it } from 'vitest';
import { ReaderDB } from './db';
import { pullAll, pushDirty, type Changes, type Transport } from './sync';
import { setWordStatus, addDocument } from './repo';

function fakeServer() {
  let version = 0;
  const tables: Record<string, Map<string, { row: Record<string, unknown>; v: number }>> = { documents: new Map(), vocab: new Map(), ignored: new Map(), stats: new Map() };
  const pk = (t: string) => (t === 'documents' ? 'id' : 'scopedKey');
  const transport: Transport = {
    async push(changes) {
      let applied = 0, stale = 0;
      for (const [t, rows] of Object.entries(changes)) for (const r of rows) {
        const key = r[pk(t)] as string;
        const cur = tables[t].get(key);
        if (cur && (cur.row.updatedAt as string) > r.updatedAt) { stale++; continue; }
        tables[t].set(key, { row: structuredClone(r), v: ++version }); applied++;
      }
      return { applied, stale, cursor: version };
    },
    async pull(since) {
      const changes = { documents: [], vocab: [], ignored: [], stats: [] } as unknown as Changes;
      for (const [t, m] of Object.entries(tables)) for (const { row, v } of m.values()) if (v > since) (changes as any)[t].push(structuredClone(row));
      return { changes, cursor: version, hasMore: false };
    },
  };
  return { transport, tables };
}

const sync = async (d: ReaderDB, t: Transport) => { await pushDirty(t, d); await pullAll(t, d); };
let n = 0;
const device = () => new ReaderDB(`test-${n++}`);

describe('sync', () => {
  it('a word added on the phone appears on the laptop', async () => {
    const { transport } = fakeServer();
    const phone = device(), laptop = device();
    await setWordStatus('Straße', 'street', 'level1', 'de', phone);
    await sync(phone, transport);
    await sync(laptop, transport);
    const e = await laptop.vocab.get('de|straße');
    expect(e?.meaning).toBe('street');
    expect(e?._dirty).toBe(0);
    expect(await phone.vocab.where('_dirty').equals(1).count()).toBe(0);
  });

  it('last write wins when both devices edit the same word', async () => {
    const { transport } = fakeServer();
    const a = device(), b = device();
    await setWordStatus('Woche', 'week', 'level1', 'de', a);
    await sync(a, transport); await sync(b, transport);
    await setWordStatus('Woche', 'week', 'level2', 'de', b); // older edit
    await new Promise((r) => setTimeout(r, 5));
    await setWordStatus('Woche', 'week', 'known', 'de', a); // newer edit
    await sync(b, transport); await sync(a, transport); await sync(b, transport);
    expect((await a.vocab.get('de|woche'))?.status).toBe('known');
    expect((await b.vocab.get('de|woche'))?.status).toBe('known');
  });

  it('keeps an unsynced local edit that is newer than the incoming row', async () => {
    const { transport } = fakeServer();
    const a = device(), b = device();
    const doc = await addDocument('T', 'Text', 'de', a);
    await sync(a, transport); await sync(b, transport);
    await b.documents.update(doc.id, { title: 'B newer', updatedAt: new Date(Date.now() + 10_000).toISOString(), _dirty: 1 });
    await pullAll(transport, b); // incoming copy is older than B's pending edit
    expect((await b.documents.get(doc.id))?.title).toBe('B newer');
  });
});
