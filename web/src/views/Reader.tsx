import { memo, useEffect, useMemo, useRef, useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../lib/db';
import { isBackendConfigured, translate } from '../lib/api';
import { lookup } from '../lib/dictionary';
import { STATUS_INFO, type VocabStatus } from '../lib/models';
import { markDocumentOpened, setWordStatus, ignoreWord, updateDocument } from '../lib/repo';
import { paragraphs, sentences, tokenize, uniqueWords } from '../lib/text';
import { useLearningState, visualState, type VisualState } from '../lib/hooks';
import { WordSheet } from './WordSheet';

const cls = (s: VisualState) =>
  s === 'new' ? 'w new' : s === 'level1' ? 'w lv1' : s === 'level2' ? 'w lv2' : s === 'level3' ? 'w lv3' : s === 'level4' ? 'w lv4' : 'w';

const Paragraph = memo(function Paragraph({ text, lang, stateOf, selected, onTap }: {
  text: string; lang: string; stateOf: (w: string) => VisualState; selected: string | null; onTap: (w: string) => void;
}) {
  const tokens = useMemo(() => tokenize(text, lang), [text, lang]);
  return (
    <p>
      {tokens.map((t, i) => t.isWord
        ? <span key={i} className={`${cls(stateOf(t.text))}${selected === t.text ? ' sel' : ''}`} onClick={() => onTap(t.text)}>{t.text}</span>
        : <span key={i}>{t.text}</span>)}
    </p>
  );
});

export function Reader({ docId, onClose }: { docId: string; onClose: () => void }) {
  const doc = useLiveQuery(() => db.documents.get(docId), [docId]);
  const lang = doc?.languageCodeRaw ?? 'de'; // Reader follows the document's language, not the global picker
  const { statusByKey, ignored } = useLearningState(lang);
  const [mode, setMode] = useState<'word' | 'sentence'>('word');
  const [selected, setSelected] = useState<string | null>(null);
  const [progress, setProgress] = useState(0);
  const bodyRef = useRef<HTMLDivElement>(null);
  const restored = useRef(false);

  useEffect(() => { void markDocumentOpened(docId); }, [docId]);

  // Restore reading position once, then save it (debounced) as you scroll. It syncs across devices.
  useEffect(() => {
    const el = bodyRef.current;
    if (!el || !doc || restored.current || mode !== 'word') return;
    restored.current = true;
    requestAnimationFrame(() => { el.scrollTop = (doc.readingProgress ?? 0) * (el.scrollHeight - el.clientHeight); });
  }, [doc, mode]);
  useEffect(() => {
    const el = bodyRef.current;
    if (!el || mode !== 'word') return;
    let t: ReturnType<typeof setTimeout>;
    const onScroll = () => {
      const p = el.scrollHeight > el.clientHeight ? el.scrollTop / (el.scrollHeight - el.clientHeight) : 1;
      setProgress(p);
      clearTimeout(t);
      t = setTimeout(() => void updateDocument(docId, { readingProgress: Math.round(p * 1000) / 1000 }), 1200);
    };
    el.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
    return () => { el.removeEventListener('scroll', onScroll); clearTimeout(t); };
  }, [docId, mode, doc?.body]);

  const stateOf = useMemo(() => (w: string) => visualState(w, statusByKey, ignored), [statusByKey, ignored]);
  const paras = useMemo(() => paragraphs(doc?.body ?? ''), [doc?.body]);

  if (!doc) return null;

  return (
    <div className="reader">
      <div className="reader-top">
        <button className="icon-btn" aria-label="Close reader" onClick={onClose}>✕</button>
        <div className="progress"><div style={{ width: `${Math.round(progress * 100)}%` }} /></div>
      </div>
      {mode === 'word' ? (
        <div className="reader-body" ref={bodyRef}>
          <div className="reader-text">
            <h2>{doc.title}</h2>
            {paras.map((p, i) => <Paragraph key={i} text={p} lang={lang} stateOf={stateOf} selected={selected} onTap={setSelected} />)}
          </div>
        </div>
      ) : (
        <SentenceMode body={doc.body} lang={lang} stateOf={stateOf} onTap={setSelected} onProgress={setProgress} />
      )}
      <div className="floating">
        <button className="pill" onClick={() => setMode(mode === 'word' ? 'sentence' : 'word')}>
          ☰ {mode === 'word' ? 'Sentence View' : 'Page View'}
        </button>
      </div>
      {selected && <WordSheet word={selected} lang={lang} onClose={() => setSelected(null)} />}
    </div>
  );
}

/** SentencePagerView: one sentence per page + its new/learning words with quick actions. */
function SentenceMode({ body, lang, stateOf, onTap, onProgress }: {
  body: string; lang: string; stateOf: (w: string) => VisualState; onTap: (w: string) => void; onProgress: (p: number) => void;
}) {
  const list = useMemo(() => sentences(body, lang), [body, lang]);
  const [i, setI] = useState(0);
  const [translation, setTranslation] = useState<{ i: number; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [meanings, setMeanings] = useState<Record<string, string | null>>({});
  const sentence = list[i] ?? '';
  const words = useMemo(() => uniqueWords(sentence, lang).filter((w) => {
    const s = stateOf(w.word);
    return s !== 'known' && s !== 'ignored';
  }), [sentence, lang, stateOf]);

  useEffect(() => { onProgress(list.length ? (i + 1) / list.length : 0); }, [i, list.length, onProgress]);
  useEffect(() => {
    let cancelled = false;
    Promise.all(uniqueWords(sentence, lang).map(async (w) => [w.normalizedKey, (await lookup(w.word, lang)).meaning] as const))
      .then((pairs) => { if (!cancelled) setMeanings(Object.fromEntries(pairs)); });
    return () => { cancelled = true; };
  }, [sentence, lang]);

  const doTranslate = async () => {
    setBusy(true);
    try { setTranslation({ i, text: await translate(sentence, lang) }); }
    catch (e) { setTranslation({ i, text: `Translation unavailable (${e instanceof Error ? e.message : 'error'})` }); }
    finally { setBusy(false); }
  };

  return (
    <div className="reader-body">
      <div className="reader-text">
        <div className="muted small">Sentence {i + 1} of {list.length}</div>
        <div className="sentence">
          {tokenize(sentence, lang).map((t, k) => t.isWord
            ? <span key={k} className={cls(stateOf(t.text))} onClick={() => onTap(t.text)}>{t.text}</span>
            : <span key={k}>{t.text}</span>)}
        </div>
        {translation?.i === i && <div className="translation">{translation.text}</div>}
        <div className="row" style={{ marginBottom: 16 }}>
          <button className="btn" disabled={i === 0} onClick={() => setI(i - 1)}>← Prev</button>
          <button className="btn" disabled={i >= list.length - 1} onClick={() => setI(i + 1)}>Next →</button>
          {isBackendConfigured() && <button className="btn" disabled={busy} onClick={doTranslate}>{busy ? 'Translating…' : 'Translate'}</button>}
        </div>
        {words.map((w) => {
          const s = stateOf(w.word);
          const meaning = meanings[w.normalizedKey] ?? null;
          return (
            <div key={w.normalizedKey} className="card" style={{ padding: 12, marginBottom: 8 }}>
              <div className="spread">
                <div onClick={() => onTap(w.word)}>
                  <b>{w.word}</b> <span className="muted">{meaning ?? '—'}</span>
                </div>
                {s !== 'new' && <span className="status-dot" data-s={s}>{STATUS_INFO[s as VocabStatus].shortLabel}</span>}
              </div>
              <div className="row" style={{ marginTop: 8 }}>
                {s === 'new' && <button className="chip" onClick={() => setWordStatus(w.word, meaning, 'level1', lang)}>+ Level 1</button>}
                <button className="chip" onClick={() => setWordStatus(w.word, meaning, 'known', lang)}>✓ Known</button>
                <button className="chip" onClick={() => ignoreWord(w.word, lang)}>Ignore</button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
