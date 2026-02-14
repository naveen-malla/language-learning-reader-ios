# LanguageReader

A personal language reading app with vocabulary tracking and simple flashcards.

## MVP Scope
- Paste text into the app and save as a document (initial scope: Kannada).
- Reader has a direct `Paste from Clipboard` action for simulator/device reliability.
- App shell uses a soft pastel canvas with rounded cards and a translucent tab bar for quick visual scanning.
- Reader composer shows live writing stats (`words`, `sentences`, `estimated read time`) before save.
- Read the document in a full-bleed reader with a progress slider.
- Toggle between word-level and sentence-level reading using a bottom-center mode button with horizontal transition.
- Word tokens are grouped by sentence for more readable spacing.
- In sentence mode, swipe horizontally through exactly one sentence per page.
- In sentence mode, each page integrates all sentence details directly in the reader:
  - a single sentence shown once in a full-width page layout
  - sentence pronunciation in Latin script (transliteration) under the sentence
  - translate action (Azure Translator when configured, otherwise offline dictionary gloss fallback)
  - sentence, transliteration, and translation live in one unified top canvas (single scroll area)
  - top canvas keeps a stable center anchor; content only shifts naturally when it truly overflows
  - only unresolved words (new + learning; known and ignored words are hidden)
  - pronunciation + meaning for visible words in an in-page list
  - unified reading text size (`17pt`) across sentence text, transliteration, translations, and word meanings
- New rows in sentence mode provide direct actions: `+` (add Level 1), `✓` (mark Known), and `delete` (ignore permanently).
- Add words to vocabulary with canonical status levels: `1`, `2`, `3`, `4`, and `Known` (`New` is untracked).
- Color-code words by status in the reader with one shared resolver across text and sentence views.
- Vocab list with search and always-visible one-tap level controls (`1 2 3 4 Known`).
- Flashcards with direct level controls (`1 2 3 4 Known`) and a review deck that includes only levels `1-4`.
- Vocab and Flashcards include compact progress pills (`Total`, `Learning`, `Known` / `Deck`, `Known`, `Index`) for fast session awareness.
- Documents list surfaces a short preview + word count metadata for faster re-entry.
- Settings for optional translation API key and dictionary source/licensing info.
- App seeds two larger Kannada sample documents on first launch for quick testing.
- Reader caches sentence splits and word tokenization per document text to keep scrolling responsive.

## Run Instructions
Prerequisites:
- Xcode (latest stable)
- iOS Simulator

Steps:
1. Open `LanguageReader.xcodeproj` in Xcode.
2. Select an iPhone Simulator (prefer iPhone 14 Pro; otherwise use the newest available).
3. Build and run.

CLI (once project exists):
- List simulators: `xcrun simctl list`
- Boot simulator: `open -a Simulator`
- Build: `xcodebuild -scheme LanguageReader -destination 'platform=iOS Simulator,name=iPhone 14 Pro' build`
- Guard repository hygiene (main-only): `./scripts/guard_main.sh`

## Dictionary Data
The app uses an offline dictionary for the initial language. A full dictionary is bundled in the app for Kannada so device updates do not require re-downloading.

```bash
./scripts/build_dictionary.py
```

This downloads the Alar dataset and writes `LanguageReader/Resources/dictionary.sqlite` (bundled in the app). The app prefers a local `Documents/dictionary.sqlite` if one exists, so you can still override by installing a custom dictionary into the app container.

Current build behavior:
- Meanings are cleaned to be more concise before insertion (metadata prefixes removed, multi-sense tails truncated).
- Redirect entries (`= ...`) are preserved so runtime redirect resolution still works.

## Dictionary Overrides
- Enable “Show diagnostics” in Settings to see lookup paths.
- Local overrides live in `Documents/dictionary_overrides.tsv` (TSV: normalized_key<TAB>meaning).
- Missing meanings are logged to `Documents/dictionary_missing.tsv`.

## Azure Translation Setup (Optional)
- Open Settings -> Translation API.
- Enter:
  - Endpoint: `https://api.cognitive.microsofttranslator.com`
  - Region: your Azure region code (for example `germanywestcentral`)
  - Key 1: saved to Keychain only (never stored in source or `UserDefaults`)
- Tap `Save Translation Settings`.

## Known Limitations
- Dictionary coverage depends on the bundled subset or locally downloaded dataset.
- Translation API is optional and not required for the MVP.
- Inflected Kannada forms use heuristic suffix and verb-form stripping (including common accusative/genitive endings and `-ುತ್ತ...` progressive forms); it still won’t cover full morphology.
- Some dictionary entries are redirects (`=`) or aliases; the app resolves one hop only.
- Meaning cleanup is heuristic and may occasionally shorten a definition too aggressively; use overrides to correct.
- Sentence translation uses Azure if configured; if unavailable/failing, it falls back to dictionary gloss.
- Azure dictionary lookup endpoints are not available for Kannada, so per-word meanings stay dictionary-first.
- Sentence detection uses NaturalLanguage sentence boundaries; long/irregular punctuation still needs refinement.
- Ignored words are currently permanent (no management screen yet).
