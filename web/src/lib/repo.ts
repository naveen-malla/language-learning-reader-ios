// All writes go through these functions. Each one stamps updatedAt and marks the row dirty,
// which is the contract the sync engine relies on. UI code never writes to Dexie directly.
import { db, type ReaderDB } from './db';
import { dueDate, evaluateRound, intervalDays, type FlashcardBinaryAnswer } from './flashcards';
import {
  makeScopedKey, newDocument, newVocabEntry, nowISO,
  type Document, type VocabEntry, type VocabStatus,
} from './models';
import { normalize } from './text';

type Listener = () => void;
const listeners = new Set<Listener>();
/** Sync engine subscribes here to push soon after local changes. */
export const onLocalChange = (fn: Listener) => { listeners.add(fn); return () => listeners.delete(fn); };
const changed = () => listeners.forEach((fn) => fn());
export const notifyLocalChange = changed;

const dirty = <T extends object>(row: T): T => ({ ...row, updatedAt: nowISO(), _dirty: 1 as const });

export async function addDocument(title: string, body: string, languageCode: string, d: ReaderDB = db): Promise<Document> {
  const doc = { ...newDocument({ title: title.trim() || 'Untitled', body, languageCodeRaw: languageCode }), _dirty: 1 as const };
  await d.documents.put(doc);
  changed();
  return doc;
}

export async function updateDocument(id: string, patch: Partial<Document>, d: ReaderDB = db) {
  const cur = await d.documents.get(id);
  if (!cur) return;
  await d.documents.put(dirty({ ...cur, ...patch }));
  changed();
}

export async function deleteDocument(id: string, d: ReaderDB = db) {
  // Soft delete (tombstone) so the deletion itself can sync to other devices.
  const cur = await d.documents.get(id);
  if (!cur) return;
  await d.documents.put(dirty({ ...cur, deletedAt: nowISO() }));
  changed();
}

export async function markDocumentOpened(id: string, d: ReaderDB = db) {
  const cur = await d.documents.get(id);
  if (!cur) return;
  const now = nowISO();
  await d.documents.put(dirty({ ...cur, firstOpenedAt: cur.firstOpenedAt ?? now, lastOpenedAt: now }));
  changed();
}

/** DocumentReaderView.addToVocab: create or update an entry and un-ignore it. */
export async function setWordStatus(
  word: string, meaning: string | null, status: VocabStatus, languageCode: string, d: ReaderDB = db,
): Promise<VocabEntry | null> {
  const key = normalize(word);
  if (!key) return null;
  const scopedKey = makeScopedKey(languageCode, key);
  return d.transaction('rw', d.vocab, d.ignored, async () => {
    const ign = await d.ignored.get(scopedKey);
    if (ign && !ign.deletedAt) await d.ignored.put(dirty({ ...ign, deletedAt: nowISO() }));

    const existing = await d.vocab.get(scopedKey);
    let entry: VocabEntry;
    if (existing && !existing.deletedAt) {
      entry = {
        ...existing,
        status,
        lastSeenAt: nowISO(),
        encounterCount: existing.encounterCount + 1,
        meaning: existing.meaning || meaning || '',
      };
    } else {
      // Like iOS: new entries have dueAt = null, which means "due now" for flashcards.
      entry = newVocabEntry({ word, normalizedKey: key, languageCode, meaning: meaning ?? '', status });
      if (existing) entry.id = existing.id; // revive a tombstoned row, keep identity
    }
    entry = dirty(entry);
    await d.vocab.put(entry);
    changed();
    return entry;
  });
}

export async function updateVocabMeaning(scopedKey: string, meaning: string, d: ReaderDB = db) {
  const cur = await d.vocab.get(scopedKey);
  if (!cur) return;
  await d.vocab.put(dirty({ ...cur, meaning }));
  changed();
}

export async function deleteVocab(scopedKey: string, d: ReaderDB = db) {
  const cur = await d.vocab.get(scopedKey);
  if (!cur) return;
  await d.vocab.put(dirty({ ...cur, deletedAt: nowISO() }));
  changed();
}

export async function ignoreWord(word: string, languageCode: string, d: ReaderDB = db) {
  const key = normalize(word);
  if (!key) return;
  const scopedKey = makeScopedKey(languageCode, key);
  await d.ignored.put(dirty({ scopedKey, languageCodeRaw: languageCode, normalizedKey: key, deletedAt: null, updatedAt: '' }));
  changed();
}

/** FlashcardsView.submitAnswer, applied once both directions of a word were answered. */
export async function applyRound(scopedKey: string, answers: FlashcardBinaryAnswer[], d: ReaderDB = db) {
  const e = await d.vocab.get(scopedKey);
  if (!e) return null;
  const outcome = evaluateRound(e.status, Math.max(0, e.srsRepetition ?? 0), answers);
  const now = new Date();
  await d.vocab.put(dirty({
    ...e,
    status: outcome.status,
    srsRepetition: outcome.nextConsecutiveSuccessRounds,
    lastSeenAt: now.toISOString(),
    dueAt: dueDate(outcome.status, now),
    srsIntervalDays: intervalDays(outcome.status),
    srsAlgorithm: null,
  }));
  changed();
  return outcome;
}

export async function bumpEncounter(scopedKey: string, d: ReaderDB = db) {
  const e = await d.vocab.get(scopedKey);
  if (e) await d.vocab.put(dirty({ ...e, encounterCount: e.encounterCount + 1 }));
}

export async function markKnown(scopedKey: string, d: ReaderDB = db) {
  const e = await d.vocab.get(scopedKey);
  if (!e) return;
  await d.vocab.put(dirty({
    ...e, status: 'known', srsRepetition: 0, lastSeenAt: nowISO(), dueAt: null,
    srsIntervalDays: null, srsAlgorithm: null, encounterCount: e.encounterCount + 1,
  }));
  changed();
}

const localDay = (date = new Date()) => {
  const p = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${p(date.getMonth() + 1)}-${p(date.getDate())}`;
};

export async function recordAnswer(answer: FlashcardBinaryAnswer, languageCode: string, d: ReaderDB = db) {
  const day = localDay();
  const scopedKey = makeScopedKey(languageCode, day);
  const cur = (await d.stats.get(scopedKey)) ?? { scopedKey, languageCodeRaw: languageCode, day, reviewed: 0, correct: 0, deletedAt: null, updatedAt: '' };
  await d.stats.put(dirty({ ...cur, reviewed: cur.reviewed + 1, correct: cur.correct + (answer === 'correct' ? 1 : 0) }));
  changed();
}

export async function recentStats(languageCode: string, days: number, d: ReaderDB = db) {
  const keys: string[] = [];
  for (let i = 0; i < days; i++) keys.push(makeScopedKey(languageCode, localDay(new Date(Date.now() - i * 864e5))));
  const rows = (await d.stats.bulkGet(keys)).filter(Boolean);
  const reviewed = rows.reduce((s, r) => s + r!.reviewed, 0);
  const correct = rows.reduce((s, r) => s + r!.correct, 0);
  return { reviewed, correct, today: (await d.stats.get(keys[0])) ?? null };
}
