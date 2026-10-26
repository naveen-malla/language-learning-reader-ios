import { useState } from 'react';
import { db } from '../lib/db';
import { auth, isBackendConfigured, login } from '../lib/api';
import { importLingq } from '../lib/importers';
import { SUPPORTED_LANGUAGES } from '../lib/models';
import { resetSyncCursor, syncNow } from '../lib/sync';
import { useApp, useSyncState, type Appearance } from '../lib/hooks';

const APPEARANCES: { id: Appearance; title: string; subtitle: string }[] = [
  { id: 'system', title: 'System', subtitle: 'Follow device setting' },
  { id: 'light', title: 'Light', subtitle: 'Bright glass surfaces' },
  { id: 'dark', title: 'Dark', subtitle: 'Soft navy dark mode' },
  { id: 'midnight', title: 'Midnight', subtitle: 'Deep contrast night mode' },
];

export function Settings() {
  const { lang, setLang, appearance, setAppearance, toast } = useApp();
  const sync = useSyncState();
  const [email, setEmail] = useState(auth.email ?? '');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [, force] = useState(0);
  const signedIn = !!auth.token;

  const submit = async (mode: 'login' | 'register') => {
    setBusy(true); setError(null);
    try {
      await login(email.trim(), password, mode);
      setPassword('');
      await syncNow();
      toast('Signed in, syncing');
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally { setBusy(false); force((n) => n + 1); }
  };

  const onLingq = async (f: File | undefined) => {
    if (!f) return;
    try {
      const r = await importLingq(JSON.parse(await f.text()), lang);
      toast(`Imported ${r.added} words (${r.skipped} already existed)`);
    } catch (e) { toast(e instanceof Error ? e.message : 'Import failed'); }
  };

  const exportBackup = async () => {
    const data = {
      exportedAt: new Date().toISOString(),
      documents: await db.documents.toArray(), vocab: await db.vocab.toArray(),
      ignored: await db.ignored.toArray(), stats: await db.stats.toArray(),
    };
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([JSON.stringify(data)], { type: 'application/json' }));
    a.download = `language-reader-backup-${data.exportedAt.slice(0, 10)}.json`;
    a.click();
  };

  return (
    <>
      <h1>Settings</h1>
      <div className="card">
        <h2>Study Language</h2>
        <div className="seg">
          {SUPPORTED_LANGUAGES.map((l) => <button key={l.code} className={lang === l.code ? 'on' : ''} onClick={() => setLang(l.code)}>{l.displayName}</button>)}
        </div>
        <p className="muted small">Library, vocab and flashcards follow this selection.{lang === 'kn' && ' The Kannada dictionary is not ported to the web yet.'}</p>
      </div>

      <div className="card">
        <h2>Appearance</h2>
        <div className="stats" style={{ gridTemplateColumns: '1fr 1fr' }}>
          {APPEARANCES.map((a) => (
            <button key={a.id} className="stat" style={{ textAlign: 'left', borderColor: appearance === a.id ? 'var(--accent)' : undefined }} onClick={() => setAppearance(a.id)}>
              <b style={{ fontSize: 16 }}>{a.title}</b><span>{a.subtitle}</span>
            </button>
          ))}
        </div>
      </div>

      <div className="card">
        <h2>Account & Sync</h2>
        {!isBackendConfigured() ? (
          <p className="muted small">Local-only mode: no backend URL configured (VITE_API_URL). Your data is saved on this device.</p>
        ) : signedIn ? (
          <>
            <p className="small">Signed in as <b>{auth.email}</b></p>
            <p className="muted small">
              Status: {sync.status}{sync.lastSyncedAt && ` · last synced ${new Date(sync.lastSyncedAt).toLocaleTimeString()}`}
              {sync.error && <><br />Error: {sync.error}</>}
            </p>
            <div className="row">
              <button className="btn" onClick={() => syncNow()}>Sync now</button>
              <button className="btn" onClick={async () => { await resetSyncCursor(); await syncNow(); toast('Full resync done'); }}>Full resync</button>
              <button className="btn danger" onClick={() => { auth.clear(); force((n) => n + 1); }}>Sign out</button>
            </div>
          </>
        ) : (
          <>
            <input className="input" type="email" autoComplete="username" placeholder="Email" value={email} onChange={(e) => setEmail(e.target.value)} style={{ marginBottom: 8 }} />
            <input className="input" type="password" autoComplete="current-password" placeholder="Password (min 8 chars)" value={password} onChange={(e) => setPassword(e.target.value)} style={{ marginBottom: 8 }} />
            {error && <p className="small" style={{ color: 'var(--wrong)' }}>{error}</p>}
            <div className="row">
              <button className="btn primary" disabled={busy || !email || password.length < 8} onClick={() => submit('login')}>Sign in</button>
              <button className="btn" disabled={busy || !email || password.length < 8} onClick={() => submit('register')}>Create account</button>
            </div>
          </>
        )}
      </div>

      <div className="card">
        <h2>Import & Backup</h2>
        <p className="muted small">Import your LingQ export (lingq_de_cards.json). Words you already have here are kept as they are.</p>
        <div className="row">
          <label className="btn">Import LingQ JSON<input type="file" accept=".json,application/json" hidden onChange={(e) => onLingq(e.target.files?.[0])} /></label>
          <button className="btn" onClick={exportBackup}>Export backup</button>
        </div>
      </div>
      <p className="muted small" style={{ textAlign: 'center' }}>Language Reader web · v{__APP_VERSION__}</p>
    </>
  );
}
