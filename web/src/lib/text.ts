// Ports of TextNormalizer, Tokenizer and SentenceTokenizer.
// Intl.Segmenter is the browser's equivalent of Apple's NLTokenizer (Safari 14.5+).

export interface Token {
  text: string;
  isWord: boolean;
}

/** TextNormalizer.normalize: trim + lowercase. */
export const normalize = (text: string) => text.trim().toLowerCase();

const EDGE_PUNCT = /^[\p{P}\p{S}]+|[\p{P}\p{S}]+$/gu;
export const stripEdgePunctuation = (text: string) => text.replace(EDGE_PUNCT, '');

const hasSegmenter = typeof Intl !== 'undefined' && 'Segmenter' in Intl;

export function tokenize(text: string, locale = 'de'): Token[] {
  if (hasSegmenter) {
    const seg = new Intl.Segmenter(locale, { granularity: 'word' });
    const out: Token[] = [];
    for (const s of seg.segment(text)) {
      const isWord = !!s.isWordLike;
      const last = out[out.length - 1];
      // Merge consecutive non-word gaps so the token list mirrors the Swift tokenizer (word, gap, word...).
      if (!isWord && last && !last.isWord) last.text += s.segment;
      else out.push({ text: s.segment, isWord });
    }
    return out;
  }
  return fallbackTokenize(text);
}

function fallbackTokenize(text: string): Token[] {
  const out: Token[] = [];
  const re = /[\p{L}\p{M}\p{Nd}]+|[^\p{L}\p{M}\p{Nd}]+/gu;
  for (const m of text.matchAll(re)) out.push({ text: m[0], isWord: /[\p{L}\p{Nd}]/u.test(m[0]) });
  return out;
}

export function sentences(text: string, locale = 'de'): string[] {
  const trimmed = text.trim();
  if (!trimmed) return [];
  if (!hasSegmenter) return trimmed.split(/(?<=[.!?])\s+/).filter(Boolean);
  const seg = new Intl.Segmenter(locale, { granularity: 'sentence' });
  const out = [...seg.segment(text)].map((s) => s.segment.trim()).filter(Boolean);
  return out.length ? out : [trimmed];
}

export function paragraphs(text: string): string[] {
  return text.split(/\n\s*\n/).map((p) => p.trim()).filter(Boolean);
}

/** Unique word tokens of a sentence, in order (SentenceInsightsBuilder). */
export function uniqueWords(sentence: string, locale = 'de'): { word: string; normalizedKey: string }[] {
  const seen = new Set<string>();
  const out: { word: string; normalizedKey: string }[] = [];
  for (const t of tokenize(sentence, locale)) {
    if (!t.isWord) continue;
    const key = normalize(t.text);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    out.push({ word: t.text, normalizedKey: key });
  }
  return out;
}
