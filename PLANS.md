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

## Status Snapshot (2026-02-14)
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
- Flashcards upgraded to due-based spaced repetition with adaptive FSRS-style scheduling (SM-2 fallback), `Again/Hard/Good/Easy` ratings, and in-session re-queue for misses.
- Unit tests for tokenization, vocab status logic, dictionary lookup, and transliteration.

In progress:
- Dictionary quality for inflected forms and coverage gaps (Phase 1 ongoing).
- Phase 1 expansion for multi-language-ready lookup architecture (language profiles + cloud cache path).
- Dictionary quality evaluation pipeline (coverage + gold accuracy + thresholds) with first Kannada fixture.
- Reader visual polish toward a cleaner LingQ-like reading experience.
- Phase 3 learning loop refinement (advanced scheduler tuning + session analytics polish).

Pending:
- FSRS parameter calibration against real review logs and retention outcomes.
- Reader-library UX alignment and quality pass.

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
   - Add tests for known failure words from `dictionary_missing.tsv` fixtures.
   - Add optional tooling to summarize missing words by frequency.
4. Phase 1D:
   - Add optional API fallback for unresolved single-word meanings with local caching. (done, enabled by user setting)
   - Keep fallback language-agnostic at architecture level (language profiles + source-language keyed cache). (done)
5. Phase 1E:
   - Add language onboarding checklist (dictionary source import + profile rules + fixture tests) so new languages avoid re-engineering.
6. Phase 1F (started):
   - Add dictionary evaluator script (`scripts/evaluate_dictionary.py`) for corpus coverage + gold-meaning accuracy.
   - Add fixture-driven thresholds and machine-readable report output for repeatable quality tracking.
   - Add evaluator unit tests (`scripts/test_evaluate_dictionary.py`) so metric logic is regression-safe.
   - Add initial Kannada core fixture as baseline quality gate.

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

Tasks:
- Keep reader full-screen with a minimal top control bar only.
- Ensure library -> document -> reader transition is smooth.
- Keep sentence mode as one sentence per horizontal page (stable pager behavior).
- Improve typography, vertical rhythm, and token spacing.
- Validate light/dark mode readability.

Acceptance criteria:
- Reader content fits iPhone 14 Pro viewport correctly.
- No bottom control clutter inside reader.
- Progress slider and close action always visible and usable.

### Phase 3: Learning Loop Improvements
Goals:
- Stronger recall workflow with low friction.

Tasks:
- Refine flashcard session logic (queue, revisit wrong items). (done)
- Tune status transitions (`new` -> `learning` -> `known`). (ongoing)
- Add lightweight stats for daily review and known ratio. (partially done: session `Due/Queue/Accuracy`)

Acceptance criteria:
- A short review session can be completed without navigation friction.
- Status updates are reflected consistently in reader, vocab, and flashcards.

### Phase 4: Hardening and Release Readiness
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
