# Decisions

## Storage
- SwiftData for local persistence (documents + vocabulary). Simple, native, and testable.
- Reader maintains a cached normalized-key status map and refreshes it on lifecycle/save events instead of rebuilding per render.
- Ignored words are persisted separately in `UserDefaults` as normalized keys for lightweight filtering without schema migration.
- `Document` stores source metadata so one model can represent text imports and YouTube imports:
  - `sourceType`, `sourceURL`, `sourceVideoID`, `sourceChannel`, `sourceChannelID`, `sourceCategory`, `sourceDurationSeconds`, `thumbnailURL`
  - `importModeRaw` (`manual`, `smartPack`, `autoTopUp`) and `autoBatchID` for batch analytics/recovery
  - `firstOpenedAt`, `lastOpenedAt` for behavior-based shelves (`Continue Reading`).

## Home IA
- Main app entry is `Library`, not the old paste-first Reader composer.
- Library prioritizes import + shelf behavior:
  - quick import (`Paste Text`, `Text File`, `YouTube URL`)
  - subtitle-verified beginner suggestions
  - full mixed-source library list
  - continue shelf based on actual open behavior.
- New lessons should remain labeled as new until first reader open (`firstOpenedAt == nil`).
- Beginner suggestion ranking uses local preference signals only (followed channels + imported category/channel history), keeping personalization offline and deterministic.

## Tokenization
- NaturalLanguage when available for better word boundaries.
- Fallback tokenizer to keep behavior deterministic in simulator.
- Reader precomputes sentence blocks and tokenized sentence blocks when source text changes.

## Reader Interaction Model
- Word mode remains full-document vertical reading.
- Sentence mode uses a horizontal one-sentence pager for focused review.
- Sentence detail content is integrated directly into each sentence page (no extra overlay panel).
- Sentence page layout favors screen usage over card chrome: reduced horizontal inset, compact top bar, and a capped/scrollable sentence header region.
- Sentence header uses a stable upper-center anchor so translated lines are visible more often, with only overflow-driven upward adjustment.
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
- For V1 (Kannada), bundle the full SQLite dictionary in the app so device updates don’t require re-downloads.
- For future languages, plan to separate dictionaries from the app bundle and provide download links/install flow.
- Keep lookup architecture language-agnostic via `DictionaryLanguageProfile` (generic default plus language-specific inflection rules).
- Use heuristic suffix stripping for Kannada inflections (including common accusative/genitive forms); not a full morphological analyzer.
- Add a lightweight progressive-verb fallback (`-ುತ್ತ...` forms) to improve hit rate on reading text without a full lemmatizer.
- Kannada stem minimum lengths are enforced by Unicode scalar count (not grapheme count) so short-but-valid stems like `ಕಾ` are not dropped.
- Progressive verb candidate generation normalizes stems that already end with Kannada `ು` signs to avoid malformed duplicates and preserve both bare stem and infinitive candidates.
- Prefer concise meanings in UI by stripping metadata prefixes and trimming long multi-sense tails.
- Resolve single-hop dictionary redirects that use `=` prefix; strip trailing digits in redirect targets.
- Maintain a local TSV override file and missing-word log in Documents for quick corrections without re-bundling.
- Treat `dictionary_missing.tsv` as a feedback signal: aggregate by normalized-word frequency and prioritize the highest-frequency misses first.
- Keep known missing-word regressions fixture-driven (`LanguageReaderTests/Fixtures/dictionary_missing_fixture.tsv`) so suffix/redirect fixes stay locked by tests.
- Store cloud-fetched missing meanings in `dictionary_cloud_cache.tsv` keyed by `language + normalized_key`.
- Lookup priority is: override -> local dictionary candidates -> cloud cache -> optional remote fallback.
- Settings quality metrics are computed from local app data (saved documents + saved vocab meanings) so the score reflects each user’s actual library, with fixture fallback only when local data is empty.
- New language additions follow a repeatable onboarding checklist (`docs/LANGUAGE_ONBOARDING_CHECKLIST.md`) to avoid per-language re-engineering.

## Translation APIs
- Optional only; no runtime dependency in MVP.
- API key stored in Keychain.
- Azure Translator is the first network provider for sentence translation (`kn -> en`) when configured.
- Endpoint + region are stored in `UserDefaults`; API key remains in Keychain.
- Translator endpoint must be an absolute `http/https` URL with a host to avoid invalid runtime configurations.
- Reader keeps an in-memory sentence translation cache to reduce repeated request latency/cost.
- If network translation is unavailable, reader falls back to the existing offline dictionary gloss.
- For missing single-word meanings, optional Azure-backed fallback is used and persisted locally so repeated lookups stay offline after first fetch.

## YouTube Import Architecture
- V1 import avoids requiring user API keys by using public YouTube web endpoints:
  - extract innertube API key from watch HTML
  - call `youtubei/v1/player` for metadata and caption tracks
  - select Kannada subtitle tracks (`kn*`), including auto-generated `asr` tracks.
- URL parsing accepts only real YouTube hosts (`youtube.com`/subdomains and `youtu.be`) to avoid false-positive imports from lookalike domains.
- Transcript extraction uses subtitle XML parsing and normalization into one newline-delimited lesson body.
- Import path gates on Kannada subtitles plus transcript readability heuristics, including numeric-sequence rejection.
- Import prefers native Kannada subtitle tracks and falls back to translatable tracks rendered in Kannada when direct Kannada tracks are unavailable.
- Suggestion shelf uses dynamic channel-seed RSS discovery plus live YouTube search-results discovery, then validates runtime subtitle availability and duration range.
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

## Testing Strategy
- Prioritize regression and edge-case tests from the beginning, not only smoke tests.
- Every user-reported bug should add a corresponding automated test before closure.
- Simulator-first acceptance: every change must be run in the simulator and the touched flow must be verified in the actual app UI before completion.
