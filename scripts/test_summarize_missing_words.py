#!/usr/bin/env python3

import json
import os
import tempfile
import unittest

import summarize_missing_words as summary


class SummarizeMissingWordsTests(unittest.TestCase):
    def test_parse_missing_tsv_ignores_comments_empty_and_bad_rows(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            path = os.path.join(tempdir, "dictionary_missing.tsv")
            with open(path, "w", encoding="utf-8") as handle:
                handle.write("# comment\n")
                handle.write("\n")
                handle.write("ಮನೆಯಲಿ\t2026-02-20T10:00:00Z\n")
                handle.write("  ಮನೆಯಲಿ  \t2026-02-20T11:00:00Z\n")
                handle.write("ಹೊಸದು\n")
                handle.write("\t2026-02-20T12:00:00Z\n")

            rows = summary.parse_missing_tsv(path)

            self.assertEqual(len(rows), 3)
            self.assertEqual(rows[0].word, "ಮನೆಯಲಿ")
            self.assertEqual(rows[1].word, "ಮನೆಯಲಿ")
            self.assertEqual(rows[2].word, "ಹೊಸದು")

    def test_summarize_rows_orders_by_frequency_then_word(self) -> None:
        rows = [
            summary.MissingRow(word="beta", timestamp=None),
            summary.MissingRow(word="alpha", timestamp=None),
            summary.MissingRow(word="beta", timestamp=None),
            summary.MissingRow(word="gamma", timestamp=None),
            summary.MissingRow(word="alpha", timestamp=None),
            summary.MissingRow(word="alpha", timestamp=None),
        ]

        result = summary.summarize_rows(rows, top=2)

        self.assertEqual(result["total_entries"], 6)
        self.assertEqual(result["unique_words"], 3)
        self.assertEqual(
            result["top_missing"],
            [
                {"word": "alpha", "count": 3},
                {"word": "beta", "count": 2},
            ],
        )

    def test_cli_writes_json_summary(self) -> None:
        with tempfile.TemporaryDirectory() as tempdir:
            input_path = os.path.join(tempdir, "dictionary_missing.tsv")
            output_path = os.path.join(tempdir, "summary.json")
            with open(input_path, "w", encoding="utf-8") as handle:
                handle.write("ಮನೆಯಲಿ\t2026-02-20T10:00:00Z\n")
                handle.write("ಮನೆಯಲಿ\t2026-02-20T10:00:01Z\n")
                handle.write("ಹೊಸದು\t2026-02-20T10:00:02Z\n")

            code = os.system(
                f"python3 scripts/summarize_missing_words.py --input '{input_path}' --top 3 --json '{output_path}' >/dev/null"
            )
            self.assertEqual(code, 0)

            with open(output_path, "r", encoding="utf-8") as handle:
                report = json.load(handle)

            self.assertEqual(report["total_entries"], 3)
            self.assertEqual(report["unique_words"], 2)
            self.assertEqual(report["top_missing"][0], {"word": "ಮನೆಯಲಿ", "count": 2})


if __name__ == "__main__":
    unittest.main()
