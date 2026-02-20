# Development

## Requirements
- Xcode latest stable
- iOS Simulator
- xcodegen (`brew install xcodegen`) for regenerating the project when files change

## Planning Source
- `PLANS.md` is the execution roadmap and current status file.
- Read `PLANS.md` first when starting work in a new chat.

## Run
1. Open `LanguageReader.xcodeproj` in Xcode.
2. Select an iPhone Simulator (prefer iPhone 14 Pro; otherwise use the newest available).
3. Build and run.

## Testing Notes
- Word learning visual state logic is covered in `LanguageReaderTests/WordLearningStateResolverTests.swift`.
- Flashcard session size normalization is covered in `LanguageReaderTests/FlashcardDeckTests.swift`.
- Keychain storage read/write/delete is covered in `LanguageReaderTests/KeychainSecretStoreTests.swift`.

## Reader Input Notes
- App now opens on `Library` (not the old paste-first Reader tab).
- `Library -> Import Content` includes:
  - `Paste Text` for manual text lessons
  - `YouTube URL` for subtitle-based lesson import
- `Continue Reading` only shows lessons that have been opened at least once.
- `Suggested for Beginners` shows only subtitle-validated Kannada YouTube entries.
- If simulator keyboard paste is unreliable, use `Paste from Clipboard` inside `Library -> Paste Text`.
- Two large sample documents are seeded on first launch and appear in `Library -> My Library`.
- In sentence mode, swipe horizontally to move one sentence at a time.
- Sentence mode now keeps details in-page: centered sentence -> translate action -> unresolved word list.
- Bottom mode button copy is `Sentence View` in full text mode and `Text View` in sentence mode.
- Sentence content uses one unified reading size (`17pt`) across sentence, transliteration, and translation.
- Sentence header now includes a transliterated pronunciation line under the sentence.
- Translation text appears inline in the same top canvas (no separate translation scroll box).
- Top canvas uses a stable upper-center anchor so translation stays visible more often (minimal shift only when overflowed).
- Sentence translate action uses Azure Translator when configured in Settings; otherwise it falls back to offline gloss.
- Sentence page now uses reduced side insets and no floating card container so more of the screen is usable.
- Reader top bar is compact and pinned higher to reduce dead space above the progress slider.
- Sentence pager clamps the current index after text edits to avoid landing on empty pages.
- Tapping an unknown word now triggers optional cloud fallback (if enabled) and stores resolved meaning in local cloud cache.
- Main tabs now share one visual system: pastel canvas, rounded surfaces, translucent tab bar, and status chips.

## Translation API Setup
1. Open Settings -> Translation API.
2. Enter endpoint, region, and Key 1 from Azure Translator.
3. Save settings; key is stored in Keychain.
4. Use sentence mode -> `Translate sentence` to verify sentence translation and tap an unknown word to verify per-word cloud fallback.

## Install On iPhone (Keep Using Without Cable)
1. Connect your iPhone via USB (or enable wireless debugging).
2. On iPhone: Settings -> Privacy & Security -> Developer Mode -> On, then restart.
3. In Xcode, set your Team and a unique bundle ID under Signing & Capabilities.
4. Select your iPhone as the run destination and press Run.
5. After the app appears on your Home Screen, you can disconnect.

Notes:
- Free Apple ID signing expires in ~7 days; reconnect and Run again to renew.
- Apple Developer Program signing lasts up to 1 year and avoids frequent re-signing.

## CLI (after project creation)
- List simulators: `xcrun simctl list`
- Boot simulator: `open -a Simulator`
- Build: `xcodebuild -scheme LanguageReader -destination 'platform=iOS Simulator,name=iPhone 14 Pro' build`
- Run tests: `xcodebuild -scheme LanguageReader -destination 'platform=iOS Simulator,name=iPhone 14 Pro' test`

## Repo Hygiene
- Check main-only state (no extra branches/worktrees): `./scripts/guard_main.sh`
- Enforce cleanup to main-only state: `./scripts/guard_main.sh --cleanup`
- If you intentionally have local edits and still want cleanup: `./scripts/guard_main.sh --cleanup --allow-dirty`

