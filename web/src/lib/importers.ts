// Importers: LingQ vocabulary export and the built-in sample lessons.
import { db, type ReaderDB } from './db';
import { dueDate } from './flashcards';
import { newDocument, newVocabEntry, nowISO, type VocabEntry, type VocabStatus } from './models';
import { normalize } from './text';
import { notifyLocalChange } from './repo';

/** Shape produced by the LingQ export snippet (docs/LINGQ_EXPORT.md). */
export interface LingqCard {
  term: string;
  display?: string;
  meanings: string[];
  status: number; // 0..3
  extended_status: number | null; // 3 = known
  fragment?: string;
  srs_due_date?: string | null;
}

/** LingQ status 0..3 maps onto our level1..level4; extended_status 3 means "known". */
export function lingqStatus(status: number, extended: number | null): VocabStatus {
  if (extended === 3) return 'known';
  return (['level1', 'level2', 'level3', 'level4'] as const)[Math.min(3, Math.max(0, status))];
}

export function lingqToEntry(card: LingqCard, languageCode: string): VocabEntry | null {
  const key = normalize(card.term);
  if (!key) return null;
  const status = lingqStatus(card.status, card.extended_status);
  const e = newVocabEntry({
    word: card.display || card.term,
    normalizedKey: key,
    languageCode,
    meaning: card.meanings.filter(Boolean).slice(0, 2).join('; '),
    status,
  });
  e.dueAt = status === 'known' ? null : dueDate(status, new Date());
  e.srsAlgorithm = 'lingq-import';
  return { ...e, _dirty: 1 };
}

/** Existing words are left untouched: your progress in this app beats an older LingQ snapshot. */
export async function importLingq(json: unknown, languageCode = 'de', d: ReaderDB = db) {
  const cards: LingqCard[] = Array.isArray(json) ? json : (json as { cards?: LingqCard[] })?.cards ?? [];
  if (!cards.length) throw new Error('No cards found. Expected the lingq_de_cards.json export.');
  let added = 0;
  let skipped = 0;
  const CHUNK = 1000;
  for (let i = 0; i < cards.length; i += CHUNK) {
    const batch = cards.slice(i, i + CHUNK).map((c) => lingqToEntry(c, languageCode)).filter((e): e is VocabEntry => !!e);
    await d.transaction('rw', d.vocab, async () => {
      const existing = await d.vocab.bulkGet(batch.map((e) => e.scopedKey));
      const fresh = batch.filter((e, j) => !existing[j] || existing[j]!.deletedAt);
      skipped += batch.length - fresh.length;
      await d.vocab.bulkPut(fresh);
      added += fresh.length;
    });
  }
  if (added) notifyLocalChange();
  return { added, skipped, total: cards.length };
}

const SAMPLES_DE = [
  {
    title: 'German Practice Story',
    body: `Heute Morgen bin ich früh aufgestanden und habe das Fenster geöffnet. Die Straße war noch ruhig, und die Luft war kühl und klar.
Ich habe mich mit einer Tasse Kaffee an den Tisch gesetzt und einen kurzen deutschen Artikel gelesen. Einige Wörter kannte ich schon, andere musste ich nachschlagen.

Später hat mir eine Freundin eine Nachricht geschickt und vorgeschlagen, dass wir am Wochenende zusammen lernen. Sie meinte, dass regelmäßiges Lesen viel hilfreicher ist als seltene, lange Lernsitzungen.
Wir wollen deshalb jeden Tag nur zwanzig Minuten lesen, neue Wörter markieren und am Abend kurz wiederholen.

Am Nachmittag bin ich einkaufen gegangen. Im Supermarkt habe ich absichtlich auf die Beschriftungen geachtet, damit ich Wörter aus dem Alltag wiedererkenne.
Zu Hause habe ich dann drei neue Wörter in meine Liste eingetragen und zu jedem Wort einen eigenen Beispielsatz geschrieben.

Am Ende des Tages hatte ich nicht das Gefühl, sehr viel gelernt zu haben. Trotzdem konnte ich mehrere Sätze flüssiger lesen als gestern.
Genau das motiviert mich: kleine Fortschritte, die sich mit der Zeit zu echtem Verständnis aufbauen.`,
  },
  {
    title: 'German Reading: Daily Learning',
    body: `Beim Sprachenlernen ist Regelmäßigkeit wichtiger als Perfektion. Viele Lernende warten auf den richtigen Moment, aber meistens reicht ein kurzer, klarer Ablauf.
Lies einen Abschnitt aufmerksam, markiere unbekannte Wörter und überprüfe danach nur die wichtigsten Begriffe.

Wenn du jedes unbekannte Wort sofort nachschlägst, verlierst du leicht den roten Faden. Es ist oft besser, zuerst den ganzen Satz zu verstehen und danach einzelne Wörter genauer anzusehen.
So trainierst du nicht nur den Wortschatz, sondern auch dein Gefühl für Struktur, Ton und Zusammenhang.

Besonders hilfreich ist es, neue Wörter schnell wiederzuverwenden. Schreibe einen kurzen Beispielsatz, lies ihn laut vor und prüfe am nächsten Tag, ob du die Bedeutung noch erinnerst.
Dieser kleine Kreislauf aus Lesen, Verstehen und Wiederholen hält den Lernaufwand niedrig und verbessert trotzdem die Erinnerung deutlich.

Mit der Zeit werden vertraute Wörter häufiger, und schwierige Texte wirken weniger anstrengend. Das Ziel ist nicht, jedes Detail sofort zu kennen.
Das Ziel ist, Schritt für Schritt sicherer zu lesen und immer weniger Hilfe zu brauchen.`,
  },
];

/** Seed samples once per device, with fixed ids so two devices never create duplicates. */
export async function seedSamplesIfEmpty(d: ReaderDB = db) {
  if ((await d.meta.get('seeded'))?.value) return;
  const count = await d.documents.count();
  if (count === 0) {
    const ids = ['00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000002'];
    const created = new Date(Date.now() - 60_000).toISOString(); // older than any real edit
    await d.documents.bulkPut(SAMPLES_DE.map((s, i) => ({
      ...newDocument({ title: s.title, body: s.body, languageCodeRaw: 'de', sourceTypeRaw: 'sample' }),
      id: ids[i], createdAt: created, updatedAt: '1970-01-01T00:00:00.000Z', _dirty: 0 as const,
    })));
  }
  await d.meta.put({ key: 'seeded', value: nowISO() });
}

