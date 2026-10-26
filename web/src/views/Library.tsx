import { useMemo, useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../lib/db';
import { addDocument, deleteDocument } from '../lib/repo';
import { tokenize, normalize } from '../lib/text';
import { SUPPORTED_LANGUAGES, type Document } from '../lib/models';
import { useApp, useLearningState } from '../lib/hooks';
import { LangChip } from './LangChip';

function newWordCount(doc: Document, statusByKey: Map<string, unknown>, ignored: Set<string>) {
  const seen = new Set<string>();
  let fresh = 0;
  for (const t of tokenize(doc.body, doc.languageCodeRaw ?? 'de')) {
    if (!t.isWord) continue;
    const k = normalize(t.text);
    if (seen.has(k) || /^\d+$/.test(k)) continue;
    seen.add(k);
    if (!statusByKey.has(k) && !ignored.has(k)) fresh++;
  }
  return { unique: seen.size, fresh };
}

export function Library({ onOpen }: { onOpen: (id: string) => void }) {
  const { lang, toast } = useApp();
  const docs = useLiveQuery(
    async () => (await db.documents.where('languageCodeRaw').equals(lang).toArray())
      .filter((d) => !d.deletedAt)
      .sort((a, b) => (b.lastOpenedAt ?? b.createdAt).localeCompare(a.lastOpenedAt ?? a.createdAt)),
    [lang], [],
  );
  const { statusByKey, ignored } = useLearningState(lang);
  const [composer, setComposer] = useState(false);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');

  const counts = useMemo(() => {
    const opened = docs.filter((d) => d.firstOpenedAt).length;
    return { total: docs.length, opened, unread: docs.length - opened };
  }, [docs]);
  const upNext = docs.find((d) => !d.firstOpenedAt) ?? docs[0];
  const langName = SUPPORTED_LANGUAGES.find((l) => l.code === lang)?.displayName ?? lang;

  const onFile = async (f: File | undefined) => {
    if (!f) return;
    let text = await f.text();
    if (/\.(srt|vtt)$/i.test(f.name)) {
      // Subtitle files: keep only the spoken lines.
      text = text.split(/\r?\n/).filter((l) => l.trim() && !/^\d+$/.test(l.trim()) && !/-->/.test(l) && l.trim() !== 'WEBVTT').join('\n');
    }
    const doc = await addDocument(f.name.replace(/\.[^.]+$/, ''), text, lang);
    toast('Lesson imported');
    onOpen(doc.id);
  };

  return (
    <>
      <div className="topbar"><LangChip /></div>
      <h1>Library</h1>

      <div className="card hero">
        <h2>{langName} Learning Console</h2>
        <div className="muted">Your lessons, synced across devices.</div>
        <div className="stats">
          <div className="stat"><b>{counts.unread}</b><span>Unread</span></div>
          <div className="stat"><b>{counts.opened}</b><span>Opened</span></div>
          <div className="stat"><b>{counts.total}</b><span>Total</span></div>
          <div className="stat"><b>{statusByKey.size}</b><span>Words</span></div>
        </div>
        {upNext && <button className="btn primary block" onClick={() => onOpen(upNext.id)}>Continue: {upNext.title}</button>}
      </div>

      <div className="card">
        <h2>Lesson Intake</h2>
        {composer ? (
          <>
            <input className="input" placeholder="Title" value={title} onChange={(e) => setTitle(e.target.value)} style={{ marginBottom: 8 }} />
            <textarea className="input" placeholder={`Paste ${langName} text…`} value={body} onChange={(e) => setBody(e.target.value)} />
            <div className="row" style={{ marginTop: 8 }}>
              <button className="btn primary" disabled={!body.trim()} onClick={async () => {
                const doc = await addDocument(title, body, lang);
                setComposer(false); setTitle(''); setBody('');
                onOpen(doc.id);
              }}>Save & Read</button>
              <button className="btn" onClick={() => setComposer(false)}>Cancel</button>
            </div>
          </>
        ) : (
          <div className="row">
            <button className="btn" onClick={() => setComposer(true)}>📋 Paste Text</button>
            <label className="btn">📄 Text File<input type="file" accept=".txt,.md,.srt,.vtt,text/plain" hidden onChange={(e) => onFile(e.target.files?.[0])} /></label>
          </div>
        )}
      </div>

      {docs.map((d) => {
        const { unique, fresh } = newWordCount(d, statusByKey, ignored);
        return (
          <div key={d.id} className="card">
            <button className="doc" style={{ background: 'none', border: 0, padding: 0 }} onClick={() => onOpen(d.id)}>
              <div className="spread">
                <div className="title">{d.title}</div>
                {!d.firstOpenedAt && <span className="badge">New</span>}
              </div>
              <div className="preview">{d.body.slice(0, 200)}</div>
            </button>
            <div className="spread" style={{ marginTop: 10 }}>
              <span className="muted small">{fresh} new of {unique} words · {unique ? Math.round(((unique - fresh) / unique) * 100) : 0}% known</span>
              <button className="chip" onClick={() => { if (confirm(`Delete “${d.title}”?`)) void deleteDocument(d.id); }}>Delete</button>
            </div>
          </div>
        );
      })}
      {!docs.length && <div className="muted">No lessons in {langName} yet. Paste some text to start.</div>}
    </>
  );
}
