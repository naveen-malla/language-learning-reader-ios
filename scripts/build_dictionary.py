#!/usr/bin/env python3
import os
import re
import sqlite3
import sys
import tempfile
import urllib.request

URL = "https://raw.githubusercontent.com/alar-dict/data/master/alar.yml"
OUTPUT_DIR = os.path.join(os.getcwd(), "LanguageReader", "Resources")
OUTPUT_DB = os.path.join(OUTPUT_DIR, "dictionary.sqlite")

try:
    import yaml  # type: ignore
except Exception:
    print("PyYAML is required. Install with: python3 -m pip install pyyaml", file=sys.stderr)
    sys.exit(1)

def normalize(text: str) -> str:
    return text.strip().lower()


def strip_leading_metadata(text: str) -> str:
    patterns = [
        r"^\s*\([^)]*\)\s*",
        r"^\s*\[[^\]]*\]\s*",
        r"^\s*\d+\.\s*",
    ]
    value = text.strip()
    changed = True
    while changed and value:
        changed = False
        for pattern in patterns:
            updated = re.sub(pattern, "", value)
            if updated != value:
                value = updated.strip()
                changed = True
    return value


def clean_meaning(text: str) -> str:
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


def extract_primary_meaning(defs) -> str:
    for definition in defs:
        raw = (definition.get("entry") or "").strip()
        if not raw:
            continue
        cleaned = clean_meaning(raw)
        if cleaned:
            return cleaned
    return ""


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
    meaning = extract_primary_meaning(defs)
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
