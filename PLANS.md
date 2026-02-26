# Plans

## Purpose
This is the execution roadmap for the LanguageReader app.
It tracks:
- What is already done.
- What is in progress.
- What is next, with acceptance criteria.

Use this file as the first read in a new chat, then read:
1. `README.md`
2. `DEVELOPMENT.md`
3. `DESIGN.md`
4. `DECISIONS.md`

## Status Snapshot (2026-02-26)
Completed:
- iOS SwiftUI app scaffold with SwiftData models.
- Tabs: Reader, Vocab, Flashcards, Settings.
- Document create/save/open flow.
- Full-screen reader with close action and progress slider.
- Reader mode toggle in bottom center (Word <-> Sentence).
- Sentence mode with horizontal one-sentence paging, translation action, and per-word meaning/pronunciation panel.
- Sentence panel now hides `known` words to focus on unresolved vocabulary.
- Word tap sheet with meaning + add to vocab.
- Sentence mode and word mode in reader.
- Offline SQLite dictionary integration.
- Dictionary diagnostics, local overrides, and missing-word logging.
- Language-profile-based lookup (`generic` default + Kannada profile rules) to reduce re-engineering per language.
- Optional cloud fallback for missing single-word meanings with persistent local cache.
- Vocab statuses (`new`, `learning`, `known`) with color coding.
- Flashcards upgraded to due-based spaced repetition with a simple LingQ-style binary flow (`Flip` -> `Wrong/Correct`) and bidirectional review (`word -> meaning`, `meaning -> word`) in the same session.
- Flashcards visual redesign pass: noir-glass session surface, calm card motion, transliteration-aware prompts, and two-row action dock.
- Hardening pass after flashcard rewrite: scheduler edge/failure tests expanded and full simulator test suite run clean.
- Unit tests for tokenization, vocab status logic, dictionary lookup, and transliteration.
- Main landing tab is now `Library` (replacing paste-first Reader home).
- Library home now includes:
  - `Import Content` quick actions (`Paste Text`, `YouTube URL`)
  - `Continue Reading` shelf (only lessons opened at least once)
  - `Suggested for Beginners` YouTube shelf with thumbnails
  - `My Library` mixed-source lesson list
- Added YouTube transcript import pipeline (no user API key required):
  - parse URL -> video ID
  - fetch metadata/caption tracks through YouTube innertube player endpoint
  - require Kannada subtitle tracks (`kn*`, auto-generated allowed)
  - fetch and normalize subtitle XML into reader-ready text
- Added subtitle-verified beginner suggestion catalog (grammar/basics/stories) with runtime validation.
- Extended `Document` persistence with source metadata (type/url/video/channel/category/duration/thumbnail) and open-state timestamps.
- Added parser-level regression tests for YouTube URL parsing and transcript XML normalization.
- Added fixture-driven regression tests for known missing-word failures (`LanguageReaderTests/Fixtures/dictionary_missing_fixture.tsv`).
- Added missing-word frequency summarizer tooling (`scripts/summarize_missing_words.py`) with unit tests.
- Added language onboarding checklist for new source languages (`docs/LANGUAGE_ONBOARDING_CHECKLIST.md`).
- Added `Text File` import flow for local `.txt` lesson ingestion in Library.
- Added suggestion personalization controls (followed-channel toggle + preference-based ranking from local import history).
- Added flashcard daily telemetry metrics (`Today`, `Known`, `Today Acc`) for low-friction progress feedback.
- Replaced static beginner video-ID seeding with dynamic channel RSS discovery + runtime Kannada subtitle/duration validation.
- Added discovery cache store with per-video validation TTL, trusted-channel memory, and exponential failure backoff.
- Added one-tap `Get 3-Day Pack` smart-pack import in Library with batch metadata and first-lesson open behavior.
- Added auto top-up coordinator on app launch/Library entry with cooldown + unread-threshold gating.
- Added `Settings -> Auto Content` controls and manual pack-run action.
- Added optional background refresh scheduler and app lifecycle wiring for best-effort prefetch.
- Added auto-content regression coverage (`YouTubeDiscoveryServiceTests`, `SuggestionCacheStoreTests`, `AutoImportCoordinatorTests`, `DocumentTests` migration coverage).

In progress:
- Dictionary quality for inflected forms and coverage gaps (Phase 1 ongoing).
- Phase 1 expansion for multi-language-ready lookup architecture (language profiles + cloud cache path).
- Dictionary quality evaluation pipeline (coverage + gold accuracy + thresholds) with first Kannada fixture.
- Reader visual polish toward a cleaner library-to-reader handoff.
- Phase 3 learning loop refinement (fixed-level schedule tuning against real retention outcomes).

Pending:
- Fixed-level interval calibration against real retention outcomes and usage cadence.

## Roadmap

### Phase 1: Dictionary Reliability (Current Priority)
Goals:
- Improve lookup hit rate for common inflections.
- Keep word meanings concise and usable in reading flow.
- Make lookup path observable and correctable locally.

Tasks:
1. Phase 1A (started):
   - Expand normalization and suffix heuristics for Kannada forms. (done)
   - Add lightweight inflection fallback for common verb-progressive endings. (done)
   - Clean noisy meanings at lookup time (strip metadata, truncate long multi-sense strings). (done)
   - Add regression tests for suffix/cleanup behavior. (done)
2. Phase 1B:
   - Improve dictionary build script so bundled entries are pre-cleaned and concise by default. (done)
   - Rebuild `dictionary.sqlite` and verify no schema breakage. (ongoing per dataset refresh cycle)
