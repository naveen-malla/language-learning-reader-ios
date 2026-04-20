# Development

This file owns environment setup, scripts, build/test/run workflow, and verification expectations. Product behavior belongs in `README.md`; durable architectural tradeoffs belong in `DECISIONS.md`.

## Requirements
- Xcode latest stable
- iOS Simulator
- xcodegen (`brew install xcodegen`) for regenerating the project when files change

## Planning Source
- `PLAN.md` is the execution roadmap and current status file.
- Read `PLAN.md` first when starting work in a new chat.

## Run
1. Open `LanguageReader.xcodeproj` in Xcode.
2. Select an iPhone Simulator (prefer iPhone 14 Pro; otherwise use the newest available).
3. Build and run.

## Testing Notes
- Word learning visual state logic is covered in `LanguageReaderTests/WordLearningStateResolverTests.swift`.
- Study-language bootstrap and migration defaults are covered in `LanguageReaderTests/StudyLanguageSettingsStoreTests.swift`.
- Legacy auto-import metadata migration is covered in `LanguageReaderTests/AutoImportSettingsTests.swift`.
- Flashcard session size normalization is covered in `LanguageReaderTests/FlashcardDeckTests.swift`.
- Keychain storage read/write/delete is covered in `LanguageReaderTests/KeychainSecretStoreTests.swift`.
- Document source type persistence and open-state flags are covered in `LanguageReaderTests/DocumentTests.swift`.
- Dictionary remote fallback language overrides are covered in `LanguageReaderTests/DictionaryManagerTests.swift`.
- Dictionary remote prefetch dedupe and disabled fallback behavior are covered in `LanguageReaderTests/DictionaryManagerTests.swift`.
- SQLite provider concurrent-read regression coverage is in `LanguageReaderTests/DictionaryTests.swift` (`testSQLiteProviderSupportsConcurrentReads`).
- Dictionary quality matching and language canonicalization are covered in `LanguageReaderTests/DictionaryQualityTests.swift`.
- Dictionary Kannada/German word-form generation is covered in `LanguageReaderTests/DictionaryLanguageProfileTests.swift`.
- YouTube import selection (track preference, missing Kannada captions, subtitles-only candidate inclusion, suggestions filtering) is covered in `LanguageReaderTests/YouTubeImportServiceTests.swift`.
- German subtitle selection and missing-caption rejection are also covered in `LanguageReaderTests/YouTubeImportServiceTests.swift`.
- Timed subtitle parsing/merge behavior is covered in `LanguageReaderTests/YouTubeImportServiceTests.swift`.
- Dynamic discovery parsing, malformed-feed tolerance, cache reuse, cacheable-vs-transient validation-failure handling, force-refresh revalidation of cached invalid candidates, and backoff fallback are covered in `LanguageReaderTests/YouTubeDiscoveryServiceTests.swift`.
- Language-scoped discovery cache separation is covered in `LanguageReaderTests/SuggestionCacheStoreTests.swift`.
- Suggestion preference ranking is covered in `LanguageReaderTests/SuggestionRankerTests.swift`.
- Suggestion/discovery cache TTL, validation cache, trusted channels, and backoff progression are covered in `LanguageReaderTests/SuggestionCacheStoreTests.swift`.
- Auto top-up trigger rules, dedupe behavior, success/failure metadata writes, and batch metadata persistence are covered in `LanguageReaderTests/AutoImportCoordinatorTests.swift`.
- Flashcard daily telemetry aggregation and per-language separation are covered in `LanguageReaderTests/FlashcardStatsStoreTests.swift`.
- Appearance mode mapping and dark/light selection behavior is covered in `LanguageReaderTests/AppAppearanceModeTests.swift`.
- Subtitle cue timeline selection and translation-cache compatibility are covered in `LanguageReaderTests/SubtitleCueTimelineTests.swift`.
- Subtitle translation cache, Azure-failure fallback, missing-config fallback, and unreadable-output rejection are covered in `LanguageReaderTests/SubtitleTranslationServiceTests.swift`.
- Screenshot launch-route parsing is covered in `LanguageReaderTests/ScreenshotLaunchConfigurationTests.swift`.

