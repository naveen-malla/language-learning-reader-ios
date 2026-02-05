# Development

## Requirements
- Xcode latest stable
- iOS Simulator
- xcodegen (`brew install xcodegen`) for regenerating the project when files change

## Run
1. Open `LanguageReader.xcodeproj` in Xcode.
2. Select an iPhone Simulator (prefer iPhone 14 Pro; otherwise use the newest available).
3. Build and run.

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

## Project Generation
- If you add or remove source files, run `xcodegen generate` to update `LanguageReader.xcodeproj`.

## Dictionary (Local Full Dataset)
1. Build the bundled SQLite dictionary:
   `./scripts/build_dictionary.py`
2. (Optional) Install into the simulator Documents directory to override:
   `./scripts/install_dictionary.sh`

The app will automatically use the Documents SQLite file if present. Otherwise it uses the bundled `LanguageReader/Resources/dictionary.sqlite`.

## Simulator Notes
- Use Simulator for all testing.
- If iPhone 14 Pro is unavailable, select the closest recent iPhone runtime.
