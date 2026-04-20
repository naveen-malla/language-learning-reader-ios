#!/usr/bin/env python3
import argparse
import html
import os
import re
import sqlite3
import sys
import tarfile
import tempfile
import urllib.request
from xml.etree import ElementTree as ET

KANADA_URL = "https://raw.githubusercontent.com/alar-dict/data/master/alar.yml"
GERMAN_URL = "https://download.freedict.org/dictionaries/deu-eng/1.9-fd1/freedict-deu-eng-1.9-fd1.src.tar.xz"
OUTPUT_DIR = os.path.join(os.getcwd(), "LanguageReader", "Resources")
KANNADA_OUTPUT_DB = os.path.join(OUTPUT_DIR, "dictionary.sqlite")
GERMAN_OUTPUT_DB = os.path.join(OUTPUT_DIR, "dictionary_de.sqlite")

TEI_NS = "{http://www.tei-c.org/ns/1.0}"
XML_LANG = "{http://www.w3.org/XML/1998/namespace}lang"

try:
    import yaml  # type: ignore
except Exception:
    print("PyYAML is required. Install with: python3 -m pip install pyyaml", file=sys.stderr)
    sys.exit(1)


def normalize(text: str) -> str:
    value = html.unescape(text)
    value = re.sub(r"\s+", " ", value).strip()
    return value.casefold()


def clean_headword(text: str) -> str:
    value = html.unescape(text)
    value = re.sub(r"\s+", " ", value).strip()
    return value


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
    value = html.unescape(text).strip()
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


def extract_primary_kannada_meaning(definitions: list[dict]) -> str:
    for definition in definitions:
        raw = (definition.get("entry") or "").strip()
        if not raw:
            continue
        cleaned = clean_meaning(raw)
        if cleaned:
            return cleaned
    return ""


def prepare_database(output_path: str) -> tuple[sqlite3.Connection, sqlite3.Cursor]:
    if os.path.exists(output_path):
        os.remove(output_path)

    conn = sqlite3.connect(output_path)
    cur = conn.cursor()
    cur.execute("PRAGMA journal_mode = WAL")
    cur.execute("PRAGMA synchronous = NORMAL")
    cur.execute("CREATE TABLE entries (key TEXT PRIMARY KEY, word TEXT, meaning TEXT)")
    cur.execute("CREATE INDEX idx_entries_word ON entries(word)")
    return conn, cur


def download_to_tempfile(url: str, suffix: str) -> str:
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        print(f"Downloading {url} ...")
        with urllib.request.urlopen(url) as response:
            tmp.write(response.read())
        return tmp.name


def build_kannada(output_path: str) -> None:
    temp_path = download_to_tempfile(KANADA_URL, ".yml")
    try:
        print("Parsing Kannada YAML...")
        with open(temp_path, "r", encoding="utf-8") as handle:
            data = yaml.safe_load(handle)

        conn, cur = prepare_database(output_path)
        inserted = 0

        for item in data:
            word = (item.get("entry") or "").strip()
            if not word:
                continue

            meaning = extract_primary_kannada_meaning(item.get("defs") or [])
            if not meaning:
                continue

            key = normalize(word)
            cur.execute(
                "INSERT OR REPLACE INTO entries (key, word, meaning) VALUES (?, ?, ?)",
                (key, clean_headword(word), meaning),
            )
            inserted += 1

        conn.commit()
        conn.close()
        print(f"Built Kannada dictionary with {inserted} entries -> {output_path}")
    finally:
        os.remove(temp_path)


def german_translations(entry: ET.Element) -> list[str]:
    values: list[str] = []
    seen: set[str] = set()

    for quote in entry.findall(f".//{TEI_NS}cit[@type='trans']/{TEI_NS}quote"):
        language = quote.attrib.get(XML_LANG, "")
        if language and not language.startswith("en"):
            continue

        text = clean_meaning("".join(quote.itertext()))
        if not text:
            continue
        if text in seen:
            continue

        seen.add(text)
        values.append(text)
        if len(values) == 3:
            break

    return values


def german_headwords(entry: ET.Element) -> list[str]:
    values: list[str] = []
    seen: set[str] = set()

    for orth in entry.findall(f"./{TEI_NS}form/{TEI_NS}orth"):
        text = clean_headword("".join(orth.itertext()))
        if not text:
            continue

        normalized = normalize(text)
        if not normalized or normalized in seen:
            continue

        seen.add(normalized)
        values.append(text)

    return values


def iter_freedict_entries(handle):
    context = ET.iterparse(handle, events=("start", "end"))
    _, root = next(context)

    for event, element in context:
        if event == "end" and element.tag == f"{TEI_NS}entry":
            yield element
            root.clear()


def build_german(output_path: str) -> None:
    temp_path = download_to_tempfile(GERMAN_URL, ".tar.xz")
    try:
        with tarfile.open(temp_path, "r:xz") as archive:
            tei_member = next((member for member in archive.getmembers() if member.name.endswith(".tei")), None)
            if tei_member is None:
                raise RuntimeError("Could not find a TEI file in the German FreeDict archive.")

            handle = archive.extractfile(tei_member)
            if handle is None:
                raise RuntimeError("Could not extract the German TEI file from the FreeDict archive.")

            conn, cur = prepare_database(output_path)
            inserted = 0
            seen_keys: set[str] = set()

            print("Parsing German TEI...")
            for entry in iter_freedict_entries(handle):
                headwords = german_headwords(entry)
                if not headwords:
                    continue

                translations = german_translations(entry)
                if not translations:
                    continue

                meaning = "; ".join(translations)
                primary_word = headwords[0]
                for headword in headwords:
                    key = normalize(headword)
                    if not key or key in seen_keys:
                        continue

                    cur.execute(
                        "INSERT OR REPLACE INTO entries (key, word, meaning) VALUES (?, ?, ?)",
                        (key, primary_word, meaning),
                    )
                    seen_keys.add(key)
                    inserted += 1

            conn.commit()
            conn.close()
            print(f"Built German dictionary with {inserted} entries -> {output_path}")
    finally:
        os.remove(temp_path)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build bundled SQLite dictionaries.")
    parser.add_argument(
        "--language",
        choices=["all", "kn", "de"],
        default="all",
        help="Dictionary language to build (default: all).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    try:
        if args.language in {"all", "kn"}:
            build_kannada(KANNADA_OUTPUT_DB)
        if args.language in {"all", "de"}:
            build_german(GERMAN_OUTPUT_DB)
    except Exception as error:
        print(f"Dictionary build failed: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
