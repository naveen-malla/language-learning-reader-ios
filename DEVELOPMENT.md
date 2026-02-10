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

## Reader Input Notes
- If simulator keyboard paste is unreliable, use `Paste from Clipboard` in Reader.
- Two large sample documents are seeded on first launch; open them via Reader -> Documents.
- In sentence mode, swipe horizontally to move one sentence at a time.
- Sentence mode now keeps details in-page: centered sentence -> translate action -> unresolved word list.
- Bottom mode button copy is `Sentence View` in full text mode and `Text View` in sentence mode.
- Sentence header text is reduced to `30pt` and uses token-level highlight colors.
- Sentence header now includes a transliterated pronunciation line under the sentence.
- Translation text is wrapped inside a fixed-height scrollable area below the translate action.

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
- When a production issue is observed, add a regression test in the same change.
- For reader performance issues, confirm sentence/token preprocessing does not rerun on pure scroll updates.
- Keep sentence-mode behavior testable in unit tests (clamped index, progress mapping, and known+ignored filtering).
- Manual reader checks after sentence-mode changes:
  - confirm sentence appears once per page (no duplicate overlay card)
  - confirm translate action and unresolved word list are visible in the same page
  - confirm sentence transliteration is visible under the sentence and stays readable on long lines
  - confirm tapping a listed word still opens the word detail sheet
  - confirm the same word uses the same highlight state in text view and sentence view
  - confirm new-word quick actions exist (`+`, `✓`, `delete`) and apply immediately
  - confirm learning rows show `L1-L4` badges
  - confirm vocab and flashcards expose direct one-tap controls (`1 2 3 4 Known`) with no dropdowns
  - confirm flashcard review pool excludes `Known`

## Project Generation
- If you add or remove source files, run `xcodegen generate` to update `LanguageReader.xcodeproj`.

## Dictionary (Local Full Dataset)
1. Build the bundled SQLite dictionary:
   `./scripts/build_dictionary.py`
2. (Optional) Install into the simulator Documents directory to override:
   `./scripts/install_dictionary.sh`

The app will automatically use the Documents SQLite file if present. Otherwise it uses the bundled `LanguageReader/Resources/dictionary.sqlite`.

## Dictionary Overrides
- Overrides: `Documents/dictionary_overrides.tsv` (normalized_key<TAB>meaning).
- Missing list: `Documents/dictionary_missing.tsv`.
- Use Settings -> Dictionary Quality to create the overrides file if needed.

## Simulator Notes
- Use Simulator for all testing.
- If iPhone 14 Pro is unavailable, select the closest recent iPhone runtime.
