# Design

## Screens
- Reader: create and open documents, read text, tap words.
- Vocab: list/search vocabulary, adjust status.
- Flashcards: due-based spaced repetition review flow.
- Settings: optional Azure translation config + key management, dictionary info/license, diagnostics, and cloud fallback controls.

## Visual Language
- Non-reader screens use a light pastel canvas and elevated rounded cards to reduce harsh contrast in management flows.
- Reader remains intentionally dark and high-contrast to prioritize text focus and vocabulary color cues.
- Status controls use a consistent badge-triggered picker (`1 2 3 4 Known`) with level meanings and a checkmark for the current selection.
- Flashcards use a custom noir-glass surface with binary recall actions (`Wrong`, `Correct`) after card flip.
- Tab bar uses translucent material treatment so navigation feels persistent but unobtrusive.

## Core Flow
1. Paste text into Reader (or use `Paste from Clipboard`) and save a document.
2. Read with tappable word tokens.
3. Tap a word to see meaning and add to vocab.
4. Classify words by tapping their level badge and selecting `1 2 3 4 Known` in a shared status picker, then review due words in Flashcards with card flip + `Wrong/Correct`.
5. Re-open saved documents faster using list previews and word-count metadata.

## Bootstrap Data
- On first launch, seed two large Kannada sample documents so reader behavior can be tested immediately.

## Reader UI
- Full-bleed reading view with a dark, reading-first canvas.
- Top overlay: close button + read-only progress slider in a compact material bar pinned close to the safe-area top.
- Bottom-center mode button toggles between Word mode and Sentence mode.
- Hide the app tab bar while reading to keep focus.
- Reader composer in the main tab shows lightweight live stats (word/sentence/read-time estimate) to reduce ambiguity before saving.

## Sentence Mode UX
- Sentence mode is a horizontal pager with one sentence per page.
- Swiping left/right advances sentence pages.
- Each sentence page integrates details in a single flow:
  - one sentence shown once (no duplicate sentence overlay), tokenized and color-coded
  - sentence-level transliteration directly under the sentence
  - translate action (Azure when configured, otherwise offline gloss fallback) directly under the sentence
  - translation appears inline in the same top canvas after tap
  - per-word meaning + pronunciation list for unresolved words
- Sentence, transliteration, and translation now use one unified reading size (`17pt`) to reduce visual jumps.
- Header region is one scrollable canvas; sentence/transliteration/translation are not split into separate scroll panes.
- Header region keeps a stable upper-center anchor: translation is usually visible without scrolling, and vertical shift stays minimal when overflow requires it.
- Header region height is capped so long sentences do not squeeze the unresolved-words list.
- Sentence page no longer uses a floating card container; content spans more of the screen width to reduce unused margins.
- Known and ignored words are intentionally hidden in the in-page sentence word list.
- New rows expose direct actions: `+` (add Level 1), `✓` (mark Known), and `delete` (ignore).
- Learning rows show compact level badges (`1/2/3/4`) that open the same status picker used in Vocab.
- Status picker options include standardized meanings:
  - `1`: Just added, review often.
  - `2`: Recognize in context with light effort.
  - `3`: Mostly familiar, occasional review.
  - `4`: Confident recall, rare review.
  - `Known`: Fully known, hide from practice lists.
- Tapping a word in the sentence word list opens the word detail sheet.
- Sentence details refresh when the selected sentence or document text changes.

## Tokenization
- Use NaturalLanguage sentence tokenization for sentence-page boundaries and spacing.
- Use NaturalLanguage word tokenization when available.
- Fallback: split on whitespace and punctuation.
- Cache sentence blocks and tokenized sentence blocks when document text changes.
- Word token buttons use shared press feedback styling for better tap confidence during dense reading.

## Sentence Translation (Gloss)
- Triggered explicitly by user action (no auto-translate).
- Uses Azure Translator (`kn -> en`) when endpoint + region + key are configured.
- Falls back to offline dictionary gloss if config is missing or API request fails.
- Translation text remains a rough aid and not a full grammar-aware translation engine.

## Dictionary Normalization
- Normalize by trimming and lowercasing.
- Resolve lookup candidates through a language profile:
  - default profile: exact lookup only
  - Kannada profile: heuristic suffix strips + lightweight progressive-verb fallback (`-ುತ್ತ...`)
- Clean dictionary meanings that are redirect-like (values starting with `=`) by resolving a single redirect hop when possible.
- Clean dictionary meanings for readability (remove leading metadata markers and trim long multi-sense tails).
- If no local meaning exists and cloud fallback is enabled, fetch one-word translation and store it in local cache.
- Optional diagnostics mode shows lookup path (`direct`, `suffix`, `redirect`, `override`, `cache`, `remote`, `none`).

## Color Coding
- New (untracked): blue highlight.
- Learning token highlight: green.
- Learning level badges (`1-4`): level-specific tint for faster scanning.
- Known: primary text color (no highlight).
- Ignored: hidden from sentence unresolved list and treated as non-highlighted.

## Flashcards UX
- Session starts from due-only queue; non-due learning words are hidden.
- Session size is configurable in Settings via `Words per session`; default is `5` due words.
- Each due word is tested twice in-session: `word -> meaning`, then `meaning -> word`.
- Card flow is: front prompt -> flip -> `Wrong`/`Correct` -> advance.
- Word transliteration is shown on word-facing prompts/reveals to support pronunciation memory.
- Level changes are resolved only after both directional answers are submitted.
- Missed words are re-queued once per session for immediate reinforcement.
- `Mark Known` is kept as a manual override action.
- Session chrome is a full-height noir-glass layout with a top progress rail, center glass card, and two-row action dock.

## Data Model (V1)
- Document: id, title, body, createdAt, updatedAt.
- VocabEntry: id, surface, normalizedKey, meaning, status (`level1`,`level2`,`level3`,`level4`,`known`), createdAt, lastSeenAt, encounterCount.
- IgnoredWordsStore: persistent normalized-word key set in `UserDefaults` used by sentence filtering and highlight resolution.

## Dictionary
- Offline, fast lookup.
- Bundle a small subset initially; allow local download/indexing later.
