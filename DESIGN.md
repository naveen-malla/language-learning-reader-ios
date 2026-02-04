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

## Tokenization
- Use NaturalLanguage tokenization when available.
- Fallback: split on whitespace and punctuation.

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
