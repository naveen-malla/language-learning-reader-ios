# Decisions

## Storage
- SwiftData for local persistence (documents + vocabulary). Simple, native, and testable.

## Tokenization
- NaturalLanguage when available for better word boundaries.
- Fallback tokenizer to keep behavior deterministic in simulator.

## Dictionary
- Offline dictionary with indexed lookup for fast taps.
- If full dataset is too large for git, download locally and build index DB.
- For V1 (Kannada), bundle the full SQLite dictionary in the app so device updates don’t require re-downloads.
- For future languages, plan to separate dictionaries from the app bundle and provide download links/install flow.

## Translation APIs
- Optional only; no runtime dependency in MVP.
- API key stored in Keychain.