3. Phase 1C:
   - Add tests for known failure words from `dictionary_missing.tsv` fixtures. (done)
   - Add optional tooling to summarize missing words by frequency. (done)
4. Phase 1D:
   - Add optional API fallback for unresolved single-word meanings with local caching. (done, enabled by user setting)
   - Keep fallback language-agnostic at architecture level (language profiles + source-language keyed cache). (done)
5. Phase 1E:
   - Add language onboarding checklist (dictionary source import + profile rules + fixture tests) so new languages avoid re-engineering. (done)
6. Phase 1F (started):
   - Add dictionary evaluator script (`scripts/evaluate_dictionary.py`) for corpus coverage + gold-meaning accuracy. (done)
   - Add fixture-driven thresholds and machine-readable report output for repeatable quality tracking. (done)
   - Add evaluator unit tests (`scripts/test_evaluate_dictionary.py`) so metric logic is regression-safe. (done)
   - Add initial Kannada core fixture as baseline quality gate. (done)

Acceptance criteria:
- Manual sample text lookup feels consistent and fast.
- Meaning text shown in UI is usually short and readable (avoid long encyclopedic definitions where possible).
- Diagnostic mode clearly shows `direct`, `suffix`, `redirect`, `override`, `cache`, `remote`, or `none`.
- Missing/incorrect meanings can be fixed via overrides without rebuilding the app.
- Unknown words can be backfilled once from cloud fallback and reused offline from local cache.
- Dictionary quality is measurable with explicit metrics:
  - token coverage
  - unique-word coverage
  - gold hit rate
  - gold accuracy (context-appropriate meaning)

### Phase 2: Reader UX Restructure
Goals:
- Reading-first screen that uses full height cleanly.
- Stable spacing and flow in long documents.
- Fast library-to-reader entry with low-friction import.

Tasks:
- Keep reader full-screen with a minimal top control bar only.
- Ensure library -> document -> reader transition is smooth. (done)
- Replace paste-first home with a mixed-content Library shell. (done)
- Add in-app import actions for text and YouTube URL. (done)
- Add in-app file import for local text lessons. (done)
- Add beginner suggestion shelf with subtitle-verified YouTube cards + thumbnails. (done)
- Keep sentence mode as one sentence per horizontal page (stable pager behavior). (done)
- Improve typography, vertical rhythm, and token spacing.
- Validate light/dark mode readability. (done)

Acceptance criteria:
- Reader content fits iPhone 14 Pro viewport correctly.
- No bottom control clutter inside reader.
- Progress slider and close action always visible and usable.

### Phase 3: Learning Loop Improvements
Goals:
- Stronger recall workflow with low friction.

Tasks:
- Refine flashcard session logic (queue, revisit wrong items). (done)
- Tune status transitions (`new` -> `learning` -> `known`). (ongoing; `known` remains manual-only)
- Add lightweight stats for daily review and known ratio. (done: session `Due/Queue/Accuracy/Today/Known/Today Acc`)

Acceptance criteria:
- A short review session can be completed without navigation friction.
- Status updates are reflected consistently in reader, vocab, and flashcards.

### Phase 4: Kannada Auto-Content Automation (Completed)
Goals:
- Remove weekly hardcoded content maintenance.
- Keep lesson continuity high with near-zero manual effort.

Tasks:
- Replace static video IDs with channel-seed RSS discovery. (done)
- Validate candidates with existing metadata/caption pipeline + duration guard. (done)
- Add one-tap smart-pack import target (`3 days * 2 lessons/day`). (done)
- Add auto top-up on app launch/Library entry with cooldown + unread trigger. (done)
- Persist per-import metadata (`sourceChannelID`, `importModeRaw`, `autoBatchID`). (done)
- Add caching/backoff for resilient discovery under endpoint volatility. (done)
- Ensure force-refresh smart pack can revalidate transiently failed candidates (not blocked by stale invalid cache). (done)
- Reject low-quality transcript imports to prevent unreadable alphanumeric-only lessons. (done)
- Add optional BG app refresh wiring with same coordinator/rate limits. (done)

Acceptance criteria:
- Suggestions refresh from recent channel uploads without source edits.
- One tap imports a deterministic pack and opens the first lesson.
- Auto top-up runs only when trigger conditions are met.
- Discovery failures degrade to cached suggestions and avoid aggressive retries.

### Phase 5: Hardening and Release Readiness
Goals:
- Stable daily-use build.

Tasks:
- Add edge-case and failure-path tests for tokenizer, dictionary fallback, and flashcard flow.
- Add regression tests for every user-reported bug before closing it.
- Run end-to-end simulator checks on iPhone 14 Pro.
- Update docs for final MVP handoff.

Acceptance criteria:
- Build + tests pass consistently from CLI.
- Known limitations are documented clearly.

## Test Plan (Execution Checklist)
- `./scripts/test.sh`
- `./scripts/run.sh`
- Manual smoke checks:
  - Create document, save, reopen.
  - Tap multiple words in reader; verify meaning and diagnostics path.
  - Add word to vocab; status color changes in reader.
  - Search in vocab; change status.
  - Flashcard reveal and status update.
  - Settings: diagnostics toggle, overrides file creation.
  - Library: `Get 3-Day Pack` import path (successful + partial pack behavior).
  - Auto top-up trigger gating (cooldown + unread threshold) and cached-fallback behavior.

## Commit Discipline
- Keep commits focused by concern:
  - dictionary
  - reader-ui
  - vocab
  - flashcards
  - docs/tests
- After each functional change:
  1. run tests
  2. run simulator build
  3. update docs (`README.md`, `DEVELOPMENT.md`, `DESIGN.md`, `DECISIONS.md`) as needed
