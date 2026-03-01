# Design

## Screens
- Library: import content, browse suggested lessons, continue reading, and open saved lessons.
- Reader: read text and tap words.
- Vocab: list/search vocabulary, adjust status.
- Flashcards: due-based spaced repetition review flow.
- Settings: optional Azure translation config + key management, appearance + flashcard preferences, and a compact dictionary quality panel.

## Visual Language
- Non-reader screens use a light pastel canvas and elevated rounded cards to reduce harsh contrast in management flows.
- Reader remains intentionally dark and high-contrast to prioritize text focus and vocabulary color cues.
- Status controls use a consistent badge-triggered picker (`1 2 3 4 Known`) with level meanings and a checkmark for the current selection.
- Flashcards use a custom noir-glass surface with binary recall actions (`Wrong`, `Correct`) after card flip.
- Tab bar uses translucent material treatment so navigation feels persistent but unobtrusive.

## UI Validation Rule
- Every UI/UX change must be validated in the running simulator app (not just previews or tests) by exercising the affected screen/flow end to end.

## Core Flow
1. Open Library and choose one of three entry points:
   - import text (`Paste Text`)
   - import local text file (`Text File`)
   - import YouTube by URL
   - run a one-tap queue pull (`Pull 3 New Lessons`)
   - open a suggested beginner video row and import in one tap
2. Imported lesson opens directly in Reader.
3. Read with tappable word tokens.
4. Tap a word to see meaning and add to vocab.
5. Classify words by tapping their level badge and selecting `1 2 3 4 Known` in a shared status picker, then review due words in Flashcards with card flip + `Wrong/Correct`.
6. Re-open saved documents from Library; `Continue Reading` includes only previously opened lessons.

## Library Home UX
- `Lesson Intake` card exposes `Paste Text`, `YouTube URL`, and one-tap queue pull.
- `Lesson Intake` also supports direct `.txt` file import for faster lesson ingestion from external notes/readers.
- Primary intake action is `Pull 3 New Lessons`; secondary actions stay available for manual text/URL/file imports.
- `Unread Lesson Queue` keeps unread imported lessons visible as a dedicated list.
- `Discovery Feed` uses explicit vertical rows (not hidden carousels) and hides videos that fail live Kannada subtitle validation.
- Suggested inventory is populated by dynamic channel RSS discovery plus live YouTube search-result discovery.
- Import path requires Kannada subtitles plus readable transcript quality, including rejection of numeric-sequence subtitle dumps.
- Import prefers native Kannada subtitle tracks and can fallback to translatable tracks rendered in Kannada when direct tracks are absent.
- Suggested categories are mixed beginner-safe topics (`Basics`, `Grammar`, `Conversation`, `Short Stories`).
- Suggestion cards allow follow/unfollow per channel; ranking prioritizes followed channels and previously successful category/channel history from local imports.
- `Discovery Feed` is split into `New to Import` and `Already in Library`, with direct open action for imported feed items.
- Library rows are deduplicated by `sourceVideoID` so accidental duplicate imports never clutter queue/library views.
- `Pull 3 New Lessons` targets 3 lessons per tap; force refresh revalidates previously invalid-cached candidates instead of trusting stale negative cache entries.
- Repeat-import fallback is off by default so pulls prioritize fresh videos; optional fallback remains available in settings.
- Auto top-up checks run at app launch and Library entry (when enabled), reusing the same planner as manual pull.
- Discovery failures degrade to cached suggestions with backoff to avoid repeated failing calls.
- `My Library` merges text and YouTube lessons with source metadata.
- `Continue Reading` is behavior-driven: item appears only after first open.

## Bootstrap Data
- On first launch, seed two large Kannada sample documents so reader behavior can be tested immediately.

## Reader UI
- Full-bleed reading view with a dark, reading-first canvas.
- Top overlay: close button + read-only progress slider in a compact material bar pinned close to the safe-area top.
- Bottom-center mode button toggles between Word mode and Sentence mode.
- Hide the app tab bar while reading to keep focus.

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
- Header region uses adaptive top alignment: long sentence/translation content is anchored higher to reduce forced scrolling, while short content keeps light breathing room.
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
- Uses Azure Translator (`kn -> en`) when endpoint + key are configured. Region is optional for global resources.
- If explicit source language translation fails, retries once with auto-detected source to reduce silent fallback behavior.
- If Kannada cloud output is unchanged from the source text, retries once with auto-detected source before accepting the result.
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
- Missing-word reports are expected to feed a lightweight cleanup loop: frequency summary -> fixture regression -> dictionary/profile fix.

## Color Coding
- New (untracked): blue highlight.
- Learning token highlight: green.
- Learning level badges (`1-4`): level-specific tint for faster scanning.
- Known: primary text color (no highlight).
- Ignored: hidden from sentence unresolved list and treated as non-highlighted.

## Flashcards UX
- Session starts from due-only queue; non-due learning words are hidden.
- Session size is configurable in Settings via `Words per session`; default is `5` due words.
- Ready state shows both total due words and the selected session word count.
- Each due word is tested twice in-session with separated directional passes: all `word -> meaning` cards first, then `meaning -> word` cards in rotated order to avoid immediate same-word reversal.
- Card flow is: front prompt -> flip -> `Wrong`/`Correct` -> advance.
- Word transliteration is shown on word-facing prompts/reveals to support pronunciation memory.
- Level changes are resolved only after both directional answers are submitted.
- Missed words are re-queued once per session for immediate reinforcement.
- `Mark Known` is kept as a manual override action.
- Session chrome is a full-height noir-glass layout with a top progress rail, center glass card, and two-row action dock.
- Session metrics include lightweight daily-loop telemetry (`Today` reviewed cards, `Known` ratio, and `Today Acc`) in addition to session counters.

## Data Model (V1)
- Document: id, title, body, createdAt, updatedAt, source metadata (`sourceType`, `sourceURL`, `sourceVideoID`, `sourceChannel`, `sourceChannelID`, `sourceCategory`, `sourceDurationSeconds`, `thumbnailURL`), import metadata (`importModeRaw`, `autoBatchID`), and open-state timestamps (`firstOpenedAt`, `lastOpenedAt`).
- VocabEntry: id, surface, normalizedKey, meaning, status (`level1`,`level2`,`level3`,`level4`,`known`), createdAt, lastSeenAt, encounterCount.
- IgnoredWordsStore: persistent normalized-word key set in `UserDefaults` used by sentence filtering and highlight resolution.

## Dictionary
- Offline, fast lookup.
- Bundle a small subset initially; allow local download/indexing later.
- Quality panel is metrics-first (`token coverage`, `unique coverage`, `gold hit rate`, `gold accuracy`, gate result, unresolved list).
- Quality metrics are evaluated against saved documents and saved vocab meanings so scores match what the user is actually reading.
