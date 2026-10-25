// Port of DictionaryManager.lookupDetailed + DictionaryLanguageProfile (German) + conciseMeaning.
// The 47 MB SQLite file is split at build time into 256 small JSON shards (scripts/build_web_dictionary.py)
// served as static files from the CDN. The browser fetches only the shards it needs and the
// service worker caches them, so lookups work offline after first use.
import { normalize, stripEdgePunctuation } from './text';

export const SHARD_COUNT = 256;

/** FNV-1a over UTF-8 bytes. Must match the Python build script exactly. */
export function shardFor(key: string): number {
  let h = 0x811c9dc5;
  for (const b of new TextEncoder().encode(key)) {
    h ^= b;
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h % SHARD_COUNT;
}

interface SuffixRule { suffix: string; minimumStemLength: number }
const GERMAN_SUFFIX_RULES: SuffixRule[] = [
  { suffix: 'ern', minimumStemLength: 3 },
  { suffix: 'en', minimumStemLength: 3 },
  { suffix: 'er', minimumStemLength: 3 },
  { suffix: 'es', minimumStemLength: 3 },
  { suffix: 'em', minimumStemLength: 3 },
  { suffix: 'e', minimumStemLength: 3 },
  { suffix: 'n', minimumStemLength: 3 },
  { suffix: 's', minimumStemLength: 3 },
];
const PROFILES: Record<string, SuffixRule[]> = { de: GERMAN_SUFFIX_RULES };

export function candidateKeys(word: string, languageCode: string): string[] {
  const out: string[] = [];
  const add = (v: string, min = 1) => { if (v && [...v].length >= min && !out.includes(v)) out.push(v); };
  const normalized = normalize(word);
  const stripped = stripEdgePunctuation(normalized);
  add(normalized);
  add(stripped);
  for (const rule of PROFILES[languageCode] ?? []) {
    if (stripped.endsWith(rule.suffix)) add(stripped.slice(0, -rule.suffix.length), rule.minimumStemLength);
  }
  return out;
}

function stripLeadingMetadata(text: string): string {
  const patterns = [/^\s*\([^)]*\)\s*/, /^\s*\[[^\]]*\]\s*/, /^\s*\d+\.\s*/];
  let v = text;
  let progress = true;
  while (progress) {
    progress = false;
    for (const p of patterns) {
      if (p.test(v)) { v = v.replace(p, '').trim(); progress = true; }
    }
  }
  return v;
}

export function conciseMeaning(meaning: string): string {
  let v = meaning.trim();
  if (!v || v.startsWith('=')) return v;
  v = stripLeadingMetadata(v);
  const a = v.toLowerCase().indexOf(' - a)');
  if (a > 0) v = v.slice(0, a).trim() || v;
  const semi = v.indexOf(';');
  if (semi > 0) v = v.slice(0, semi).trim() || v;
  if (v.length > 140) {
    const comma = v.indexOf(',');
    if (comma >= 10) v = v.slice(0, comma).trim();
  }
  v = v.replace(/\s+/g, ' ').trim();
  while (/[.;,:]$/.test(v)) v = v.slice(0, -1).trim();
  return v;
}

function cleanMeaning(meaning: string, key: string): string | null {
  const c = conciseMeaning(meaning.trim());
  if (!c || c.toLowerCase() === key.toLowerCase()) return null;
  return c;
}

export type LookupPath = 'override' | 'direct' | 'suffix' | 'redirect' | 'cache' | 'none';
export interface LookupResult { word: string; normalizedKey: string; matchedKey: string | null; meaning: string | null; path: LookupPath }

export type ShardLoader = (languageCode: string, shard: number) => Promise<Record<string, string>>;

const shardCache = new Map<string, Promise<Record<string, string>>>();

export const fetchShard: ShardLoader = (languageCode, shard) => {
  const id = `${languageCode}/${shard}`;
  let p = shardCache.get(id);
  if (!p) {
    p = fetch(`/dict/${languageCode}/${shard}.json`).then((r) => (r.ok ? r.json() : {})).catch(() => {
      shardCache.delete(id); // allow retry once online again
      return {};
    });
    shardCache.set(id, p);
  }
  return p;
};

async function rawLookup(key: string, languageCode: string, load: ShardLoader): Promise<string | null> {
  const shard = await load(languageCode, shardFor(key));
  return shard[key] ?? null;
}

export async function lookup(
  word: string,
  languageCode: string,
  opts: { overrides?: Map<string, string>; load?: ShardLoader } = {},
): Promise<LookupResult> {
  const load = opts.load ?? fetchShard;
  const normalized = normalize(word);
  const none: LookupResult = { word, normalizedKey: normalized, matchedKey: null, meaning: null, path: 'none' };
  if (!normalized) return none;

  const override = opts.overrides?.get(normalized);
  if (override) return { ...none, matchedKey: normalized, meaning: override, path: 'override' };

  for (const key of candidateKeys(word, languageCode)) {
    const raw = await rawLookup(key, languageCode, load);
    if (raw == null) continue;
    const trimmed = raw.trim();
    if (trimmed.startsWith('=')) {
      const target = normalize(stripEdgePunctuation(trimmed.slice(1).trim()).replace(/\d+$/, '').trim());
      if (target && target !== key) {
        const redirected = await rawLookup(target, languageCode, load);
        const cleaned = redirected ? cleanMeaning(redirected, target) : null;
        if (cleaned) return { ...none, matchedKey: key, meaning: cleaned, path: 'redirect' };
      }
      continue;
    }
    const cleaned = cleanMeaning(trimmed, key);
    if (cleaned) return { ...none, matchedKey: key, meaning: cleaned, path: key === normalized ? 'direct' : 'suffix' };
  }
  return none;
}
