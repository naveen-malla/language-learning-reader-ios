#!/usr/bin/env python3
"""Dictionary quality evaluator.

Evaluates two things:
1) Coverage on a corpus (token and unique word hit rates)
2) Meaning accuracy against a gold fixture (accepted meanings per word)
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sqlite3
import sys
import unicodedata
from collections import Counter
from dataclasses import dataclass
from typing import Any


WORD_PATTERN = re.compile(r"[^\W\d_]+", flags=re.UNICODE)


KANNADA_SUFFIX_RULES: list[tuple[str, int]] = [
    ("ವಾಗಿತ್ತು", 3),
    ("ವಾಗಿ", 3),
    ("ಗಳನ್ನು", 2),
    ("ಗಳಲ್ಲಿ", 2),
    ("ಯಲ್ಲಿ", 2),
    ("ದಲ್ಲಿ", 2),
    ("ನಲ್ಲಿ", 2),
    ("ಯಲಿ", 2),
    ("ಗಳ", 2),
    ("ಗಳು", 2),
    ("ವನ್ನು", 2),
    ("ವನು", 2),
    ("ಕ್ಕೆ", 2),
    ("ನಿಗೆ", 2),
    ("ರಿಗೆ", 2),
    ("ದಿಂದ", 2),
    ("ಯನ್ನು", 2),
    ("ನ್ನು", 2),
    ("ಲ್ಲಿ", 2),
    ("ಲಿ", 2),
    ("ಗೆ", 2),
    ("ನು", 2),
    ("ವೂ", 3),
    ("ವೇ", 3),
    ("ಯ", 2),
    ("ದ", 2),
]

KANNADA_PROGRESSIVE_ENDINGS = [
    "ುತ್ತಿದ್ದರು",
    "ುತ್ತಿದ್ದ",
    "ುತ್ತಿತ್ತು",
    "ುತ್ತದೆ",
    "ುತ್ತವೆ",
    "ತ್ತಿದ್ದರು",
    "ತ್ತಿದ್ದ",
    "ತ್ತಿತ್ತು",
    "ತ್ತದೆ",
    "ತ್ತವೆ",
]


@dataclass
class LookupResult:
    word: str
    normalized_key: str
    matched_key: str | None
    meaning: str | None
    path: str


def normalize(text: str) -> str:
    return text.strip().lower()


def is_punctuation(char: str) -> bool:
    return unicodedata.category(char).startswith("P")


def strip_edge_punctuation(text: str) -> str:
    if not text:
        return ""

    start = 0
    end = len(text)
    while start < end and is_punctuation(text[start]):
        start += 1
    while end > start and is_punctuation(text[end - 1]):
        end -= 1
    return text[start:end]


def strip_trailing_digits(text: str) -> str:
    value = text
    while value and value[-1].isdigit():
        value = value[:-1]
    return value.strip()


def strip_leading_metadata(text: str) -> str:
    patterns = [
        r"^\s*\([^)]*\)\s*",
        r"^\s*\[[^\]]*\]\s*",
        r"^\s*\d+\.\s*",
    ]
    value = text
    progressed = True
    while progressed and value:
        progressed = False
        for pattern in patterns:
            updated = re.sub(pattern, "", value)
            if updated != value:
                value = updated.strip()
                progressed = True
    return value


def concise_meaning(text: str) -> str:
    value = text.strip()
    if not value:
        return ""

    if value.startswith("="):
        return value

    value = strip_leading_metadata(value)

    split_index = value.lower().find(" - a)")
    if split_index != -1:
        prefix = value[:split_index].strip()
        if prefix:
            value = prefix

    if ";" in value:
        first_clause = value.split(";", 1)[0].strip()
        if first_clause:
            value = first_clause

    if len(value) > 140 and "," in value:
        first_phrase = value.split(",", 1)[0].strip()
        if len(first_phrase) >= 10:
            value = first_phrase

    value = re.sub(r"\s+", " ", value).strip()
    value = value.rstrip(".,;:").strip()
    return value


def build_candidate_keys(normalized_word: str, language_code: str) -> list[str]:
    candidates: list[str] = []

    def append_if_new(value: str, minimum_length: int = 1) -> None:
        if len(value) < minimum_length:
            return
        if value in candidates:
            return
        candidates.append(value)

    stripped = strip_edge_punctuation(normalized_word)
    append_if_new(normalized_word)
    append_if_new(stripped)

    if language_code != "kn":
        return candidates

    for suffix, minimum_stem_length in KANNADA_SUFFIX_RULES:
        if not stripped.endswith(suffix):
            continue
        stem = stripped[: -len(suffix)]
        append_if_new(stem, minimum_stem_length)
        if stem.endswith("ಯ"):
            append_if_new(stem[:-1], minimum_stem_length)

    for ending in KANNADA_PROGRESSIVE_ENDINGS:
        if not stripped.endswith(ending):
            continue
        stem = stripped[: -len(ending)]
        append_if_new(stem, 2)
        append_if_new(stem + "ು", 2)

    return candidates


class DictionaryLookupEngine:
    def __init__(self, sqlite_path: str, source_language: str) -> None:
        self.sqlite_path = sqlite_path
        self.source_language = normalize(source_language) or "kn"
        self.connection = sqlite3.connect(sqlite_path)
        self.connection.row_factory = sqlite3.Row
        self.cache: dict[str, str | None] = {}

    def close(self) -> None:
        self.connection.close()

    def _lookup_raw(self, key: str) -> str | None:
        if key in self.cache:
            return self.cache[key]

        row = self.connection.execute(
            "SELECT meaning FROM entries WHERE key = ? LIMIT 1",
            (key,),
        ).fetchone()
        meaning = (row["meaning"] if row is not None else None)
        self.cache[key] = meaning
        return meaning

    def _resolve_meaning(self, raw_meaning: str, key: str) -> tuple[str | None, str | None]:
        trimmed = raw_meaning.strip()
        if not trimmed:
            return None, None

        if trimmed.startswith("="):
            redirect = strip_trailing_digits(strip_edge_punctuation(trimmed[1:].strip()))
            redirect_key = normalize(redirect)
            if not redirect_key or redirect_key == key:
                return None, None

            redirected_meaning = self._lookup_raw(redirect_key)
            if redirected_meaning is None:
                return None, None

            cleaned = concise_meaning(redirected_meaning)
            if not cleaned or cleaned.lower() == redirect_key:
                return None, None
            return cleaned, "redirect"

        cleaned = concise_meaning(trimmed)
        if not cleaned or cleaned.lower() == key:
            return None, None
        return cleaned, None

    def lookup(self, word: str) -> LookupResult:
        normalized = normalize(word)
        if not normalized:
            return LookupResult(word=word, normalized_key="", matched_key=None, meaning=None, path="none")

        candidates = build_candidate_keys(normalized, self.source_language)
        for candidate in candidates:
            raw = self._lookup_raw(candidate)
            if raw is None:
                continue

            meaning, resolved_path = self._resolve_meaning(raw, candidate)
            if meaning is None:
                continue

            if resolved_path == "redirect":
                path = "redirect"
            elif candidate == normalized:
                path = "direct"
            else:
                path = "suffix"

            return LookupResult(
                word=word,
                normalized_key=normalized,
                matched_key=candidate,
                meaning=meaning,
                path=path,
            )

        return LookupResult(
            word=word,
            normalized_key=normalized,
            matched_key=None,
            meaning=None,
            path="none",
        )


def tokenize_sentences(sentences: list[str]) -> list[str]:
    tokens: list[str] = []
    for sentence in sentences:
        tokens.extend(WORD_PATTERN.findall(sentence))
    return tokens


def evaluate_corpus(engine: DictionaryLookupEngine, corpus_sentences: list[str]) -> dict[str, Any]:
    tokens = tokenize_sentences(corpus_sentences)
    token_total = len(tokens)
    token_hits = 0
    unique_words: set[str] = set()
    unique_hit_words: set[str] = set()
    path_counts: Counter[str] = Counter()
    unresolved_counter: Counter[str] = Counter()

    for token in tokens:
        normalized_token = normalize(token)
        if not normalized_token:
            continue
        unique_words.add(normalized_token)

        result = engine.lookup(token)
        if result.meaning:
            token_hits += 1
            unique_hit_words.add(normalized_token)
            path_counts[result.path] += 1
        else:
            unresolved_counter[normalized_token] += 1

    unique_total = len(unique_words)
    unique_hits = len(unique_hit_words)
    token_coverage = (token_hits / token_total) if token_total else 0.0
    unique_coverage = (unique_hits / unique_total) if unique_total else 0.0

    return {
        "token_total": token_total,
        "token_hits": token_hits,
        "token_coverage": token_coverage,
        "unique_total": unique_total,
        "unique_hits": unique_hits,
        "unique_coverage": unique_coverage,
        "path_counts": dict(path_counts),
        "unresolved_top": unresolved_counter.most_common(25),
    }


def is_meaning_match(actual: str, accepted: list[str], mode: str) -> bool:
    if not accepted:
        return False
    actual_value = actual.strip().lower()
    for expected in accepted:
        candidate = expected.strip().lower()
        if not candidate:
            continue
        if mode == "exact" and actual_value == candidate:
            return True
        if mode != "exact" and candidate in actual_value:
            return True
    return False


def evaluate_gold(engine: DictionaryLookupEngine, gold: list[dict[str, Any]]) -> dict[str, Any]:
    total = len(gold)
    hits = 0
    correct = 0
    missing: list[dict[str, Any]] = []
    mismatches: list[dict[str, Any]] = []
    correct_rows: list[dict[str, Any]] = []

    for row in gold:
        word = str(row.get("word", "")).strip()
        accepted = [str(value) for value in row.get("accepted_meanings", [])]
        mode = str(row.get("match_mode", "contains")).strip().lower() or "contains"
        if not word:
            continue

        result = engine.lookup(word)
        if result.meaning is None:
            missing.append({"word": word, "expected": accepted})
            continue

        hits += 1
        if is_meaning_match(result.meaning, accepted, mode):
            correct += 1
            correct_rows.append({"word": word, "meaning": result.meaning, "path": result.path})
        else:
            mismatches.append(
                {
                    "word": word,
                    "meaning": result.meaning,
                    "path": result.path,
                    "expected": accepted,
                    "match_mode": mode,
                }
            )

    hit_rate = (hits / total) if total else 0.0
    accuracy = (correct / total) if total else 0.0
    return {
        "total": total,
        "hits": hits,
        "hit_rate": hit_rate,
        "correct": correct,
        "accuracy": accuracy,
        "missing": missing,
        "mismatches": mismatches,
        "correct_samples": correct_rows[:25],
    }


def evaluate_thresholds(metrics: dict[str, Any], thresholds: dict[str, Any]) -> dict[str, Any]:
    checks: list[dict[str, Any]] = []

    def add_check(metric_name: str, actual: float, threshold_name: str) -> None:
        if threshold_name not in thresholds:
            return
        expected = float(thresholds[threshold_name])
        checks.append(
            {
                "metric": metric_name,
                "actual": actual,
                "expected_min": expected,
                "passed": actual >= expected,
            }
        )

    add_check("token_coverage", metrics["coverage"]["token_coverage"], "token_coverage_min")
    add_check("unique_coverage", metrics["coverage"]["unique_coverage"], "unique_coverage_min")
    add_check("gold_hit_rate", metrics["gold"]["hit_rate"], "gold_hit_rate_min")
    add_check("gold_accuracy", metrics["gold"]["accuracy"], "gold_accuracy_min")

    passed = all(check["passed"] for check in checks) if checks else True
    return {"passed": passed, "checks": checks}


def evaluate_fixture(
    engine: DictionaryLookupEngine,
    fixture_path: str,
) -> dict[str, Any]:
    with open(fixture_path, "r", encoding="utf-8") as handle:
        fixture = json.load(handle)

    fixture_name = str(fixture.get("name", os.path.basename(fixture_path)))
    corpus_sentences = [str(sentence) for sentence in fixture.get("corpus_sentences", [])]
    gold = list(fixture.get("gold", []))
    thresholds = dict(fixture.get("thresholds", {}))

    coverage = evaluate_corpus(engine, corpus_sentences)
    gold_metrics = evaluate_gold(engine, gold)
    report = {
        "fixture_name": fixture_name,
        "fixture_path": fixture_path,
        "coverage": coverage,
        "gold": gold_metrics,
    }
    report["thresholds"] = evaluate_thresholds(report, thresholds)
    return report


def format_percentage(value: float) -> str:
    return f"{value * 100:.1f}%"


def print_report(report: dict[str, Any]) -> None:
    print(f"\nFixture: {report['fixture_name']}")
    coverage = report["coverage"]
    gold = report["gold"]
    thresholds = report["thresholds"]

    print(
        "  Coverage: tokens "
        f"{format_percentage(coverage['token_coverage'])} ({coverage['token_hits']}/{coverage['token_total']}), "
        f"unique {format_percentage(coverage['unique_coverage'])} ({coverage['unique_hits']}/{coverage['unique_total']})"
    )
    print(
        "  Gold: hit rate "
        f"{format_percentage(gold['hit_rate'])} ({gold['hits']}/{gold['total']}), "
        f"accuracy {format_percentage(gold['accuracy'])} ({gold['correct']}/{gold['total']})"
    )

    unresolved = coverage["unresolved_top"][:8]
    if unresolved:
        unresolved_text = ", ".join(f"{word}({count})" for word, count in unresolved)
        print(f"  Top unresolved: {unresolved_text}")

    if gold["mismatches"]:
        first = gold["mismatches"][0]
        print(
            "  Sample mismatch: "
            f"{first['word']} -> {first['meaning']} (expected one of {first['expected']})"
        )

    if thresholds["checks"]:
        print(f"  Thresholds: {'PASS' if thresholds['passed'] else 'FAIL'}")
        for check in thresholds["checks"]:
            status = "PASS" if check["passed"] else "FAIL"
            print(
                f"    - {status} {check['metric']}: "
                f"{check['actual']:.3f} >= {check['expected_min']:.3f}"
            )


def resolve_fixture_paths(explicit_paths: list[str]) -> list[str]:
    if explicit_paths:
        return explicit_paths

    default_glob = os.path.join("scripts", "eval_fixtures", "*.json")
    return sorted(glob.glob(default_glob))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate dictionary coverage and meaning accuracy.")
    parser.add_argument(
        "--dictionary",
        default=os.path.join("LanguageReader", "Resources", "dictionary.sqlite"),
        help="Path to dictionary sqlite file.",
    )
    parser.add_argument(
        "--source-language",
        default="kn",
        help="Source language code used for lookup heuristics (default: kn).",
    )
    parser.add_argument(
        "--fixture",
        action="append",
        default=[],
        help="Fixture JSON path. Can be passed multiple times. Defaults to scripts/eval_fixtures/*.json",
    )
    parser.add_argument(
        "--report-json",
        help="Optional output path for machine-readable JSON report.",
    )
    parser.add_argument(
        "--no-fail-on-thresholds",
        action="store_true",
        help="Exit 0 even when thresholds fail.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    fixture_paths = resolve_fixture_paths(args.fixture)

    if not os.path.exists(args.dictionary):
        print(f"Dictionary not found at: {args.dictionary}", file=sys.stderr)
        return 2
    if not fixture_paths:
        print("No fixtures found. Add JSON fixtures under scripts/eval_fixtures/.", file=sys.stderr)
        return 2

    engine = DictionaryLookupEngine(args.dictionary, args.source_language)
    try:
        reports = [evaluate_fixture(engine, fixture_path) for fixture_path in fixture_paths]
    finally:
        engine.close()

    overall_passed = all(report["thresholds"]["passed"] for report in reports)
    for report in reports:
        print_report(report)

    overall = {
        "dictionary": os.path.abspath(args.dictionary),
        "source_language": normalize(args.source_language),
        "fixture_count": len(reports),
        "thresholds_passed": overall_passed,
        "reports": reports,
    }

    if args.report_json:
        os.makedirs(os.path.dirname(os.path.abspath(args.report_json)), exist_ok=True)
        with open(args.report_json, "w", encoding="utf-8") as handle:
            json.dump(overall, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        print(f"\nWrote JSON report: {args.report_json}")

    if not args.no_fail_on_thresholds and not overall_passed:
        print("\nDictionary evaluation failed thresholds.", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

