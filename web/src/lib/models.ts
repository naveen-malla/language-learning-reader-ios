// Ported 1:1 from the iOS SwiftData models (Document.swift, VocabEntry.swift).
// Field names are kept identical to Swift so data can move between apps without mapping.
// Sync-only fields (updatedAt, deletedAt, _dirty) are additions, not renames.

export type SupportedLanguage = 'de' | 'kn';
export const SUPPORTED_LANGUAGES: { code: SupportedLanguage; displayName: string; shortLabel: string; hasDictionary: boolean }[] = [
  { code: 'de', displayName: 'German', shortLabel: 'DE', hasDictionary: true },
  { code: 'kn', displayName: 'Kannada', shortLabel: 'KN', hasDictionary: false },
];

export type VocabStatus = 'level1' | 'level2' | 'level3' | 'level4' | 'known';
export const LEARNING_LEVELS: VocabStatus[] = ['level1', 'level2', 'level3', 'level4'];
export const PROGRESSION: VocabStatus[] = ['level1', 'level2', 'level3', 'level4', 'known'];

export const STATUS_INFO: Record<VocabStatus, { displayName: string; shortLabel: string; meaningLabel: string }> = {
  level1: { displayName: 'Level 1', shortLabel: '1', meaningLabel: 'Just added, review often.' },
  level2: { displayName: 'Level 2', shortLabel: '2', meaningLabel: 'Recognize in context with light effort.' },
  level3: { displayName: 'Level 3', shortLabel: '3', meaningLabel: 'Mostly familiar, occasional review.' },
  level4: { displayName: 'Level 4', shortLabel: '4', meaningLabel: 'Confident recall, rare review.' },
  known: { displayName: 'Known', shortLabel: 'Known', meaningLabel: 'Fully known, hide from practice lists.' },
};

export const isLearning = (s: VocabStatus) => s !== 'known';

/** Same legacy mapping as VocabStatus.init(from:) in Swift. */
export function decodeStatus(raw: string | null | undefined): VocabStatus {
  switch (raw) {
    case 'new': return 'level1';
    case 'learning': return 'level2';
    case 'level1': case 'level2': case 'level3': case 'level4': case 'known': return raw;
    default: return 'level1';
  }
}

/** Fields every synced row carries. ISO-8601 strings, so they sort and compare as text. */
export interface SyncFields {
  updatedAt: string;
  deletedAt: string | null;
  /** 1 = changed locally, not yet pushed. Local-only, never sent to the server. */
  _dirty?: 0 | 1;
}

export type DocumentSourceType = 'text' | 'youtube' | 'sample';

export interface Document extends SyncFields {
  id: string;
  title: string;
  body: string;
  languageCodeRaw: string | null;
  createdAt: string;
  sourceTypeRaw: DocumentSourceType | null;
  sourceURL: string | null;
  sourceVideoID: string | null;
  sourceChannel: string | null;
  sourceChannelID: string | null;
  sourceCategory: string | null;
  sourceDurationSeconds: number | null;
  thumbnailURL: string | null;
  subtitleCuesRaw: string | null;
  translatedSubtitleCuesRaw: string | null;
  importModeRaw: string | null;
  autoBatchID: string | null;
  firstOpenedAt: string | null;
  lastOpenedAt: string | null;
  /** Web addition: reading position (0..1) so you resume where you stopped on any device. */
  readingProgress: number | null;
}

export interface VocabEntry extends SyncFields {
  id: string;
  normalizedKey: string;
  /** `${languageCode}|${normalizedKey}`; the natural key used for sync. */
  scopedKey: string;
  languageCodeRaw: string | null;
  word: string;
  meaning: string;
  status: VocabStatus;
  createdAt: string;
  lastSeenAt: string;
  encounterCount: number;
  dueAt: string | null;
  srsIntervalDays: number | null;
  srsEaseFactor: number | null;
  srsRepetition: number | null;
  srsLapseCount: number | null;
  isSuspended: boolean | null;
  srsStability: number | null;
  srsDifficulty: number | null;
  srsAlgorithm: string | null;
}

/** IgnoredWordsStore lived in UserDefaults on iOS; here it is a synced table. */
export interface IgnoredWord extends SyncFields {
  scopedKey: string;
  languageCodeRaw: string;
  normalizedKey: string;
}

/** FlashcardStatsStore per-day counters. */
export interface FlashcardDailyStats extends SyncFields {
  scopedKey: string; // `${languageCode}|${YYYY-MM-DD}`
  languageCodeRaw: string;
  day: string;
  reviewed: number;
  correct: number;
}

export const makeScopedKey = (languageCode: string, normalizedKey: string) => `${languageCode}|${normalizedKey}`;

export const nowISO = () => new Date().toISOString();

export function newDocument(partial: Pick<Document, 'title' | 'body' | 'languageCodeRaw'> & Partial<Document>): Document {
  const now = nowISO();
  return {
    id: crypto.randomUUID(),
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
    sourceTypeRaw: 'text',
    sourceURL: null,
    sourceVideoID: null,
    sourceChannel: null,
    sourceChannelID: null,
    sourceCategory: null,
    sourceDurationSeconds: null,
    thumbnailURL: null,
    subtitleCuesRaw: null,
    translatedSubtitleCuesRaw: null,
    importModeRaw: null,
    autoBatchID: null,
    firstOpenedAt: null,
    lastOpenedAt: null,
    readingProgress: null,
    ...partial,
  };
}

export function newVocabEntry(p: { word: string; normalizedKey: string; languageCode: string; meaning: string; status?: VocabStatus }): VocabEntry {
  const now = nowISO();
  return {
    id: crypto.randomUUID(),
    normalizedKey: p.normalizedKey,
    scopedKey: makeScopedKey(p.languageCode, p.normalizedKey),
    languageCodeRaw: p.languageCode,
    word: p.word,
    meaning: p.meaning,
    status: p.status ?? 'level1',
    createdAt: now,
    lastSeenAt: now,
    updatedAt: now,
    deletedAt: null,
    encounterCount: 1,
    dueAt: null,
    srsIntervalDays: 0,
    srsEaseFactor: 2.5,
    srsRepetition: 0,
    srsLapseCount: 0,
    isSuspended: false,
    srsStability: null,
    srsDifficulty: null,
    srsAlgorithm: null,
  };
}