## Verification Touchpoints
- `README.md` is the source of truth for intended product behavior.
- This section keeps high-value context that commonly affects developer verification and debugging.
- App now opens on `Library` (not the old paste-first Reader tab).
- Fresh installs default to German; migrated installs keep Kannada as the selected study language.
- `Document` language is persistent and may differ from the global study-language picker after imports or migrations.
- `Library -> Lesson Intake` includes:
  - `Paste Text` for manual text lessons
  - `Text File` for local `.txt` lesson import
  - `YouTube URL` for subtitle-based lesson import
- `Library -> Lesson Intake` also includes `Pull 3 New Lessons` for one-tap batch import of validated lessons in the currently selected study language.
- `Unread Lesson Queue` explicitly lists unread imported YouTube lessons.
- `Continue Reading` only shows lessons that have been opened at least once.
- `Discovery Feed` shows subtitle-validated YouTube entries for the selected study language, split into `New to Import` and `Already in Library`.
- Suggested entries are discovered from channel RSS feeds plus live YouTube search-result pages and validated live.
- Manual pull targets 3 lessons per tap; auto top-up scales by unread queue.
- Candidate duration window is 5 to 20 minutes.
- Subtitle quality filtering rejects low-readable and numeric-sequence transcripts before they enter import batches.
- German import requires direct `de*` tracks.
- Kannada import prefers direct `kn*` subtitle tracks and falls back to translatable tracks rendered in Kannada when needed.
- Repeat-import fallback is configurable in `Settings -> Auto Content`; default is disabled so pulls prioritize fresh videos.
- Imported video history and auto-top-up timestamps are persisted per language so German and Kannada queues do not pollute each other.
- Auto top-up runs on app launch and Library entry when enabled, with defaults:
  - cooldown: 24 hours
  - unread trigger: fewer than 3 imported YouTube lessons
  - validation budget: 60 candidates
  - validation concurrency: 6
- Auto-content toggles and status live in `Settings -> Auto Content`.
- Suggestion cards support channel follow/unfollow and re-rank using followed channels + existing import history.
- If simulator keyboard paste is unreliable, use `Paste from Clipboard` inside `Library -> Paste Text`.
- Two large sample documents are seeded on first launch and appear in `Library -> My Library`.
- Screenshot capture routes are available for simulator-only documentation work:
  - `xcrun simctl launch --terminate-running-process booted com.local.LanguageReader --screenshot-demo --screenshot-route=library`
  - `xcrun simctl launch --terminate-running-process booted com.local.LanguageReader --screenshot-demo --screenshot-route=flashcards-session`
  - `xcrun simctl launch --terminate-running-process booted com.local.LanguageReader --screenshot-demo --screenshot-route=watch`
  - supported routes: `library`, `vocab`, `flashcards`, `flashcards-session`, `settings`, `reader`, `watch`
- In sentence mode, swipe horizontally to move one sentence at a time.
- Sentence mode now keeps details in-page: centered sentence -> translate action -> unresolved word list.
- Bottom mode button copy is `Sentence View` in full text mode and `Text View` in sentence mode.
- Sentence content uses one unified reading size (`17pt`) across sentence, transliteration, and translation.
- Sentence header now includes a transliterated pronunciation line under the sentence.
- Translation text appears inline in the same top canvas (no separate translation scroll box).
- Top canvas uses adaptive top alignment so long sentence/translation content stays high on screen with less forced scrolling.
- Sentence translate action uses Azure Translator when configured in Settings; otherwise it falls back to offline gloss.
- Sentence translation accepts output only when readability gates pass (applies to Azure/public/fallback paths).
- Sentence page now uses reduced side insets and no floating card container so more of the screen is usable.
- Reader top bar is compact and pinned higher to reduce dead space above the progress slider.
- Imported YouTube lessons expose a `Watch` toggle in the reader top bar without changing the default open-in-reader behavior.
- `Watch` mode uses an embedded YouTube player inside the reader, with the top progress slider acting as a video scrubber.
- Timed subtitle cues are stored locally on the document and drive subtitle sync during playback.
- Older imported YouTube lessons that do not have stored timed cues lazily backfill them on reader open and show a disabled `Preparing` top-bar state while that recovery is running.
- If timed-cue backfill fails for an older lesson, the app synthesizes a coarse subtitle timeline from the stored transcript so `Watch` can still render subtitle lines and prefetch English subtitles.
- Imported video lessons start subtitle translation prefetch on reader open, then reuse cached translated cues on later `Watch` opens.
- When English subtitle cues are available, the reader renders English as the primary lyric line with Kannada beneath it and a stronger active-cue treatment.
- Active subtitle selection advances on exact cue starts and preserves the previous cue through short gaps so the highlight stays stable during play/pause/seek.
- `Watch` mode keeps source-language playback usable when translation fails and will reuse cached English cues when a new translation attempt is unavailable.
- Sentence pager clamps the current index after text edits to avoid landing on empty pages.
- Tapping an unknown word now triggers optional cloud fallback (if enabled) and stores resolved meaning in local cloud cache.
- Main tabs now share one visual system: pastel canvas, rounded surfaces, translucent tab bar, and status chips.

