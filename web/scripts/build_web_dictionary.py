#!/usr/bin/env python3
"""Split the iOS app's SQLite dictionary into 256 JSON shards for the web app.

Why shards: the full German dictionary is 47 MB. A phone should not download that to look up
one word. Each shard is ~60 KB raw (~20 KB gzipped by the CDN), the browser fetches only the
shards its words hash to, and the service worker keeps them for offline use.

Usage (from web/):
    python3 scripts/build_web_dictionary.py                 # German, default paths
    python3 scripts/build_web_dictionary.py --lang kn --sqlite ../LanguageReader/Resources/dictionary.sqlite
"""
import argparse
import json
import sqlite3
from pathlib import Path

SHARD_COUNT = 256  # must match SHARD_COUNT in src/lib/dictionary.ts


def fnv1a(key: str) -> int:
    """FNV-1a over UTF-8 bytes; must match shardFor() in src/lib/dictionary.ts."""
    h = 0x811C9DC5
    for b in key.encode("utf-8"):
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h


def main() -> None:
    here = Path(__file__).resolve().parent.parent
    p = argparse.ArgumentParser()
    p.add_argument("--lang", default="de")
    p.add_argument("--sqlite", default=str(here.parent / "LanguageReader/Resources/dictionary_de.sqlite"))
    p.add_argument("--out", default=None)
    args = p.parse_args()

    src = Path(args.sqlite)
    if not src.exists():
        raise SystemExit(f"Dictionary not found: {src}\nBuild it first with ../scripts/build_dictionary.py")

    out_dir = Path(args.out) if args.out else here / "public" / "dict" / args.lang
    out_dir.mkdir(parents=True, exist_ok=True)

    shards: list[dict[str, str]] = [{} for _ in range(SHARD_COUNT)]
    conn = sqlite3.connect(f"file:{src}?mode=ro", uri=True)
    rows = 0
    for key, meaning in conn.execute("SELECT key, meaning FROM entries"):
        if not key or not meaning:
            continue
        shards[fnv1a(key) % SHARD_COUNT][key] = meaning
        rows += 1
    conn.close()

    total = 0
    for i, shard in enumerate(shards):
        data = json.dumps(shard, ensure_ascii=False, separators=(",", ":"))
        (out_dir / f"{i}.json").write_text(data, encoding="utf-8")
        total += len(data.encode("utf-8"))

    print(f"{rows} entries -> {SHARD_COUNT} shards in {out_dir} ({total / 1e6:.1f} MB raw)")


if __name__ == "__main__":
    main()