## Testing Standard
- Treat tests as strict quality gates, not smoke checks.
- Every feature should have failure-path and edge-case coverage.
- Ensure caching/normalization and URL parsing edge cases are covered in unit tests.
- When a production issue is observed, add a regression test in the same change.
- For reader performance issues, confirm sentence/token preprocessing does not rerun on pure scroll updates.
- Keep sentence-mode behavior testable in unit tests (clamped index, progress mapping, and known+ignored filtering).
- Manual reader checks after sentence-mode changes:
  - confirm sentence appears once per page (no duplicate overlay card)
  - confirm sentence mode fills more horizontal space and does not look boxed-in
  - confirm top progress bar is positioned higher with reduced extra padding
  - confirm sentence/transliteration/translation share one top canvas scroll area
  - confirm top canvas stays visually stable after translation appears (no big upward jump)
  - confirm translate action and unresolved word list are visible in the same page
  - confirm sentence transliteration is visible under the sentence and stays readable on long lines
  - confirm translate action shows a loading state and resolves into wrapped inline text
  - confirm translation still works (fallback gloss) if API key is missing/cleared
  - confirm tapping a listed word still opens the word detail sheet
  - confirm the same word uses the same highlight state in text view and sentence view
  - confirm new-word quick actions exist (`+`, `✓`, `delete`) and apply immediately
  - confirm learning rows show tappable `1-4` level badges in sentence mode
  - confirm tapping a level badge opens the shared `1 2 3 4 Known` menu with checkmark + meaning text
  - confirm vocab rows use the same badge-triggered status picker and status meanings as sentence rows
  - confirm flashcards show due-only queue (`Due`, `Queue`, `Accuracy`) with binary `Wrong/Correct` feedback after flip
  - confirm Settings -> Flashcards -> `Words per session` defaults to `5` and changes the next started session size
  - confirm each due word is tested in both directions in-session (`word -> meaning`, `meaning -> word`)
  - confirm same-word reverse direction is not shown immediately back-to-back when multiple words are in the session
  - confirm one wrong answer in a round keeps level unchanged, while two wrong answers demote by one level
  - confirm two fully-correct rounds in a row promote a word by one level (cap at level 4)
  - confirm level-based due buckets remain fixed (`1d`, `3d`, `7d`, `15d`)
  - confirm missed words are re-queued once for same-session reinforcement
  - confirm flashcard review pool excludes `Known`
  - confirm Reader/Vocab/Flashcards/Settings all render with the shared card + chip styling (no mixed legacy controls)
- Manual library/import checks after home/import changes:
  - confirm app lands on `Library` tab at launch
  - confirm `Paste Text` import creates a new library item
  - confirm `YouTube URL` import rejects links without Kannada subtitles
  - confirm importing a suggested video opens reader immediately after save
  - confirm imported YouTube rows show thumbnail, source badge, and channel metadata
  - confirm imported item appears in `Continue Reading` only after the first reader open

## Project Generation
- If you add or remove source files, run `xcodegen generate` to update `LanguageReader.xcodeproj`.

## Dictionary (Local Full Dataset)
1. Build the bundled SQLite dictionary:
   `./scripts/build_dictionary.py`
2. (Optional) Install into the simulator Documents directory to override:
   `./scripts/install_dictionary.sh`

The app will automatically use the Documents SQLite file if present. Otherwise it uses the bundled `LanguageReader/Resources/dictionary.sqlite`.

Dictionary quality notes:
- Build script now normalizes meanings for concise display (strips leading metadata and trims multi-sense tails).
- Runtime lookup now includes broader Kannada suffix handling and light `-ುತ್ತ...` progressive verb fallback.
- Runtime lookup path is language-profile based (`kn` has inflection rules; other languages use generic exact lookup by default).
- Missing-word cloud fallback results are cached in `Documents/dictionary_cloud_cache.tsv`.
- Settings -> Dictionary Quality evaluates your local saved documents (coverage) and saved vocab meanings (accuracy).
- Re-run dictionary-focused tests after lookup changes:
  `xcodebuild -scheme LanguageReader -destination "id=$(./scripts/select_simulator.sh)" test -only-testing:LanguageReaderTests/DictionaryManagerTests`

## Dictionary Overrides
- Overrides: `Documents/dictionary_overrides.tsv` (normalized_key<TAB>meaning).
- Missing list: `Documents/dictionary_missing.tsv`.

## Simulator Notes
- Use Simulator for all testing.
- If iPhone 14 Pro is unavailable, select the closest recent iPhone runtime.
