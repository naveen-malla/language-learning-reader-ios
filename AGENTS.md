# AGENTS.md

## Project Intent
Build a language reader iOS app (initial scope: Kannada) with fast, offline-friendly word lookup, vocabulary tracking, and flashcards. Keep the UX clean and focused on reading.

## Non-Goals
- No cloud sync in V1.
- No hard dependency on online translation APIs.
- No reliance on Apple Translation framework for core functionality.

## Workflow
- Ship a basic working function first, then scale.
- Challenge assumptions and suggest better approaches.
- Prefer small, inspectable changes and clear structure.
- Keep commits small and focused.
- Build with learning psychology in mind: reduce friction, reinforce recall, and keep the reading flow smooth.

## Git Cadence (Default)
- Commit and push logical checkpoints immediately without waiting for manual approval.
- Pair each checkpoint with the relevant verification (`xcodebuild` or script-based build/test) for touched scope.
- Keep each commit single-purpose and include related docs/tests updates in the same checkpoint.
- Never use force-push.

## Multi-Agent Safety
- Assume parallel agents are active and stage only files touched in the current task (no broad staging).
- Before every push, run `git fetch origin` and `git rebase origin/main`.
- If a rebase conflict overlaps another agent's in-flight work, stop and report instead of overwriting.
- Never erase, reset, or revert unrelated edits.
- Exclude generated/transient artifacts from commits.

## Quality Bar
- Deterministic behavior where possible.
- Clean separation of UI, data, and domain logic.
- Add tests for tokenization and vocab status logic.
- Test quality is a priority from the start: cover edge cases, failure paths, and regressions, not just happy paths.
- When a bug is found, add a failing test first (or in the same change) before shipping the fix.
- Prefer behavior-level tests with realistic text fixtures over trivial property assertions.

## Testing
- Use iOS Simulator for all runs.
- Prefer iPhone 14 Pro if available; otherwise use a recent iPhone runtime.
- Build/run from CLI with `xcodebuild` after each milestone.
- List simulators: `xcrun simctl list`
- Boot simulator: `open -a Simulator`
- Build (xcodebuild): `xcodebuild -scheme LanguageReader -destination 'platform=iOS Simulator,name=iPhone 14 Pro' build`
- Test (xcodebuild): `xcodebuild -scheme LanguageReader -destination 'platform=iOS Simulator,name=iPhone 14 Pro' test`
- Target a single test: `xcodebuild -scheme LanguageReader -destination "id=$(./scripts/select_simulator.sh)" test -only-testing:LanguageReaderTests/DictionaryManagerTests`

## Local Scripts
- Build (simulator): `./scripts/build.sh`
- Run (build/install/launch): `./scripts/run.sh`
- Test: `./scripts/test.sh`
- Boot simulator: `./scripts/boot_simulator.sh`
- Select simulator: `./scripts/select_simulator.sh`
- Build bundled dictionary: `./scripts/build_dictionary.py`
- Evaluate dictionary quality (coverage/meaning fixtures): `./scripts/evaluate_dictionary.py`
- Evaluate dictionary with JSON report: `python3 scripts/evaluate_dictionary.py --report-json /tmp/dictionary_eval_report.json`
- Evaluate without failing thresholds: `python3 scripts/evaluate_dictionary.py --no-fail-on-thresholds`
- Dictionary evaluation tests: `./scripts/test_evaluate_dictionary.py`
- Summarize missing words by frequency: `python3 scripts/summarize_missing_words.py --input Documents/dictionary_missing.tsv --top 20`
- Missing-word summary tests: `./scripts/test_summarize_missing_words.py`
- Install dictionary into simulator: `./scripts/install_dictionary.sh`
- Repo hygiene guard (main-only check/cleanup): `./scripts/guard_main.sh`
- Enforce cleanup to main-only state: `./scripts/guard_main.sh --cleanup`
- Cleanup while allowing local edits: `./scripts/guard_main.sh --cleanup --allow-dirty`

## Project Generation
- Prerequisite: install xcodegen if missing (`brew install xcodegen`).
- If source files are added or removed, run `xcodegen generate`.

## Dictionary Data Paths
- Overrides: `Documents/dictionary_overrides.tsv` (normalized_key<TAB>meaning).
- Missing list: `Documents/dictionary_missing.tsv`.
- Cloud fallback cache: `Documents/dictionary_cloud_cache.tsv`.

## Data & Secrets
- Never commit secrets.
- Store optional API keys in Keychain only.
- Avoid assistant/tool branding or AI references in code or UI.

## UI/UX Principles
- Reading-first layout.
- Tappable tokens must feel responsive.
- Color coding for vocab status should be consistent and unobtrusive.

## Documentation Discipline
- Always update relevant docs after any change or decision without waiting for a prompt.
- Update `README.md` for scope, run steps, known limits, and user-facing behavior changes.
- Update `DEVELOPMENT.md` for workflow, scripts, build/test steps, and environment requirements.
- Update `DESIGN.md` for UX flows, UI behavior, and interaction changes.
- Update `DECISIONS.md` for architectural choices, data/storage changes, and tradeoffs.
