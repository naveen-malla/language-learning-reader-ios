# Decisions

## Storage
- SwiftData for local persistence (documents + vocabulary). Simple, native, and testable.

## Tokenization
- NaturalLanguage when available for better word boundaries.
- Fallback tokenizer to keep behavior deterministic in simulator.

## Dictionary
- Offline dictionary with indexed lookup for fast taps.
- If full dataset is too large for git, download locally and build index DB.

## Translation APIs
- Optional only; no runtime dependency in MVP.
- API key stored in Keychain.
