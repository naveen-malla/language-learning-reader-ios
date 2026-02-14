# Dictionary Evaluation

## Purpose
This defines how dictionary quality is measured for real reading quality, not just lookup speed.

Targets:
- high coverage (most words get a meaning)
- high correctness (meaning matches sentence intent)

## Metrics
- `token_coverage`: fraction of all tokens in corpus with a resolved meaning.
- `unique_coverage`: fraction of unique words in corpus with a resolved meaning.
- `gold_hit_rate`: fraction of gold words with any resolved meaning.
- `gold_accuracy`: fraction of gold words where meaning matches accepted expectations.

## Evaluator
Script: `scripts/evaluate_dictionary.py`

What it does:
- tokenizes corpus sentences
- applies the same lookup heuristics used by app dictionary flow (normalization, suffix candidates, redirect resolution, concise meaning cleanup)
- computes coverage + gold metrics
- applies fixture thresholds
- optionally writes machine-readable JSON report

## Fixture Format
Location: `scripts/eval_fixtures/*.json`

Minimum structure:
```json
{
  "name": "fixture_name",
  "corpus_sentences": ["..."],
  "gold": [
    {
      "word": "example",
      "accepted_meanings": ["allowed phrase 1", "allowed phrase 2"],
      "match_mode": "contains"
    }
  ],
  "thresholds": {
    "token_coverage_min": 0.8,
    "unique_coverage_min": 0.7,
    "gold_hit_rate_min": 0.85,
    "gold_accuracy_min": 0.7
  }
}
```

`match_mode`:
- `contains` (default): expected phrase appears inside meaning
- `exact`: meaning must match exactly

## Commands
Run evaluator with default fixtures:
```bash
python3 scripts/evaluate_dictionary.py --report-json /tmp/dictionary_eval_report.json
```

Run evaluator without failing on thresholds:
```bash
python3 scripts/evaluate_dictionary.py --no-fail-on-thresholds
```

Run evaluator unit tests:
```bash
python3 scripts/test_evaluate_dictionary.py
```

## Workflow
1. Add/refresh corpus sentences from real reading material.
2. Curate gold words with context-appropriate accepted meanings.
3. Run evaluator and inspect:
   - top unresolved words
   - mismatch list
4. Fix highest-impact issues:
   - improve dictionary entries/building pipeline
   - add overrides for wrong meanings
   - tune language profile rules where justified
5. Re-run until thresholds pass.

## Current Baseline
Initial fixture: `scripts/eval_fixtures/kannada_core_v1.json`

This fixture is intentionally strict on meaning quality so wrong-sense matches are visible early.

