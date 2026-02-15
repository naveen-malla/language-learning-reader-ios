# LanguageReader

An iOS reading-first language learning app (initial scope: Kannada) with offline word lookup, vocabulary tracking, and adaptive spaced-repetition flashcards.

## Product Snapshot
- Read saved documents in a distraction-light interface designed for long sessions.
- Tap words to get instant meanings, pronunciation, and vocabulary actions.
- Keep learning state unified across Reader, Vocab, and Flashcards.
- Review only what is due with adaptive scheduling (`Again`, `Hard`, `Good`, `Easy`).
- Work fully offline by default; optional cloud translation/fallback is additive.

## Screenshots

| Reader | Vocab |
|---|---|
| ![Reader tab](docs/screenshots/reader.jpg) | ![Vocab tab](docs/screenshots/vocab.jpg) |

| Flashcards | Settings |
|---|---|
| ![Flashcards tab](docs/screenshots/flashcards.jpg) | ![Settings tab](docs/screenshots/settings.jpg) |

## Core UX
- **Reader-first flow**: minimal friction from paste/import to immersive reading.
- **Liquid-glass interface layer**: thin/ultra-thin material cards, pills, and controls add depth while preserving contrast.
- **Word-level intelligence**: dictionary lookup path tracking (`direct`, `suffix`, `redirect`, `override`, `cache`, `remote`, `none`).
- **Progressive vocab states**: `1`, `2`, `3`, `4`, `Known` with consistent color mapping.
- **Session-focused flashcards**: due filtering, re-queue for misses, and interval previews.
- **Sentence support**: one-sentence paging with transliteration and translation fallback.

## Spaced Repetition (Words Only)
- Scheduler engine supports adaptive FSRS-style behavior with SM-2 fallback.
- Review outcomes update interval, stability/difficulty signals, repetition count, lapses, and next due date.
- `Known` and suspended cards are excluded from due queues.
- Session metrics track `Due`, `Queue`, and `Accuracy` to keep review decisions fast.

## Getting Started
Prerequisites:
- Xcode (latest stable)
- iOS Simulator (prefer iPhone 14 Pro)

### Xcode
1. Open `LanguageReader.xcodeproj`.
2. Select an iPhone simulator.
3. Build and Run.

### CLI
- Boot simulator: `./scripts/boot_simulator.sh`
- Build: `./scripts/build.sh`
- Run (build + install + launch): `./scripts/run.sh`
- Test: `./scripts/test.sh`
- List simulators: `xcrun simctl list`

## Dictionary Pipeline
- Bundled SQLite dictionary powers offline lookup.
- Build/update bundled dictionary:

```bash
./scripts/build_dictionary.py
```

- Runtime prefers app-container dictionary if present, otherwise bundled fallback.
- Local correction files in app Documents:
  - `dictionary_overrides.tsv`
  - `dictionary_missing.tsv`
  - `dictionary_cloud_cache.tsv`
- Settings now includes `Dictionary Quality` evaluation with:
  - token coverage
  - unique coverage
  - gold hit rate
  - gold accuracy
  - quality gate pass/fail and top unresolved words
- Dictionary settings intentionally keep this area quality-focused to reduce noise in the reading workflow.
- Quality fixtures are selected by source language code, with a baseline fallback fixture if no language-specific fixture exists yet.

## Optional Translation Setup
Translation is optional and not required for core functionality.

In **Settings -> Translation API**, provide:
- Endpoint (example): `https://api.cognitive.microsofttranslator.com`
- Region
- API key (stored in Keychain)

## Quality Bar
- Deterministic domain logic where practical.
- Strong unit coverage on tokenizer, dictionary lookup paths, vocab state resolution, and flashcard scheduling.
- Full simulator test runs supported via `./scripts/test.sh`.

## Documentation Map
- Product plan and checkpoints: `PLANS.md`
- Development workflow: `DEVELOPMENT.md`
- UX and behavior details: `DESIGN.md`
- Architecture decisions: `DECISIONS.md`

## Known Limits (Current Scope)
- Kannada is the first fully wired language profile.
- Morphology handling is heuristic, not full linguistic analysis.
- Per-word cloud fallback is context-light and can vary by sentence context.
- No cloud sync in V1.
