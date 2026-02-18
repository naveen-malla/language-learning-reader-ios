# Decisions

## Storage
- SwiftData for local persistence (documents + vocabulary). Simple, native, and testable.
- Reader maintains a cached normalized-key status map and refreshes it on lifecycle/save events instead of rebuilding per render.
- Ignored words are persisted separately in `UserDefaults` as normalized keys for lightweight filtering without schema migration.
- `Document` stores source metadata so one model can represent text imports and YouTube imports:
  - `sourceType`, `sourceURL`, `sourceVideoID`, `sourceChannel`, `sourceCategory`, `sourceDurationSeconds`, `thumbnailURL`
  - `firstOpenedAt`, `lastOpenedAt` for behavior-based shelves (`Continue Reading`).

## Home IA
- Main app entry is `Library`, not the old paste-first Reader composer.
- Library prioritizes import + shelf behavior:
  - quick import (`Paste Text`, `YouTube URL`)
  - subtitle-verified beginner suggestions
  - full mixed-source library list
  - continue shelf based on actual open behavior.
- New lessons should remain labeled as new until first reader open (`firstOpenedAt == nil`).

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
- YouTube suggestion cards intentionally include thumbnails, compact metadata chips, and explicit import actions to reduce choice friction.

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
- Prefer concise meanings in UI by stripping metadata prefixes and trimming long multi-sense tails.
- Resolve single-hop dictionary redirects that use `=` prefix; strip trailing digits in redirect targets.
- Maintain a local TSV override file and missing-word log in Documents for quick corrections without re-bundling.
- Store cloud-fetched missing meanings in `dictionary_cloud_cache.tsv` keyed by `language + normalized_key`.
- Lookup priority is: override -> local dictionary candidates -> cloud cache -> optional remote fallback.
- Settings quality metrics are computed from local app data (saved documents + saved vocab meanings) so the score reflects each user’s actual library, with fixture fallback only when local data is empty.

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
- Transcript extraction uses subtitle XML parsing and normalization into one newline-delimited lesson body.
- Suggestion shelf uses a vetted seed catalog and performs runtime subtitle validation so the UI only shows currently importable entries.
- Beginner feed currently enforces short-form duration guardrails (max 12 minutes) to prevent overload for new learners.

## Testing Strategy
- Prioritize regression and edge-case tests from the beginning, not only smoke tests.
- Every user-reported bug should add a corresponding automated test before closure.
