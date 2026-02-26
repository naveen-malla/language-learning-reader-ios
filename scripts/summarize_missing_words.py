#!/usr/bin/env python3
"""Summarize dictionary_missing.tsv by normalized-word frequency."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import Counter
from dataclasses import dataclass


@dataclass(frozen=True)
class MissingRow:
    word: str
    timestamp: str | None


def normalize_word(value: str) -> str:
    trimmed = value.strip().lower()
    if not trimmed:
        return ""
    return re.sub(r"\s+", " ", trimmed)


def has_letter(value: str) -> bool:
    return any(character.isalpha() for character in value)


def parse_missing_tsv(path: str) -> list[MissingRow]:
    rows: list[MissingRow] = []
    with open(path, "r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.rstrip("\r\n")
            trimmed = line.strip()
            if not trimmed or trimmed.startswith("#"):
                continue

            parts = line.split("\t")
            word = normalize_word(parts[0] if parts else "")
            if not word or not has_letter(word):
                continue

            timestamp = parts[1].strip() if len(parts) > 1 and parts[1].strip() else None
            rows.append(MissingRow(word=word, timestamp=timestamp))

    return rows


def summarize_rows(rows: list[MissingRow], top: int) -> dict[str, object]:
    counter = Counter(row.word for row in rows)
    ranked = sorted(counter.items(), key=lambda item: (-item[1], item[0]))
    top_rows = [{"word": word, "count": count} for word, count in ranked[:top]]

    return {
        "total_entries": len(rows),
        "unique_words": len(counter),
        "top_missing": top_rows,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Summarize dictionary_missing.tsv frequency.")
    parser.add_argument(
        "--input",
        default=os.path.join("Documents", "dictionary_missing.tsv"),
        help="Path to missing TSV file (default: Documents/dictionary_missing.tsv)",
    )
    parser.add_argument(
        "--top",
        type=int,
        default=20,
        help="Number of top words to display (default: 20)",
    )
    parser.add_argument(
        "--json",
        dest="json_output",
        help="Optional path to write JSON summary.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.top <= 0:
        print("--top must be greater than 0", file=sys.stderr)
        return 2

    if not os.path.exists(args.input):
        print(f"Missing TSV not found at: {args.input}", file=sys.stderr)
        return 2

    rows = parse_missing_tsv(args.input)
    summary = summarize_rows(rows, top=args.top)

    print(f"File: {os.path.abspath(args.input)}")
    print(f"Total missing entries: {summary['total_entries']}")
    print(f"Unique missing words: {summary['unique_words']}")

    top_missing = summary["top_missing"]
    if top_missing:
        print("Top missing words:")
        for row in top_missing:
            print(f"  - {row['word']} ({row['count']})")
    else:
        print("Top missing words: none")

    if args.json_output:
        output_path = os.path.abspath(args.json_output)
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as handle:
            json.dump(summary, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        print(f"Wrote JSON summary: {output_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
