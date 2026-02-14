#!/usr/bin/env python3

import os
import sqlite3
import tempfile
import unittest

import evaluate_dictionary as evaluator


class EvaluateDictionaryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.sqlite_path = os.path.join(self.tempdir.name, "dictionary.sqlite")
        connection = sqlite3.connect(self.sqlite_path)
        connection.execute(
            "CREATE TABLE entries (key TEXT PRIMARY KEY, word TEXT, meaning TEXT)"
        )
        connection.commit()
        connection.close()

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def _insert(self, key: str, word: str, meaning: str) -> None:
        connection = sqlite3.connect(self.sqlite_path)
        connection.execute(
            "INSERT OR REPLACE INTO entries (key, word, meaning) VALUES (?, ?, ?)",
            (key, word, meaning),
        )
        connection.commit()
        connection.close()

    def test_suffix_lookup_for_kannada_profile(self) -> None:
        self._insert("ಮನೆ", "ಮನೆ", "house")
        engine = evaluator.DictionaryLookupEngine(self.sqlite_path, "kn")
        try:
            result = engine.lookup("ಮನೆಯಲಿ")
        finally:
            engine.close()

        self.assertEqual(result.path, "suffix")
        self.assertEqual(result.matched_key, "ಮನೆ")
        self.assertEqual(result.meaning, "house")

    def test_redirect_lookup_resolves_one_hop(self) -> None:
        self._insert("ತುಂಬಾ", "ತುಂಬಾ", "= ತುಂಬ2.")
        self._insert("ತುಂಬ", "ತುಂಬ", "very")
        engine = evaluator.DictionaryLookupEngine(self.sqlite_path, "kn")
        try:
            result = engine.lookup("ತುಂಬಾ")
        finally:
            engine.close()

        self.assertEqual(result.path, "redirect")
        self.assertEqual(result.meaning, "very")

    def test_gold_accuracy_and_thresholds(self) -> None:
        self._insert("hello", "hello", "greeting; salutation")
        self._insert("world", "world", "earth")
        engine = evaluator.DictionaryLookupEngine(self.sqlite_path, "en")
        try:
            coverage = evaluator.evaluate_corpus(
                engine,
                corpus_sentences=["hello world hello unknown"],
            )
            gold = evaluator.evaluate_gold(
                engine,
                gold=[
                    {"word": "hello", "accepted_meanings": ["greeting"]},
                    {"word": "world", "accepted_meanings": ["earth"]},
                    {"word": "unknown", "accepted_meanings": ["missing"]},
                ],
            )
        finally:
            engine.close()

        metrics = {"coverage": coverage, "gold": gold}
        thresholds = evaluator.evaluate_thresholds(
            metrics,
            {
                "token_coverage_min": 0.7,
                "unique_coverage_min": 0.6,
                "gold_hit_rate_min": 0.6,
                "gold_accuracy_min": 0.6,
            },
        )

        self.assertAlmostEqual(coverage["token_coverage"], 0.75, places=3)
        self.assertAlmostEqual(coverage["unique_coverage"], 2 / 3, places=3)
        self.assertAlmostEqual(gold["hit_rate"], 2 / 3, places=3)
        self.assertAlmostEqual(gold["accuracy"], 2 / 3, places=3)
        self.assertTrue(thresholds["passed"])


if __name__ == "__main__":
    unittest.main()

