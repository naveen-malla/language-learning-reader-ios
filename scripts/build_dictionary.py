#!/usr/bin/env python3
import os
import sqlite3
import sys
import tempfile
import urllib.request

URL = "https://raw.githubusercontent.com/alar-dict/data/master/alar.yml"
OUTPUT_DIR = os.path.join(os.getcwd(), "data")
OUTPUT_DB = os.path.join(OUTPUT_DIR, "alar.sqlite")

try:
    import yaml  # type: ignore
except Exception:
    print("PyYAML is required. Install with: python3 -m pip install pyyaml", file=sys.stderr)
    sys.exit(1)

def normalize(text: str) -> str:
    return text.strip().lower()

os.makedirs(OUTPUT_DIR, exist_ok=True)

with tempfile.NamedTemporaryFile(delete=False, suffix=".yml") as tmp:
    print("Downloading Alar dataset...")
    with urllib.request.urlopen(URL) as resp:
        tmp.write(resp.read())
    tmp_path = tmp.name

print("Parsing YAML...")
with open(tmp_path, "r", encoding="utf-8") as f:
    data = yaml.safe_load(f)

os.remove(tmp_path)

print("Building SQLite...")
conn = sqlite3.connect(OUTPUT_DB)
cur = conn.cursor()
cur.execute("CREATE TABLE IF NOT EXISTS entries (key TEXT PRIMARY KEY, word TEXT, meaning TEXT)")
cur.execute("CREATE INDEX IF NOT EXISTS idx_entries_word ON entries(word)")

inserted = 0
for item in data:
    word = (item.get("entry") or "").strip()
    if not word:
        continue
    defs = item.get("defs") or []
    meaning = ""
    for d in defs:
        entry = (d.get("entry") or "").strip()
        if entry:
            meaning = entry
            break
    if not meaning:
        continue

    key = normalize(word)
    cur.execute(
        "INSERT OR REPLACE INTO entries (key, word, meaning) VALUES (?, ?, ?)",
        (key, word, meaning),
    )
    inserted += 1

conn.commit()
conn.close()

print(f"Done. Inserted {inserted} entries.")
print(f"Dictionary created at: {OUTPUT_DB}")
