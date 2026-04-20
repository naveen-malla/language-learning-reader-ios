# Plan

## Purpose
This is the execution roadmap for the LanguageReader app.
It tracks:
- what is already done
- what is in progress
- what is next, with acceptance criteria

Read this file first in a new chat, then read:
1. `README.md`
2. `DEVELOPMENT.md`
3. `DECISIONS.md`

## Status Snapshot
Completed:
- iOS SwiftUI app scaffold with SwiftData models and the main tabs (`Library`, `Vocab`, `Flashcards`, `Settings`).
- Library-first home with text import, text-file import, subtitle-gated YouTube import, beginner discovery, unread queue, and mixed-source saved library.
- Language-scoped study flow for German and Kannada across documents, vocab, ignored words, flashcards, auto-import metadata, and suggestion caching.
- Persistent study-language selection with German default on fresh installs and Kannada preservation for migrated installs.
- German and Kannada YouTube discovery/import wiring with language-specific subtitle validation rules.
- Bundled dual-dictionary setup (`dictionary.sqlite` for Kannada, `dictionary_de.sqlite` for German) plus language-aware override/missing-word files.
- Full-screen reader with word mode, sentence mode, word tap sheet, transliteration support, and inline translation flow.
- Offline SQLite dictionary integration with diagnostics, overrides, missing-word logging, and optional single-word cloud fallback cache.
- Language-profile-based lookup path so Kannada-specific rules stay isolated from the generic lookup flow.
- Due-based flashcards with binary `Wrong/Correct` feedback, bidirectional review, session sizing, and lightweight daily telemetry.
- Dynamic YouTube discovery, ranking, validation cache, manual `Pull 3 New Lessons`, and app-driven auto top-up.
- Regression coverage for tokenizer, vocab state logic, dictionary lookup, YouTube import/discovery, auto-top-up coordination, and flashcard scheduling.

In progress:
- In-reader YouTube playback with synced subtitles: timed cue persistence, inline player mode, cached English subtitle translation, legacy timed-cue backfill, lyric-style subtitle emphasis, and translation-status diagnostics are implemented in code and still need full simulator/device verification.
- Dictionary quality tuning for inflected forms and corpus coverage gaps, especially for real-world German text beyond the new core fixture.
- Multi-language-ready lookup path hardening without overcomplicating V1.
- Reader and library polish where it improves reading flow without adding UI clutter.
- Fixed-interval flashcard tuning based on real retention behavior rather than guesswork.

Pending:
- Longer-run interval calibration after enough real usage exposes where the current level buckets are too aggressive or too weak.

## Current Priorities
- Finish verification for in-reader YouTube playback, subtitle sync, Azure-backed English subtitle caching, and the new subtitle failure-state messages.
- Improve dictionary hit rate and meaning quality for both Kannada and German corpus misses.
- Keep the lookup architecture language-agnostic, with only the minimum language-specific rules needed for correctness.
- Preserve the reading-first experience while tightening import reliability and review consistency.

## Roadmap
### Phase 1: Dictionary Reliability
Goals:
- Improve lookup hit rate for common inflections.
- Keep meanings concise and usable inside the reading flow.
- Make lookup failures observable and correctable locally.

Checklist:
- [x] Expand normalization and suffix heuristics for Kannada forms.
- [x] Add lightweight progressive-verb fallback.
- [x] Add conservative German suffix stripping for common inflection endings.
- [x] Clean noisy meanings at lookup/build time.
- [x] Add fixture-driven regression coverage for known missing words.
- [x] Add a German core evaluation fixture and bundled German SQLite build path.
- [x] Add missing-word summary tooling.
- [x] Add optional single-word cloud fallback with local cache.
- [x] Add evaluator tooling for coverage and gold-meaning accuracy.
- [ ] Keep improving dictionary quality as missing-word reports and fixtures reveal new gaps.

Acceptance criteria:
- Sample reading text lookup feels consistent and fast.
- Meaning text in the UI is usually short and readable.
- Diagnostics make the lookup path obvious.
- Missing or incorrect meanings can be corrected locally without rebuilding the app.

### Phase 2: Reader And Library Polish
Goals:
- Keep the reading screen clean and stable.
- Make library-to-reader entry low-friction.
- Avoid management-screen clutter that competes with reading.

Checklist:
- [x] Replace the paste-first home with a Library-first shell.
- [x] Add a persistent study-language selector across main study surfaces.
- [x] Support pasted text, text-file import, and subtitle-gated YouTube import.
- [x] Scope library shelves, vocab, flashcards, and quality checks by selected study language.
- [x] Keep sentence mode to one sentence per page.
- [x] Keep import/discovery state visible through unread queue and split discovery lists.
- [x] Preserve timed subtitle cues during YouTube import so playback sync does not depend on re-fetching timing later.
- [x] Add an in-reader `Watch` mode for imported YouTube lessons with inline player + synced subtitle panel.
- [x] Cache English subtitle translation on first `Watch` entry when Azure is configured, while keeping Kannada-only fallback usable.
- [x] Lazily recover timed subtitle cues for older imported YouTube lessons so `Watch` no longer requires re-import.
- [x] Improve subtitle sync polish so translated English lines read as the primary lyric flow and active cues snap cleanly during playback and seeking.
- [ ] Continue tightening typography, spacing, and screen usage where it materially improves long reading sessions.
- [ ] Complete simulator and real-device verification for embedded playback behavior.

Acceptance criteria:
- Reader content fits recent iPhone simulators cleanly.
- Progress and exit controls stay visible and usable.
- Importing a lesson and getting back into reading stays fast and predictable.
- Imported YouTube lessons open in normal reading mode by default and switch into inline playback only when the user taps `Watch`.

### Phase 3: Learning Loop Refinement
Goals:
- Keep review friction low.
- Make status transitions and flashcard results feel consistent across the app.

Checklist:
- [x] Move flashcards to a due-based binary review flow.
- [x] Add bidirectional review and same-session reinforcement for misses.
- [x] Add session sizing and lightweight daily telemetry.
- [ ] Revisit fixed level intervals once real usage shows where recall is breaking down.

Acceptance criteria:
- A short review session completes without navigation friction.
- Status changes show up consistently in Reader, Vocab, and Flashcards.

### Phase 4: Release Hardening
Goals:
- Keep the app stable for daily use.

Checklist:
- [ ] Add regression coverage for every real user-visible bug as it appears.
- [ ] Keep simulator acceptance mandatory for touched flows.
- [x] Tighten docs and verification steps for dual-language support, bundled dictionary builds, and simulator screenshots.

Acceptance criteria:
- Build and tests pass consistently from CLI.
- Known limitations and workflow expectations stay documented.
