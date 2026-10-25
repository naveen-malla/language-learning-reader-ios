import { useMemo, useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../lib/db';
import { PROGRESSION, STATUS_INFO, type VocabStatus } from '../lib/models';
import { deleteVocab, setWordStatus } from '../lib/repo';
import { useApp } from '../lib/hooks';
import { LangChip } from './LangChip';

const PAGE = 100;

function ago(iso: string) {
  const m = Math.round((Date.now() - new Date(iso).getTime()) / 60000);
  if (m < 60) return `${m} min`;
  if (m < 1440) return `${Math.round(m / 60)} hr`;
  return `${Math.round(m / 1440)} d`;
}

export function Vocab() {
  const { lang } = useApp();
  const [q, setQ] = useState('');
  const [filter, setFilter] = useState<VocabStatus | 'learning' | 'all'>('learning');
  const [limit, setLimit] = useState(PAGE);
  const entries = useLiveQuery(
    async () => (await db.vocab.where('languageCodeRaw').equals(lang).toArray()).filter((e) => !e.deletedAt),
    [lang], [],
  );
  const counts = useMemo(() => {
    const known = entries.filter((e) => e.status === 'known').length;
    return { total: entries.length, known, learning: entries.length - known };
  }, [entries]);
  const shown = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return entries
      .filter((e) => filter === 'all' || (filter === 'learning' ? e.status !== 'known' : e.status === filter))
      .filter((e) => !needle || e.normalizedKey.includes(needle) || e.meaning.toLowerCase().includes(needle))
      .sort((a, b) => b.lastSeenAt.localeCompare(a.lastSeenAt));
  }, [entries, q, filter]);

  return (
    <>
      <div className="topbar"><span /><LangChip /></div>
      <h1>Vocab</h1>
      <input className="input" placeholder="🔍 Search words or meanings" value={q} onChange={(e) => { setQ(e.target.value); setLimit(PAGE); }} />
      <div className="card" style={{ marginTop: 14 }}>
        <h2>Progress</h2>
        <div className="stats">
          <div className="stat"><b>{counts.total}</b><span>Total</span></div>
          <div className="stat"><b>{counts.learning}</b><span>Learning</span></div>
          <div className="stat"><b>{counts.known}</b><span>Known</span></div>
        </div>
        <div className="row">
          {(['learning', 'all', ...PROGRESSION] as const).map((f) => (
            <button key={f} className="chip" style={filter === f ? { borderColor: 'var(--new)', color: 'var(--new)' } : undefined}
              onClick={() => { setFilter(f); setLimit(PAGE); }}>
              {f === 'learning' ? 'Learning' : f === 'all' ? 'All' : STATUS_INFO[f].displayName}
            </button>
          ))}
        </div>
      </div>
      <div className="card">
        {shown.slice(0, limit).map((e) => (
          <div key={e.scopedKey} className="list-row">
            <div className="spread">
              <b style={{ fontSize: 18 }}>{e.word}</b>
              <select value={e.status} aria-label={`Status of ${e.word}`}
                onChange={(ev) => void setWordStatus(e.word, e.meaning, ev.target.value as VocabStatus, lang)}
                className="status-dot" data-s={e.status} style={{ border: 0 }}>
                {PROGRESSION.map((s) => <option key={s} value={s}>{STATUS_INFO[s].shortLabel}</option>)}
              </select>
            </div>
            <div className="muted">{e.meaning || '—'}</div>
            <div className="spread small muted" style={{ marginTop: 4 }}>
              <span>Seen {e.encounterCount}× · updated {ago(e.lastSeenAt)} ago</span>
              <button className="chip small" onClick={() => { if (confirm(`Remove “${e.word}”?`)) void deleteVocab(e.scopedKey); }}>Remove</button>
            </div>
          </div>
        ))}
        {!shown.length && <div className="muted">No words here yet. Tap words while reading to add them.</div>}
        {shown.length > limit && <button className="btn block" onClick={() => setLimit(limit + PAGE)}>Show more ({shown.length - limit})</button>}
      </div>
    </>
  );
}
