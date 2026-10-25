# Export your LingQ vocabulary

LingQ has no full JSON export, so this snippet reads your own cards through the LingQ API while you are signed in.

1. Open https://www.lingq.com in Chrome or Safari on your Mac and sign in.
2. Open the developer console (Chrome: Cmd+Option+J; Safari: enable the Develop menu first, then Cmd+Option+C).
3. Paste this and press Enter. It takes about a minute for roughly 15k cards and then downloads `lingq_de_cards.json`.

```js
(async () => {
  const lang = 'de', cards = [];
  let url = `/api/v3/${lang}/cards/?page=1&page_size=1000`;
  while (url) {
    const j = await (await fetch(url, { credentials: 'include' })).json();
    for (const c of j.results) cards.push({
      term: c.term, display: c.hints?.[0]?.term || c.term,
      meanings: (c.hints || []).map(h => h.text).filter(Boolean),
      status: c.status, extended_status: c.extended_status,
      fragment: c.fragment || '', srs_due_date: c.srs_due_date,
    });
    url = j.next; console.log(cards.length);
  }
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([JSON.stringify({ language: lang, count: cards.length, cards })], { type: 'application/json' }));
  a.download = `lingq_${lang}_cards.json`; a.click();
})();
```

4. In the web app: Settings → Import & Backup → **Import LingQ JSON**.

Status mapping: LingQ status 0/1/2/3 becomes Level 1/2/3/4; `extended_status 3` becomes Known.
Words you already have in the app are not overwritten. Keep the file out of git: `web/data/` is ignored.