## Translation API Setup
1. Open Settings -> Translation API.
2. Enter endpoint, source/target language codes, and Key 1 from Azure Translator. Region is optional for global resources.
3. Save settings; key is stored in Keychain.
4. Use sentence mode -> `Translate sentence` to verify sentence translation and tap an unknown word to verify per-word cloud fallback.
5. If Azure is unavailable, sentence translation should still attempt public web fallback before showing unavailable state.
6. English subtitle generation also uses the same Azure settings first, but it now falls back to the public translator when Azure is unavailable or unreadable.
7. For imported YouTube lessons, open the reader first to verify background subtitle prefetch, then enter `Watch` mode to verify cached English subtitle reuse.

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
- For user-visible defects, add a test that reproduces the exact symptom and a test that verifies the intended recovery behavior (for example retry path, fallback path, or error handling path).
- Reliability-first bias: do not trade away correctness for storage/network/cost when iPhone 14 Pro performance remains acceptable.
- For every code change, run the app on simulator (`./scripts/run.sh`) and manually verify the affected real UI/app flow before considering the change complete.
- For reader performance issues, confirm sentence/token preprocessing does not rerun on pure scroll updates.
- Keep sentence-mode behavior testable in unit tests (clamped index, progress mapping, and known+ignored filtering).
- Manual reader checks after sentence-mode changes:
  - confirm sentence appears once per page (no duplicate overlay card)
  - confirm sentence mode fills more horizontal space and does not look boxed-in
  - confirm top progress bar is positioned higher with reduced extra padding
  - confirm sentence/transliteration/translation share one top canvas scroll area
  - confirm top canvas stays top-aligned after translation appears (no large dead space above sentence text)
  - confirm translate action and unresolved word list are visible in the same page
  - confirm sentence transliteration is visible under the sentence and stays readable on long lines
  - confirm translate action shows a loading state and resolves into wrapped inline text
  - confirm translation still works (fallback gloss) if API key is missing/cleared
  - confirm translation works when API key is present even if region is blank (global resource path)
  - confirm translator retries without `from` when source-language config is invalid and still returns a cloud translation
  - confirm translation attempts public web fallback when Azure is not configured or transiently fails
  - confirm mixed Kannada+English gloss-like output is not shown as sentence translation; unavailable message appears instead
  - confirm tapping `Translate sentence` again after an unavailable result reattempts translation (unavailable outcomes are not cached)
  - confirm tapping a listed word still opens the word detail sheet
  - confirm the same word uses the same highlight state in text view and sentence view
  - confirm new-word quick actions exist (`+`, `✓`, `delete`) and apply immediately
  - confirm learning rows show tappable `1-4` level badges in sentence mode
  - confirm tapping a level badge opens the shared `1 2 3 4 Known` menu with checkmark + meaning text
  - confirm vocab rows use the same badge-triggered status picker and status meanings as sentence rows
  - confirm flashcards show due-only queue (`Due`, `Queue`, `Accuracy`) with binary `Wrong/Correct` feedback after flip
  - confirm flashcards metrics also show `Today`, `Known`, and `Today Acc`
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
  - confirm `Text File` import opens the imported lesson in reader
  - confirm `YouTube URL` import rejects links without Kannada subtitles
  - confirm importing a suggested video opens reader immediately after save
  - confirm imported YouTube lessons still open in reading mode by default
  - confirm a newly imported YouTube lesson shows `Watch` immediately
  - confirm an older imported YouTube lesson without stored cues shows `Preparing`, then gains `Watch` without rewriting the lesson body
  - confirm tapping `Watch` shows inline video at the top and subtitle panel below without any overlay covering the player
  - confirm the top progress slider scrubs video while in `Watch` mode
  - confirm active subtitle highlight follows playback and seeking
  - confirm the highlight snaps to the next subtitle exactly at cue boundaries and does not flicker during short silent gaps
  - confirm translated lessons visually prioritize the English line while keeping Kannada readable underneath
  - confirm Azure-configured `Watch` mode generates English subtitles once and reuses cached subtitle translation on the next open
  - confirm missing Azure config leaves `Watch` mode playable and clearly labeled as Kannada-only
  - confirm transient subtitle-translation failure still leaves the subtitle panel usable with source subtitles and shows the Azure-request-failed message
  - confirm unreadable/mostly-unchanged Azure output is rejected and labeled as rejected English subtitle output
  - confirm cached English subtitles remain visible even if a later retry fails
  - confirm following/unfollowing a suggestion channel reorders cards immediately
  - confirm imported YouTube rows show thumbnail, source badge, and channel metadata
  - confirm imported item appears in `Continue Reading` only after the first reader open
  - confirm `Pull 3 New Lessons` imports a deterministic batch and opens the first imported lesson
  - confirm a second `Pull 3 New Lessons` tap revalidates discovery candidates and does not get stuck on stale invalid-cache entries
  - confirm clearing library rows does not allow immediate re-import of the exact same prior video IDs (history dedupe still applies)
  - confirm discovery cards split correctly between `New to Import` and `Already in Library`
  - confirm auto top-up runs only when cooldown elapsed and unread threshold is below trigger
  - confirm when discovery fails, cached suggestions are still shown if available
  - confirm `Settings -> Auto Content` reflects last auto attempt/success timestamps
  - confirm app logs no BGTask registration warning (`BGTaskSchedulerPermittedIdentifiers` present in Info.plist)

