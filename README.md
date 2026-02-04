# LanguageReader

A personal language reading app with vocabulary tracking and simple flashcards.

## MVP Scope
- Paste text into the app and save as a document (initial scope: Kannada).
- Read the document with tappable word tokens.
- Add words to vocabulary with basic status tracking (new/learning/known).
- Color-code words by status in the reader.
- Vocab list with search and status updates.
- Simple flashcards (Kannada prompt, English meaning reveal).
- Settings for optional translation API key and dictionary source/licensing info.

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
- Build: `xcodebuild -scheme LanguageReader -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`

## Dictionary Data
The app uses an offline dictionary for the initial language. If the full dataset is too large for git, it will be downloaded locally and indexed into a fast lookup DB (ignored from git).

## Known Limitations
- Dictionary coverage depends on the bundled subset or locally downloaded dataset.
- Translation API is optional and not required for the MVP.
