# Decisions

This file records durable architecture and product decisions. Active checklist work belongs in `PLAN.md`, and detailed product behavior belongs in `README.md`.

## Storage
- SwiftData for local persistence (documents + vocabulary). Simple, native, and testable.
- `Document` and `VocabEntry` both persist a source/study `languageCode` so content and vocab remain language-scoped even when the global picker changes.
- Vocab identity is a stored scoped key (`language + normalized_key`) instead of a single global normalized key.
- Reader maintains a cached normalized-key status map and refreshes it on lifecycle/save events instead of rebuilding per render.
- Ignored words are persisted separately in `UserDefaults` and split by language for lightweight filtering without schema migration.
- `Document` stores source metadata so one model can represent text imports and YouTube imports:
  - `sourceType`, `sourceURL`, `sourceVideoID`, `sourceChannel`, `sourceChannelID`, `sourceCategory`, `sourceDurationSeconds`, `thumbnailURL`
  - `subtitleCuesRaw` and `translatedSubtitleCuesRaw` persist JSON-backed timed source cues and cached English subtitle cues for imported YouTube lessons
  - `importModeRaw` (`manual`, `smartPack`, `autoTopUp`) and `autoBatchID` for batch analytics/recovery
  - `firstOpenedAt`, `lastOpenedAt` for behavior-based shelves (`Continue Reading`).
- Flashcard telemetry, suggestion cache state, auto-import history, and auto-import run timestamps are also scoped by language.

## Home IA
- Main app entry is `Library`, not the old paste-first Reader composer.
- A persistent study-language selector controls Library, Vocab, Flashcards, Settings quality checks, and YouTube discovery/import.
- Library prioritizes import + shelf behavior:
  - quick import (`Paste Text`, `Text File`, `YouTube URL`)
  - subtitle-verified beginner suggestions
  - full mixed-source library list
  - continue shelf based on actual open behavior.
- New lessons should remain labeled as new until first reader open (`firstOpenedAt == nil`).
- Fresh installs default to German; migrated installs stay Kannada-first to avoid silently reinterpreting existing data.
- Beginner suggestion ranking uses local preference signals only (followed channels + imported category/channel history), keeping personalization offline and deterministic.
- Suggestion ranking normalizes followed-channel and history keys at ranking time (trim + lowercase, merged duplicates) so minor storage-format drift does not silently degrade personalization.

## Tokenization
- NaturalLanguage when available for better word boundaries.
- Fallback tokenizer to keep behavior deterministic in simulator.
- Reader precomputes sentence blocks and tokenized sentence blocks when source text changes.

## Reader Interaction Model
- Word mode remains full-document vertical reading.
- Sentence mode uses a horizontal one-sentence pager for focused review.
- Reader lookup, translation, and watch-mode source-language behavior follow the stored document language rather than the global study-language picker.
- Imported YouTube lessons keep reading mode as the default open state and add a secondary inline `Watch` mode inside the same reader screen instead of forking into a separate lesson player.
- `Watch` mode uses a `WKWebView`-hosted YouTube iframe player to stay within YouTube embed requirements and keep playback controls inside the reader layout.
- Reader chrome stays outside the player surface; the compact top slider doubles as a video scrubber while subtitles render below the player.
- Legacy imported YouTube documents recover timed subtitle cues lazily from `sourceVideoID` on reader open instead of forcing a full re-import just to unlock `Watch`.
- Subtitle presentation now treats translated English as the primary lyric line and keeps source Kannada as a lighter supporting line to preserve study context without flattening the translation focus.
- Sentence detail content is integrated directly into each sentence page (no extra overlay panel).
- Sentence page layout favors screen usage over card chrome: reduced horizontal inset, compact top bar, and a capped/scrollable sentence header region.
- Sentence header uses adaptive top alignment so long lines are anchored higher and do not waste vertical space above the sentence.
- Sentence pages show pronunciation in Latin script using the same `Transliterator` used for word-level pronunciation, keeping pronunciation rules consistent.
- Sentence word list omits `known` and ignored words to reduce noise and emphasize unresolved vocabulary.
- Sentence paging/progress/filter logic lives in a small model (`SentenceReaderModel`) so it can be tested without UI harnesses.

## Visual System
- Use one shared theme/token file (`DesignSystem.swift`) for accent colors, card chrome, and status chip styling to keep tab-level UI consistent.
- Keep a deliberate contrast split: light app shell for management screens, dark reader canvas for immersion and longer reading sessions.
- Prefer rounded card surfaces and capsule controls over dense form rows to reduce interaction friction during repeated vocab updates.
- Keep micro-interactions subtle and functional: shared press states for token taps and icon actions are preferred over heavy animation.
- YouTube suggestion rows intentionally include thumbnails, compact metadata chips, and explicit import/open actions so new-vs-imported state stays visible without hidden horizontal carousels.

