// Local database (IndexedDB via Dexie). This is the app's source of truth on each device:
// every read comes from here, so the app works offline and feels instant.
// The sync engine (sync.ts) reconciles these tables with the backend.
import Dexie, { type Table } from 'dexie';
import type { Document, FlashcardDailyStats, IgnoredWord, VocabEntry } from './models';

export interface MetaRow { key: string; value: string }

export class ReaderDB extends Dexie {
  documents!: Table<Document, string>;
  vocab!: Table<VocabEntry, string>; // primary key: scopedKey
  ignored!: Table<IgnoredWord, string>; // primary key: scopedKey
  stats!: Table<FlashcardDailyStats, string>; // primary key: scopedKey
  meta!: Table<MetaRow, string>;

  constructor(name = 'language-reader') {
    super(name);
    this.version(1).stores({
      documents: 'id, languageCodeRaw, updatedAt, _dirty',
      vocab: 'scopedKey, languageCodeRaw, status, dueAt, updatedAt, _dirty',
      ignored: 'scopedKey, languageCodeRaw, _dirty',
      stats: 'scopedKey, languageCodeRaw, _dirty',
      meta: 'key',
    });
  }
}

export const db = new ReaderDB();

export const SYNCED_TABLES = ['documents', 'vocab', 'ignored', 'stats'] as const;
export type SyncedTable = (typeof SYNCED_TABLES)[number];

export async function getMeta(key: string, d: ReaderDB = db): Promise<string | null> {
  return (await d.meta.get(key))?.value ?? null;
}
export async function setMeta(key: string, value: string, d: ReaderDB = db): Promise<void> {
  await d.meta.put({ key, value });
}
