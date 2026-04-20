# Language Onboarding Checklist

Use this checklist to add a new source language without reworking core architecture.

## 1. Dictionary Source
- Collect raw dictionary data for the target language.
- Normalize raw entries into `key`, `word`, `meaning` rows.
- Run `./scripts/build_dictionary.py` and confirm the SQLite output is valid.

## 2. Language Profile
- Add/extend `DictionaryLanguageProfile` rules for the language code.
- Start with minimal, defensible heuristics only:
  - high-frequency inflection suffixes
  - common verb-progressive endings (if relevant)
- Keep generic fallback behavior intact for unsupported forms.

## 3. Lookup Regression Fixtures
- Add high-frequency known failures to a fixture TSV in tests.
- Cover suffix and redirect paths where applicable.
- Add/extend unit tests so fixture rows must resolve expected meanings.

## 4. Quality Fixture
- Add a fixture in `scripts/eval_fixtures/*.json` with:
  - corpus sentences
  - gold words + accepted meanings
  - minimum thresholds (token coverage, unique coverage, gold hit rate, gold accuracy)
- Run: `python3 scripts/evaluate_dictionary.py --report-json /tmp/dictionary_eval_report.json`

## 5. Missing-Word Feedback Loop
- Verify `Documents/dictionary_missing.tsv` is being written in app.
- Summarize unresolved frequency:
  - `python3 scripts/summarize_missing_words.py --input Documents/dictionary_missing.tsv --top 20`
- Prioritize top unresolved words into overrides or profile fixes.

## 6. UI/Workflow Checks
- Confirm reader tap lookup stays responsive with the new language profile.
- Confirm diagnostics path labels remain correct (`direct/suffix/redirect/override/cache/remote/none`).
- Confirm cloud fallback remains optional and never blocks offline flow.

## 7. Test and Build Gate
- Targeted dictionary tests:
  - `xcodebuild -scheme LanguageReader -destination "id=$(./scripts/select_simulator.sh)" test -only-testing:LanguageReaderTests/DictionaryManagerTests`
- Full test suite:
  - `./scripts/test.sh`
- Simulator build:
  - `./scripts/build.sh`

## 8. Docs Update Gate
- Update all of these before merge:
  - `README.md`
  - `DEVELOPMENT.md`
  - `DECISIONS.md`
  - `PLAN.md`
