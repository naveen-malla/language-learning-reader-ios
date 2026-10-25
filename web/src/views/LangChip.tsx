import { SUPPORTED_LANGUAGES } from '../lib/models';
import { useApp } from '../lib/hooks';

/** Persistent study-language selector shown on every main tab (StudyLanguageUI.swift). */
export function LangChip() {
  const { lang, setLang } = useApp();
  const i = SUPPORTED_LANGUAGES.findIndex((l) => l.code === lang);
  const cur = SUPPORTED_LANGUAGES[i] ?? SUPPORTED_LANGUAGES[0];
  return (
    <button className="chip lang" aria-label="Switch study language"
      onClick={() => setLang(SUPPORTED_LANGUAGES[(i + 1) % SUPPORTED_LANGUAGES.length].code)}>
      🌐 {cur.shortLabel}
    </button>
  );
}
