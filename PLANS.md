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

## Status Snapshot (2026-02-06)
Completed:
- iOS SwiftUI app scaffold with SwiftData models.
- Tabs: Reader, Vocab, Flashcards, Settings.
- Document create/save/open flow.
- Full-screen reader with close action and progress slider.
- Word tap sheet with meaning + add to vocab.
- Sentence mode and word mode in reader.
- Offline SQLite dictionary integration.
- Dictionary diagnostics, local overrides, and missing-word logging.
- Vocab statuses (`new`, `learning`, `known`) with color coding.
- Basic flashcards with reveal and status updates.
- Unit tests for tokenization, vocab status logic, dictionary lookup, and transliteration.

In progress:
- Dictionary quality for inflected Kannada forms and coverage gaps.
- Reader visual polish toward a cleaner LingQ-like reading experience.

Pending:
- Better spaced repetition behavior (beyond current basic flashcards).
- Reader-library UX alignment and quality pass.

## Roadmap

### Phase 1: Dictionary Reliability (Current Priority)
Goals:
- Improve lookup hit rate for common inflections.
- Make lookup path observable and correctable locally.

Tasks:
- Expand normalization and suffix heuristics for Kannada forms.
- Add tests for known failure words from `dictionary_missing.tsv`.
- Keep single-hop redirect resolution stable; avoid noisy meanings.
- Add optional tooling to summarize missing words by frequency.

Acceptance criteria:
- Manual sample text lookup feels consistent and fast.
- Diagnostic mode clearly shows `direct`, `suffix`, `redirect`, `override`, or `none`.
- Missing/incorrect meanings can be fixed via overrides without rebuilding the app.

### Phase 2: Reader UX Restructure
Goals:
- Reading-first screen that uses full height cleanly.
- Stable spacing and flow in long documents.

Tasks:
- Keep reader full-screen with a minimal top control bar only.
- Ensure library -> document -> reader transition is smooth.
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
- Refine flashcard session logic (queue, revisit wrong items).
- Tune status transitions (`new` -> `learning` -> `known`).
- Add lightweight stats for daily review and known ratio.

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
