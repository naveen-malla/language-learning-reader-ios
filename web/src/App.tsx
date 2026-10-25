import { useCallback, useEffect, useMemo, useState } from 'react';
import { AppContext, usePersistentState, type Appearance } from './lib/hooks';
import { Library } from './views/Library';
import { Reader } from './views/Reader';
import { Vocab } from './views/Vocab';
import { Flashcards } from './views/Flashcards';
import { Settings } from './views/Settings';

type Tab = 'library' | 'vocab' | 'flashcards' | 'settings';
const TABS: { id: Tab; label: string; ico: string }[] = [
  { id: 'library', label: 'Library', ico: '📚' },
  { id: 'vocab', label: 'Vocab', ico: '☰' },
  { id: 'flashcards', label: 'Flashcards', ico: '🗂' },
  { id: 'settings', label: 'Settings', ico: '⚙︎' },
];

export default function App() {
  const [tab, setTab] = usePersistentState<Tab>('lr.tab', 'library');
  const [lang, setLang] = usePersistentState<string>('lr.studyLanguage', 'de');
  const [appearance, setAppearance] = usePersistentState<Appearance>('appearance.mode', 'dark');
  const [readerId, setReaderId] = useState<string | null>(null);
  const [toastMsg, setToastMsg] = useState<string | null>(null);

  useEffect(() => {
    const apply = () => {
      const sysLight = window.matchMedia('(prefers-color-scheme: light)').matches;
      const theme = appearance === 'system' ? (sysLight ? 'light' : 'dark') : appearance;
      document.documentElement.dataset.theme = theme;
    };
    apply();
    const mq = window.matchMedia('(prefers-color-scheme: light)');
    mq.addEventListener('change', apply);
    return () => mq.removeEventListener('change', apply);
  }, [appearance]);

  const toast = useCallback((m: string) => { setToastMsg(m); setTimeout(() => setToastMsg(null), 2600); }, []);
  const ctx = useMemo(() => ({ lang, setLang, appearance, setAppearance, toast }), [lang, appearance, toast]); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <AppContext.Provider value={ctx}>
      <div className="app">
        {tab === 'library' && <Library onOpen={setReaderId} />}
        {tab === 'vocab' && <Vocab />}
        {tab === 'flashcards' && <Flashcards />}
        {tab === 'settings' && <Settings />}
      </div>
      {!readerId && (
        <nav className="tabbar">
          {TABS.map((t) => (
            <button key={t.id} className={`tab ${tab === t.id ? 'active' : ''}`} onClick={() => setTab(t.id)}>
              <span className="ico">{t.ico}</span>{t.label}
            </button>
          ))}
        </nav>
      )}
      {readerId && <Reader docId={readerId} onClose={() => setReaderId(null)} />}
      {toastMsg && <div className="toast">{toastMsg}</div>}
    </AppContext.Provider>
  );
}
