import { useEffect, useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../lib/db';
import { lookup, type LookupResult } from '../lib/dictionary';
import { isBackendConfigured, translate } from '../lib/api';
import { makeScopedKey, PROGRESSION, STATUS_INFO, type VocabStatus } from '../lib/models';
import { normalize } from '../lib/text';
import { ignoreWord, setWordStatus, updateVocabMeaning } from '../lib/repo';

interface Props { word: string; lang: string; onClose: () => void }

export function WordSheet({ word, lang, onClose }: Props) {
  const key = normalize(word);
  const entry = useLiveQuery(() => db.vocab.get(makeScopedKey(lang, key)), [lang, key]);
  const live = entry && !entry.deletedAt ? entry : undefined;
  const [result, setResult] = useState<LookupResult | null>(null);
  const [cloud, setCloud] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState('');

  useEffect(() => {
    let cancelled = false;
    setLoading(true); setCloud(null);
    lookup(word, lang).then(async (r) => {
      if (cancelled) return;
      setResult(r);
      // Cloud fallback (DictionaryManager.lookupDetailedWithRemoteFallback) only when the dictionary misses.
      if (!r.meaning && isBackendConfigured()) {
        try { const t = await translate(word, lang); if (!cancelled && t.toLowerCase() !== key) setCloud(t); } catch { /* offline or not signed in */ }
      }
      if (!cancelled) setLoading(false);
    });
    return () => { cancelled = true; };
  }, [word, lang, key]);

  const meaning = live?.meaning || result?.meaning || cloud || '';
  const set = (s: VocabStatus) => void setWordStatus(word, meaning || null, s, lang);

  return (
    <>
      <div className="sheet-backdrop" onClick={onClose} />
      <div className="sheet" role="dialog" aria-label={`Word ${word}`}>
        <div className="grabber" />
        <div className="spread">
          <div className="word">{word}</div>
          {live && <span className="status-dot" data-s={live.status}>{STATUS_INFO[live.status].shortLabel}</span>}
        </div>
        {editing ? (
          <div className="row" style={{ margin: '10px 0' }}>
            <input className="input" value={draft} onChange={(e) => setDraft(e.target.value)} autoFocus />
            <button className="btn" onClick={async () => {
              if (!live) await setWordStatus(word, draft, 'level1', lang);
              else await updateVocabMeaning(live.scopedKey, draft);
              setEditing(false);
            }}>Save</button>
          </div>
        ) : (
          <div className="meaning" onClick={() => { setDraft(meaning); setEditing(true); }}>
            {loading && !meaning ? <span className="muted">Looking up…</span> : meaning || <span className="muted">No meaning yet. Tap to add one.</span>}
            {!live?.meaning && !result?.meaning && cloud && <span className="muted small"> (machine translation)</span>}
          </div>
        )}
        {result?.matchedKey && result.matchedKey !== key && <div className="muted small">Matched as “{result.matchedKey}”</div>}

        <div className="levels">
          {PROGRESSION.map((s) => (
            <button key={s} className={`lvl ${live?.status === s ? 'on' : ''}`} data-s={s} onClick={() => set(s)}>
              {s === 'known' ? '✓' : STATUS_INFO[s].shortLabel}
            </button>
          ))}
        </div>
        {live && <div className="muted small" style={{ marginBottom: 12 }}>{STATUS_INFO[live.status].meaningLabel}</div>}
        <div className="row">
          {!live && <button className="btn primary" style={{ flex: 1 }} onClick={() => set('level1')}>Add to Vocab</button>}
          <button className="btn" onClick={async () => { await ignoreWord(word, lang); onClose(); }}>Ignore</button>
          <button className="btn" onClick={onClose}>Done</button>
        </div>
      </div>
    </>
  );
}