## Learning State Model
- Canonical tracked vocab states are `level1`, `level2`, `level3`, `level4`, and `known`.
- Status display labels and learning-stage meanings are centralized on `VocabStatus` so Reader, Vocab, and Flashcards stay aligned.
- `New` is intentionally not stored in vocab; it is derived when no vocab entry and no ignore flag exists for a normalized key.
- One shared resolver determines word visual state across reader text view, sentence view, vocab, and flashcard flows.
- Level selection UI is standardized around a badge-triggered status picker (`1/2/3/4/Known`) with explicit meaning text and current-selection checkmark.
- Backward compatibility is preserved for stored legacy values (`new -> level1`, `learning -> level2`, `known -> known`).
- Flashcard review deck includes only learning levels (`level1` through `level4`), excludes suspended cards, and is filtered by due date.
- Flashcards intentionally use a simple LingQ-style binary flow (`Flip` -> `Wrong`/`Correct`) instead of multi-rating schedulers.
- Flashcards test each due word in both directions in-session (`word -> meaning`, `meaning -> word`) before finalizing a level outcome.
- Directional prompts are intentionally separated within a session (not immediate back-to-back for the same word when multiple words are queued).
- Flashcard session intake is intentionally capped by a user-configurable `Words per session` setting (default `5`) to keep cognitive load controlled.
- Lightweight daily telemetry (`reviewed`, `correct`) is stored in local `UserDefaults` to show same-day momentum and known-ratio progress without adding backend dependencies.
- Level progression is conservative by design: promote by one level only after two perfect rounds in a row; cap auto-promotion at `level4`.
- Demotion is lightweight: only rounds with two wrong answers demote one level (minimum `level1`); mixed rounds keep level unchanged.
- `known` remains a manual-only state change and is never auto-assigned by flashcards.
- Due intervals are fixed by level (`1`, `3`, `7`, `15` days), and a one-time migration normalizes old minute/hour schedules into this model.

## Dictionary
- Offline dictionary with indexed lookup for fast taps.
- If full dataset is too large for git, download locally and build index DB.
- Bundle separate SQLite dictionaries per source language so provider selection stays simple and lookups remain offline.
- Kannada uses the existing Alar source.
- German uses the official FreeDict German-English TEI source and is built into `dictionary_de.sqlite`.
- Keep lookup architecture language-agnostic via `DictionaryLanguageProfile` (generic default plus language-specific inflection rules).
- Use heuristic suffix stripping for Kannada inflections (including common accusative/genitive forms); not a full morphological analyzer.
- Use conservative suffix stripping for German inflections (`-e`, `-en`, `-er`, `-es`, `-em`, `-n`, `-s`) without compound splitting in this pass.
- Add a lightweight progressive-verb fallback (`-ುತ್ತ...` forms) to improve hit rate on reading text without a full lemmatizer.
- Kannada stem minimum lengths are enforced by Unicode scalar count (not grapheme count) so short-but-valid stems like `ಕಾ` are not dropped.
- Progressive verb candidate generation normalizes stems that already end with Kannada `ು` signs to avoid malformed duplicates and preserve both bare stem and infinitive candidates.
- Prefer concise meanings in UI by stripping metadata prefixes and trimming long multi-sense tails.
- Resolve single-hop dictionary redirects that use `=` prefix; strip trailing digits in redirect targets.
- Maintain a local TSV override file and missing-word log in Documents for quick corrections without re-bundling.
- Overrides and missing-word logs are split per language so German corrections do not bleed into Kannada and vice versa.
- Treat `dictionary_missing.tsv` as a feedback signal: aggregate by normalized-word frequency and prioritize the highest-frequency misses first.
- Keep known missing-word regressions fixture-driven (`LanguageReaderTests/Fixtures/dictionary_missing_fixture.tsv`) so suffix/redirect fixes stay locked by tests.
- Store cloud-fetched missing meanings in `dictionary_cloud_cache.tsv` keyed by `language + normalized_key`.
- When loading cloud-cache TSV rows with duplicate `language + normalized_key`, keep the entry with the newest `updated_at` timestamp so stale rows cannot override fresher cache values after merges/imports.
- SQLite-backed dictionary lookups run through a serialized queue and use per-lookup prepared statements to prevent shared-statement races under concurrent sentence prefetch.
- Lookup priority is: override -> local dictionary candidates -> cloud cache -> optional remote fallback.
- Settings quality metrics are computed from local app data (saved documents + saved vocab meanings) so the score reflects each user’s actual library, with fixture fallback only when local data is empty.
- Manual `Refresh quality` now runs a remote enrichment pass over unresolved corpus words before computing the gate, prioritizing correctness for real personal libraries over request minimization.
- New language additions follow a repeatable onboarding checklist (`docs/LANGUAGE_ONBOARDING_CHECKLIST.md`) to avoid per-language re-engineering.

