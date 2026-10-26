// Port of FlashcardDeck.swift (SimpleLevelScheduler, FlashcardRoundEvaluator, FlashcardDeck).
import type { VocabEntry, VocabStatus } from './models';
import { isLearning } from './models';

export type FlashcardDirection = 'wordToMeaning' | 'meaningToWord';
export type FlashcardBinaryAnswer = 'correct' | 'wrong';
export interface FlashcardPrompt { entryKey: string; direction: FlashcardDirection }

export const DEFAULT_SESSION_WORD_LIMIT = 5;
export const SESSION_WORD_LIMIT_OPTIONS = [5, 10, 15, 20, 30];
const DAY_MS = 24 * 60 * 60 * 1000;

export function intervalDays(status: VocabStatus): number | null {
  switch (status) {
    case 'level1': return 1;
    case 'level2': return 3;
    case 'level3': return 7;
    case 'level4': return 15;
    case 'known': return null;
  }
}

export function dueDate(status: VocabStatus, base: Date): string | null {
  const d = intervalDays(status);
  return d == null ? null : new Date(base.getTime() + d * DAY_MS).toISOString();
}

export function isDue(e: VocabEntry, now = new Date()): boolean {
  if (!isLearning(e.status) || e.isSuspended === true || e.deletedAt) return false;
  if (!e.dueAt) return true;
  return e.dueAt <= now.toISOString();
}

export function promoted(s: VocabStatus): VocabStatus {
  return ({ level1: 'level2', level2: 'level3', level3: 'level4', level4: 'level4', known: 'level4' } as const)[s];
}
export function demoted(s: VocabStatus): VocabStatus {
  return ({ level1: 'level1', level2: 'level1', level3: 'level2', level4: 'level3', known: 'level4' } as const)[s];
}

export interface RoundOutcome { status: VocabStatus; nextConsecutiveSuccessRounds: number; shouldRequeue: boolean }

export function evaluateRound(status: VocabStatus, consecutiveSuccessRounds: number, answers: FlashcardBinaryAnswer[]): RoundOutcome {
  if (answers.length !== 2) throw new Error('A round must include two directional answers');
  const correct = answers.filter((a) => a === 'correct').length;
  if (correct === 2) {
    let streak = Math.max(0, consecutiveSuccessRounds) + 1;
    let next = status;
    if (streak >= 2) { next = promoted(status); streak = 0; }
    return { status: next, nextConsecutiveSuccessRounds: streak, shouldRequeue: false };
  }
  if (correct === 1) return { status, nextConsecutiveSuccessRounds: 0, shouldRequeue: true };
  return { status: demoted(status), nextConsecutiveSuccessRounds: 0, shouldRequeue: true };
}

export function dueEntries(entries: VocabEntry[], now = new Date(), limit = 80): VocabEntry[] {
  const far = '0000';
  return entries
    .filter((e) => isDue(e, now))
    .sort((a, b) =>
      (a.dueAt ?? far).localeCompare(b.dueAt ?? far) ||
      a.lastSeenAt.localeCompare(b.lastSeenAt) ||
      a.createdAt.localeCompare(b.createdAt))
    .slice(0, limit);
}

export function nextDueDate(entries: VocabEntry[], now = new Date()): string | null {
  const n = now.toISOString();
  const future = entries.filter((e) => isLearning(e.status) && !e.isSuspended && !e.deletedAt && e.dueAt && e.dueAt > n).map((e) => e.dueAt!);
  return future.length ? future.sort()[0] : null;
}

export const promptsFor = (entryKey: string): FlashcardPrompt[] => [
  { entryKey, direction: 'wordToMeaning' },
  { entryKey, direction: 'meaningToWord' },
];

export function spacedSessionPrompts(keys: string[]): FlashcardPrompt[] {
  if (!keys.length) return [];
  const first = keys.map((k) => ({ entryKey: k, direction: 'wordToMeaning' as const }));
  let second = keys;
  if (keys.length > 2) {
    const pivot = Math.max(1, Math.floor(keys.length / 2)) % keys.length;
    second = [...keys.slice(pivot), ...keys.slice(0, pivot)];
  }
  return [...first, ...second.map((k) => ({ entryKey: k, direction: 'meaningToWord' as const }))];
}

export function sessionPrompts(entries: VocabEntry[], now = new Date(), limit = DEFAULT_SESSION_WORD_LIMIT): FlashcardPrompt[] {
  return spacedSessionPrompts(dueEntries(entries, now, limit).map((e) => e.scopedKey));
}
