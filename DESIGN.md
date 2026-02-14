# Design

## Screens
- Reader: create and open documents, read text, tap words.
- Vocab: list/search vocabulary, adjust status.
- Flashcards: simple review flow.
- Settings: optional Azure translation config + key management, dictionary info/license.

## Core Flow
1. Paste text into Reader (or use `Paste from Clipboard`) and save a document.
2. Read with tappable word tokens.
3. Tap a word to see meaning and add to vocab.
4. Classify and review words with direct `1 2 3 4 Known` controls in Vocab and Flashcards.

## Bootstrap Data
- On first launch, seed two large Kannada sample documents so reader behavior can be tested immediately.

## Reader UI
- Full-bleed reading view with a dark, reading-first canvas.
- Top overlay: close button + read-only progress slider.
- Bottom-center mode button toggles between Word mode and Sentence mode.
- Hide the app tab bar while reading to keep focus.

## Sentence Mode UX
- Sentence mode is a horizontal pager with one sentence per page.
- Swiping left/right advances sentence pages.
- Each sentence page integrates details in a single flow:
  - one centered sentence shown once (no duplicate sentence overlay), tokenized and color-coded
  - sentence-level transliteration directly under the sentence
  - translate action (dictionary gloss) directly under the sentence
  - wrapped translation text in a fixed-height scroll area
  - per-word meaning + pronunciation list for unresolved words
- Sentence header text uses a reduced large type size (`30pt`) for better balance with details below.
- Sentence transliteration uses smaller, muted typography in a capped-height area to keep spacing clean on long sentences.
- Known and ignored words are intentionally hidden in the in-page sentence word list.
- New rows expose direct actions: `+` (add Level 1), `✓` (mark Known), and `delete` (ignore).
- Learning rows show compact `L1/L2/L3/L4` badges.
- Tapping a word in the sentence word list opens the word detail sheet.
- Sentence details refresh when the selected sentence or document text changes.

## Tokenization
- Use NaturalLanguage sentence tokenization for sentence-page boundaries and spacing.
- Use NaturalLanguage word tokenization when available.
- Fallback: split on whitespace and punctuation.
- Cache sentence blocks and tokenized sentence blocks when document text changes.

## Sentence Translation (Gloss)
- Triggered explicitly by user action (no auto-translate).
- Uses Azure Translator (`kn -> en`) when endpoint + region + key are configured.
- Falls back to offline dictionary gloss if config is missing or API request fails.
- Translation text remains a rough aid and not a full grammar-aware translation engine.

## Dictionary Normalization
- Normalize by trimming and lowercasing.
- If direct lookup fails, try a small set of common Kannada suffix strips (heuristic, not full morphology).
- Clean dictionary meanings that are redirect-like (values starting with `=`) by resolving a single redirect hop when possible.
- Optional diagnostics mode shows lookup path (direct/suffix/redirect/override).

## Color Coding
- New (untracked): blue highlight.
- Learning (`L1-L4`): green highlight.
- Known: primary text color (no highlight).
- Ignored: hidden from sentence unresolved list and treated as non-highlighted.

## Data Model (V1)
- Document: id, title, body, createdAt, updatedAt.
- VocabEntry: id, surface, normalizedKey, meaning, status (`level1`,`level2`,`level3`,`level4`,`known`), createdAt, lastSeenAt, encounterCount.
- IgnoredWordsStore: persistent normalized-word key set in `UserDefaults` used by sentence filtering and highlight resolution.

## Dictionary
- Offline, fast lookup.
- Bundle a small subset initially; allow local download/indexing later.