## Translation APIs
- Optional only; no runtime dependency in MVP.
- API key stored in Keychain.
- Azure Translator is the first network provider for sentence translation (`source -> en`) when configured.
- Azure Translator is also the primary path for English subtitle translation in `Watch` mode; translation now starts prefetching on reader open for imported videos and is cached locally on the document.
- Endpoint + source/target language are stored in `UserDefaults`; API key remains in Keychain. Region is stored when provided and treated as optional for global translator resources.
- Translator endpoint must be an absolute `http/https` URL with a host to avoid invalid runtime configurations.
- Active subtitle selection advances at exact cue starts and intentionally keeps the previous cue selected through short gaps so the lyric-style highlight remains stable during playback and seeking.
- Sentence translation has a secondary public web fallback provider so no-key setups still get best-effort translations at tap time.
- Translator client and subtitle translation reject empty, unchanged, or obviously source-language output using language-aware heuristics instead of Kannada-only checks.
- Reader keeps an in-memory sentence translation cache to reduce repeated request latency/cost.
- Subtitle translation uses the same Azure settings store as sentence translation and falls back to the public translator when Azure is unavailable, misconfigured, or returns unreadable output.
- Subtitle fallback messaging stays simple at runtime: keep playback usable, prefer cached English cues when present, and only surface a generic unavailable state when no readable English subtitle path succeeds.
- Cloud/public/fallback outputs all pass the same readability gate before display, so mixed Kannada+English sentence output is rejected.
- Failed/unavailable sentence translation outcomes are intentionally not cached, so a new tap reattempts network paths.
- If network translation is unavailable, reader falls back to offline gloss only when gloss readability is high; otherwise it returns explicit unavailable status text instead of mixed-script output.
- For missing single-word meanings, optional Azure-backed fallback is used and persisted locally so repeated lookups stay offline after first fetch.

## YouTube Import Architecture
- V1 import avoids requiring user API keys by using public YouTube web endpoints:
  - extract innertube API key from watch HTML
  - call `youtubei/v1/player` for metadata and caption tracks
  - select subtitle tracks based on the active study language.
- URL parsing accepts only real YouTube hosts (`youtube.com`/subdomains and `youtu.be`) to avoid false-positive imports from lookalike domains.
- Transcript extraction uses subtitle XML parsing that preserves timing (`start`/`dur`), normalizes/merges readable subtitle cues, and then derives the existing newline-delimited lesson body from those cues.
- Older documents that predate timed-cue persistence can backfill subtitle cues from the original YouTube source while leaving the stored lesson body unchanged.
- Import path gates on language-appropriate subtitles plus transcript readability heuristics, including numeric-sequence rejection.
- German requires direct `de*` subtitle tracks.
- Kannada prefers native `kn*` subtitle tracks and can still fall back to translatable tracks rendered in Kannada when direct tracks are unavailable.
- Consecutive duplicate subtitle lines are only collapsed when their timings are adjacent enough to represent the same caption event; repeated lines with large time gaps stay separate.
- Suggestion shelf uses dynamic channel-seed RSS discovery plus live YouTube search-results discovery, then validates runtime subtitle availability and duration range for the selected language.
- Library discovery UI is intentionally split into `New to Import` and `Already in Library` to make feed freshness state explicit and avoid hidden duplication confusion.
- Discovery/validation results are cached locally with TTL and exponential backoff to keep behavior deterministic during endpoint volatility.
- Force-refresh discovery bypasses cached invalid validation records and revalidates candidates to recover from transient endpoint failures.
- Auto-import keeps a persisted history of imported video IDs so previously imported items are still skipped even after library cleanup.
- Library/queue presentation deduplicates rows by `sourceVideoID` to prevent duplicate visual clutter.
- Smart pack and auto top-up share one batch planner:
  - manual pull target: 3 new lessons per tap
  - duration window: 5 to 20 minutes
  - validation budget: 60 candidates
  - validation concurrency: 6
  - auto trigger: unread imported YouTube lessons `< 3`
  - auto cooldown: 24 hours
- Repeat-import fallback is available but defaults to off so fresh imports are prioritized.
- Background refresh is optional/best-effort and uses the same coordinator/rate limits as foreground checks.
- Suggestion ranking normalizes followed-channel and history keys (case/whitespace) but discards empty normalized keys so malformed profile data cannot over-boost videos with missing metadata.

## Testing Strategy
- Prioritize regression and edge-case tests from the beginning, not only smoke tests.
- Every user-reported bug should add a corresponding automated test before closure.
- Simulator-first acceptance: every change must be run in the simulator and the touched flow must be verified in the actual app UI before completion.
- Reliability-first tradeoff policy: if iPhone 14 Pro can run the solution comfortably, prefer robustness/coverage over storage or cost optimizations.
