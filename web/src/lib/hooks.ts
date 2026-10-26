import { useLiveQuery } from 'dexie-react-hooks';
import { createContext, useContext, useEffect, useState } from 'react';
import { db } from './db';
import type { VocabStatus } from './models';
import { normalize } from './text';
import { getSyncState, subscribeSync, type SyncState } from './sync';

export type Appearance = 'system' | 'light' | 'dark' | 'midnight';

export interface AppCtx {
  lang: string;
  setLang: (l: string) => void;
  appearance: Appearance;
  setAppearance: (a: Appearance) => void;
  toast: (msg: string) => void;
}
export const AppContext = createContext<AppCtx>(null as unknown as AppCtx);
export const useApp = () => useContext(AppContext);

export function usePersistentState<T extends string | number>(key: string, initial: T): [T, (v: T) => void] {
  const [v, setV] = useState<T>(() => {
    try {
      const raw = localStorage.getItem(key);
      if (raw == null) return initial;
      return (typeof initial === 'number' ? Number(raw) : raw) as T;
    } catch { return initial; }
  });
  const set = (nv: T) => { setV(nv); try { localStorage.setItem(key, String(nv)); } catch { /* private mode */ } };
  return [v, set];
}

/** WordLearningStateResolver inputs: status by normalized key + ignored keys, live-updating. */
export function useLearningState(lang: string) {
  const statusByKey = useLiveQuery(async () => {
    const m = new Map<string, VocabStatus>();
    await db.vocab.where('languageCodeRaw').equals(lang).each((e) => { if (!e.deletedAt) m.set(e.normalizedKey, e.status); });
    return m;
  }, [lang], new Map<string, VocabStatus>());
  const ignored = useLiveQuery(async () => {
    const s = new Set<string>();
    await db.ignored.where('languageCodeRaw').equals(lang).each((r) => { if (!r.deletedAt) s.add(r.normalizedKey); });
    return s;
  }, [lang], new Set<string>());
  return { statusByKey, ignored };
}

export type VisualState = 'new' | 'ignored' | 'known' | VocabStatus;

export function visualState(word: string, statusByKey: Map<string, VocabStatus>, ignored: Set<string>): VisualState {
  const key = normalize(word);
  if (!key) return 'new';
  if (ignored.has(key)) return 'ignored';
  return statusByKey.get(key) ?? 'new';
}

export function useSyncState(): SyncState {
  const [s, setS] = useState(getSyncState());
  useEffect(() => subscribeSync(setS), []);
  return s;
}
