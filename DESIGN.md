# Design

## Screens
- Reader: create and open documents, read text, tap words.
- Vocab: list/search vocabulary, adjust status.
- Flashcards: simple review flow.
- Settings: optional API key, dictionary info/license.

## Core Flow
1. Paste text into Reader (or use `Paste from Clipboard`) and save a document.
2. Read with tappable word tokens.
3. Tap a word to see meaning and add to vocab.
4. Review/upgrade vocab via Vocab tab or Flashcards.

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
- A bottom sentence panel shows:
  - current sentence
  - translate action (dictionary gloss)
  - per-word meaning + pronunciation list for `new`, `learning`, and unseen words
- Known words are intentionally hidden in the sentence panel list.
- Tapping a word in the page text or sentence panel opens the word detail sheet.
- Sentence panel content refreshes when the document text changes.

## Tokenization
- Use NaturalLanguage sentence tokenization for sentence-page boundaries and spacing.
- Use NaturalLanguage word tokenization when available.
- Fallback: split on whitespace and punctuation.
- Cache sentence blocks and tokenized sentence blocks when document text changes.

## Sentence Translation (Gloss)
- Triggered explicitly by user action (no auto-translate).
- Offline dictionary-based gloss; replaces known words with meanings and preserves punctuation.
- Label as rough translation; not fully grammatical.

## Dictionary Normalization
- Normalize by trimming and lowercasing.
- If direct lookup fails, try a small set of common Kannada suffix strips (heuristic, not full morphology).
- Clean dictionary meanings that are redirect-like (values starting with `=`) by resolving a single redirect hop when possible.
- Optional diagnostics mode shows lookup path (direct/suffix/redirect/override).

## Color Coding
- New: blue.
- Learning: yellow.
- Known: gray.

## Data Model (V1)
- Document: id, title, body, createdAt, updatedAt.
- VocabEntry: id, surface, normalizedKey, meaning, status, createdAt, lastSeenAt, encounterCount.

## Dictionary
- Offline, fast lookup.
- Bundle a small subset initially; allow local download/indexing later.
