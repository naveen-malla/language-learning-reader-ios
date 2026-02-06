# Design

## Screens
- Reader: create and open documents, read text, tap words.
- Vocab: list/search vocabulary, adjust status.
- Flashcards: simple review flow.
- Settings: optional API key, dictionary info/license.

## Core Flow
1. Paste text into Reader and save a document.
2. Read with tappable word tokens.
3. Tap a word to see meaning and add to vocab.
4. Review/upgrade vocab via Vocab tab or Flashcards.

## Reader UI
- Full-bleed reading view (no card container).
- Top overlay: close button, read-only progress slider, sentence view toggle.
- Hide the tab bar while reading to keep focus.
- Follows system appearance (light/dark).

## Tokenization
- Use NaturalLanguage sentence tokenization for layout spacing.
- Use NaturalLanguage word tokenization when available.
- Fallback: split on whitespace and punctuation.

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
