// Unit tests: pure logic ported from Swift. Each case mirrors a behaviour the iOS test suite relies on.
import { describe, expect, it } from 'vitest';
import { candidateKeys, conciseMeaning, lookup, shardFor } from './dictionary';
import { dueEntries, evaluateRound, spacedSessionPrompts } from './flashcards';
import { decodeStatus, newVocabEntry } from './models';
import { normalize, sentences, tokenize, uniqueWords } from './text';
import { lingqStatus } from './importers';

describe('text', () => {
  it('normalizes like TextNormalizer', () => expect(normalize('  Straße ')).toBe('straße'));
  it('tokenizes words and gaps', () => {
    const t = tokenize('Die Straße, war ruhig.');
    expect(t.filter((x) => x.isWord).map((x) => x.text)).toEqual(['Die', 'Straße', 'war', 'ruhig']);
    expect(t.map((x) => x.text).join('')).toBe('Die Straße, war ruhig.');
  });
  it('splits sentences', () => expect(sentences('Ich lese. Du schreibst!  Wir lernen?')).toHaveLength(3));
  it('dedupes words per sentence', () => expect(uniqueWords('Das Haus und das Auto').map((w) => w.normalizedKey)).toEqual(['das', 'haus', 'und', 'auto']));
});

describe('status', () => {
  it('maps legacy values like VocabStatus.init(from:)', () => {
    expect(decodeStatus('new')).toBe('level1');
    expect(decodeStatus('learning')).toBe('level2');
    expect(decodeStatus('bogus')).toBe('level1');
  });
  it('maps LingQ statuses', () => {
    expect(lingqStatus(0, null)).toBe('level1');
    expect(lingqStatus(2, 0)).toBe('level3');
    expect(lingqStatus(3, 3)).toBe('known');
  });
});

describe('dictionary', () => {
  it('shard hash matches the Python build script (FNV-1a)', () => {
    // Values computed with scripts/build_web_dictionary.py fnv1a() % 256
    expect(shardFor('woche')).toBe(SHARDS.woche);
    expect(shardFor('straße')).toBe(SHARDS['straße']);
  });
  it('generates German suffix candidates with minimum stem length', () => {
    expect(candidateKeys('Häusern,', 'de')).toEqual(['häusern,', 'häusern', 'häus', 'häuser']);
    expect(candidateKeys('des', 'de')).toEqual(['des']);
  });
  it('shortens meanings like conciseMeaning', () => {
    expect(conciseMeaning('week; twice a week; during the week')).toBe('week');
    expect(conciseMeaning('(der) 1. street.')).toBe('street');
  });
  it('resolves suffix and redirect lookups', async () => {
    const data: Record<string, string> = { woche: 'week; weeks', ging: '=gehen', gehen: 'to go' };
    const load = async () => data;
    expect((await lookup('Wochen', 'de', { load })).meaning).toBe('week');
    expect((await lookup('Wochen', 'de', { load })).path).toBe('suffix');
    expect((await lookup('ging', 'de', { load })).meaning).toBe('to go');
    expect((await lookup('xyz', 'de', { load })).path).toBe('none');
  });
});

describe('flashcards', () => {
  it('promotes after two perfect rounds, demotes on double miss', () => {
    const r1 = evaluateRound('level2', 0, ['correct', 'correct']);
    expect(r1).toEqual({ status: 'level2', nextConsecutiveSuccessRounds: 1, shouldRequeue: false });
    expect(evaluateRound('level2', 1, ['correct', 'correct']).status).toBe('level3');
    expect(evaluateRound('level2', 1, ['correct', 'wrong'])).toEqual({ status: 'level2', nextConsecutiveSuccessRounds: 0, shouldRequeue: true });
    expect(evaluateRound('level2', 0, ['wrong', 'wrong']).status).toBe('level1');
    expect(evaluateRound('level4', 1, ['correct', 'correct']).status).toBe('level4');
  });
  it('spaces second direction by a full pass and rotates', () => {
    const p = spacedSessionPrompts(['a', 'b', 'c', 'd']);
    expect(p.map((x) => x.entryKey + x.direction[0])).toEqual(['aw', 'bw', 'cw', 'dw', 'cm', 'dm', 'am', 'bm']);
  });
  it('orders due entries oldest first and skips known/future', () => {
    const mk = (k: string, status: 'level1' | 'known', dueAt: string | null) => ({ ...newVocabEntry({ word: k, normalizedKey: k, languageCode: 'de', meaning: '' }), status, dueAt });
    const now = new Date('2026-01-10T00:00:00Z');
    const list = [mk('late', 'level1', '2026-01-09T00:00:00Z'), mk('early', 'level1', '2026-01-01T00:00:00Z'), mk('future', 'level1', '2026-02-01T00:00:00Z'), mk('k', 'known', null)];
    expect(dueEntries(list, now).map((e) => e.word)).toEqual(['early', 'late']);
  });
});

// Filled from the Python implementation so both sides are checked against the same numbers.
const SHARDS: Record<string, number> = { woche: 127, 'straße': 24 };