## Project Generation
- If you add or remove source files, run `xcodegen generate` to update `LanguageReader.xcodeproj`.

## Dictionary (Local Full Dataset)
1. Build the bundled SQLite dictionary:
   `./scripts/build_dictionary.py`
2. (Optional) Install into the simulator Documents directory to override:
   `./scripts/install_dictionary.sh`

The app will automatically use the Documents SQLite file if present. Otherwise it uses bundled resources:
- `LanguageReader/Resources/dictionary.sqlite` for Kannada
- `LanguageReader/Resources/dictionary_de.sqlite` for German

Dictionary quality notes:
- Build script now normalizes meanings for concise display (strips leading metadata and trims multi-sense tails).
- Runtime lookup now includes broader Kannada suffix handling, light `-ುತ್ತ...` progressive verb fallback, and conservative German suffix stripping.
- Runtime lookup path is language-profile based (`kn` has inflection rules; other languages use generic exact lookup by default).
- Missing-word cloud fallback results are cached in `Documents/dictionary_cloud_cache.tsv`.
- Settings -> Dictionary Quality evaluates your local saved documents (coverage) and saved vocab meanings (accuracy).
- `Refresh quality` performs aggressive remote enrichment from the current corpus before scoring (no fixed candidate cap), then reuses cached meanings on later runs.
- Summarize local missing words by frequency:
  `python3 scripts/summarize_missing_words.py --input Documents/dictionary_missing.tsv --top 20`
- Evaluate the German bundled dictionary:
  `python3 scripts/evaluate_dictionary.py --source-language de --report-json /tmp/german_dictionary_eval.json`
- Known missing-word regressions are fixture-driven:
  - fixture: `LanguageReaderTests/Fixtures/dictionary_missing_fixture.tsv`
  - test: `xcodebuild -scheme LanguageReader -destination "id=$(./scripts/select_simulator.sh)" test -only-testing:LanguageReaderTests/DictionaryMissingFixtureTests`
- Re-run dictionary-focused tests after lookup changes:
  `xcodebuild -scheme LanguageReader -destination "id=$(./scripts/select_simulator.sh)" test -only-testing:LanguageReaderTests/DictionaryManagerTests`

Language onboarding:
- Follow `docs/LANGUAGE_ONBOARDING_CHECKLIST.md` when wiring a new source language.

## Dictionary Overrides
- Overrides: `Documents/dictionary_overrides.tsv` (normalized_key<TAB>meaning).
- Missing list: `Documents/dictionary_missing.tsv`.

## Simulator Notes
- Use Simulator for all testing.
- If iPhone 14 Pro is unavailable, select the closest recent iPhone runtime.
- Simulator acceptance is mandatory for each change: build, launch, and exercise the touched flow in the real app UI before sign-off.
- For YouTube playback changes, do one real-iPhone verification before sign-off because embedded player behavior is higher risk on device than text-only reader flows.
