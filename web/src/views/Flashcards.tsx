import { useEffect, useMemo, useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../lib/db';
import {
  dueEntries, nextDueDate, promptsFor, sessionPrompts, SESSION_WORD_LIMIT_OPTIONS,
  type FlashcardBinaryAnswer, type FlashcardPrompt,
} from '../lib/flashcards';
import { applyRound, bumpEncounter, markKnown, recentStats, recordAnswer } from '../lib/repo';
import { STATUS_INFO } from '../lib/models';
import { useApp, usePersistentState } from '../lib/hooks';
import { LangChip } from './LangChip';

export function Flashcards() {
  const { lang } = useApp();
  const [limit, setLimit] = usePersistentState<number>('flashcards_session_word_limit', 5);
  const entries = useLiveQuery(
    async () => (await db.vocab.where('languageCodeRaw').equals(lang).toArray()).filter((e) => !e.deletedAt),
    [lang], [],
  );
  const byKey = useMemo(() => new Map(entries.map((e) => [e.scopedKey, e])), [entries]);
  const due = useMemo(() => dueEntries(entries), [entries]);
  const stats = useLiveQuery(() => recentStats(lang, 7), [lang, entries]);

  const [queue, setQueue] = useState<FlashcardPrompt[]>([]);
  const [pending, setPending] = useState<Record<string, FlashcardBinaryAnswer[]>>({});
  const [requeued, setRequeued] = useState<Set<string>>(new Set());
  const [revealed, setRevealed] = useState(false);
  const [session, setSession] = useState({ reviewed: 0, correct: 0 });

  const active = queue.length > 0;
  const prompt = queue[0];
  const entry = prompt ? byKey.get(prompt.entryKey) : undefined;

  useEffect(() => { if (prompt && !entry) setQueue((q) => q.slice(1)); }, [prompt, entry]);

  const start = () => {
    setQueue(sessionPrompts(entries, new Date(), limit));
    setPending({}); setRequeued(new Set()); setRevealed(false); setSession({ reviewed: 0, correct: 0 });
  };

  const answer = async (a: FlashcardBinaryAnswer) => {
    if (!prompt || !entry) return;
    const rest = queue.slice(1);
    setSession((s) => ({ reviewed: s.reviewed + 1, correct: s.correct + (a === 'correct' ? 1 : 0) }));
    void recordAnswer(a, lang);
    void bumpEncounter(entry.scopedKey);
    const round = [...(pending[prompt.entryKey] ?? []), a];
    if (round.length === 2) {
      const outcome = await applyRound(entry.scopedKey, round);
      setPending((p) => { const n = { ...p }; delete n[prompt.entryKey]; return n; });
      if (outcome?.shouldRequeue && outcome.status !== 'known' && !requeued.has(prompt.entryKey)) {
        rest.push(...promptsFor(prompt.entryKey));
        setRequeued((s) => new Set(s).add(prompt.entryKey));
      }
    } else {
      setPending((p) => ({ ...p, [prompt.entryKey]: round }));
    }
    setQueue(rest);
    setRevealed(false);
  };

  const known = async () => {
    if (!entry) return;
    await markKnown(entry.scopedKey);
    setQueue((q) => q.filter((p) => p.entryKey !== entry.scopedKey));
    setRevealed(false);
  };
  const skip = () => { if (prompt) { setQueue([...queue.slice(1), prompt]); setRevealed(false); } };

  const acc = stats && stats.reviewed ? `${Math.round((stats.correct / stats.reviewed) * 100)}%` : '–';
  const next = nextDueDate(entries);

  return (
    <>
      <div className="topbar">
        {active ? <button className="icon-btn" aria-label="End session" onClick={() => setQueue([])}>✕</button> : <span />}
        <LangChip />
      </div>
      {!active && <h1>Flashcards</h1>}
      <div className="stats">
        <div className="stat"><b>{due.length}</b><span>Due</span></div>
        <div className="stat"><b>{active ? queue.length : 0}</b><span>Queue</span></div>
        <div className="stat"><b>{acc}</b><span>7-day acc.</span></div>
        <div className="stat"><b>{stats?.today?.reviewed ?? 0}</b><span>Today</span></div>
      </div>

      {active && entry ? (
        <>
          <div className="card flashcard" onClick={() => setRevealed(true)}>
            <span className="dir">{prompt.direction === 'wordToMeaning' ? 'Word → Meaning' : 'Meaning → Word'}</span>
            <span className="status-dot" data-s={entry.status} style={{ position: 'absolute', top: 12, right: 14 }}>{STATUS_INFO[entry.status].shortLabel}</span>
            <div>
              {prompt.direction === 'wordToMeaning' ? entry.word : entry.meaning || '(no meaning saved)'}
              {revealed
                ? <div className="back">{prompt.direction === 'wordToMeaning' ? entry.meaning || '(no meaning saved)' : entry.word}</div>
                : <div className="back small">Tap to reveal</div>}
            </div>
          </div>
          <div className="answer">
            <button className="btn wrong" disabled={!revealed} onClick={() => answer('wrong')}>✕ Wrong</button>
            <button className="btn right" disabled={!revealed} onClick={() => answer('correct')}>✓ Correct</button>
            <button className="btn" onClick={known}>Mark Known</button>
            <button className="btn" onClick={skip}>Skip ▶▶</button>
          </div>
        </>
      ) : (
        <div className="card">
          {session.reviewed > 0 && <p>Session done: {session.correct}/{session.reviewed} correct.</p>}
          <h2>Session size</h2>
          <div className="seg" style={{ marginBottom: 14 }}>
            {SESSION_WORD_LIMIT_OPTIONS.map((n) => <button key={n} className={limit === n ? 'on' : ''} onClick={() => setLimit(n)}>{n}</button>)}
          </div>
          <button className="btn primary block" disabled={!due.length} onClick={start}>
            {due.length ? `Start review (${Math.min(limit, due.length)} words)` : 'Nothing due'}
          </button>
          {!due.length && next && <p className="muted small">Next card due {new Date(next).toLocaleString()}.</p>}
        </div>
      )}
    </>
  );
}
