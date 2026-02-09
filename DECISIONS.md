# Decisions

## Storage
- SwiftData for local persistence (documents + vocabulary). Simple, native, and testable.
- Reader maintains a cached normalized-key status map and refreshes it on lifecycle/save events instead of rebuilding per render.

## Tokenization
- NaturalLanguage when available for better word boundaries.
- Fallback tokenizer to keep behavior deterministic in simulator.
- Reader precomputes sentence blocks and tokenized sentence blocks when source text changes.

## Reader Interaction Model
- Word mode remains full-document vertical reading.
- Sentence mode uses a horizontal one-sentence pager for focused review.
- Sentence panel omits `known` words to reduce noise and emphasize unresolved vocabulary.
- Sentence paging/progress/filter logic lives in a small model (`SentenceReaderModel`) so it can be tested without UI harnesses.

## Dictionary
- Offline dictionary with indexed lookup for fast taps.
- If full dataset is too large for git, download locally and build index DB.
- For V1 (Kannada), bundle the full SQLite dictionary in the app so device updates don’t require re-downloads.
- For future languages, plan to separate dictionaries from the app bundle and provide download links/install flow.
- Use light heuristic suffix stripping for Kannada inflections; not a full morphological analyzer.
- Resolve single-hop dictionary redirects that use `=` prefix; strip trailing digits in redirect targets.
- Maintain a local TSV override file and missing-word log in Documents for quick corrections without re-bundling.

## Translation APIs
- Optional only; no runtime dependency in MVP.
- API key stored in Keychain.
- V1 uses an offline dictionary-based sentence gloss when the user taps translate (rough translation, not full grammar).

## Testing Strategy
- Prioritize regression and edge-case tests from the beginning, not only smoke tests.
- Every user-reported bug should add a corresponding automated test before closure.
