#!/usr/bin/env python3
"""Build the app's read-only content database from USFM sources.

Usage:
  python pipeline/build_db.py --sources content/sources --out build/content.db
  python pipeline/build_db.py --sources pipeline/tests/fixtures/usfm \
      --out app/assets/content/content.db --sample --allow-unverified

--sources holds one directory per version ID (e.g. AMH1962/, WEB/) with
.SFM/.usfm files. Versions must be registered in content/versions.json.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from abible import usfm  # noqa: E402
from abible.catalog import book_aliases, load_books, load_versions, vkey  # noqa: E402
from abible.geez import index_terms  # noqa: E402
from validate import validate_version  # noqa: E402

SCHEMA_VERSION = 1

SCHEMA = """
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE version (
  id TEXT PRIMARY KEY, name TEXT, local_name TEXT, abbrev TEXT, language TEXT,
  canon TEXT, attribution TEXT, license_status TEXT, content_hash TEXT,
  audio_provider TEXT, audio_fileset_id TEXT, audio_allow_download INTEGER
);
CREATE TABLE book (
  version_id TEXT, code TEXT, num INTEGER, ordinal INTEGER, name TEXT,
  short_name TEXT, abbrev TEXT, testament TEXT, chapter_count INTEGER,
  PRIMARY KEY (version_id, code)
);
CREATE TABLE verse (
  version_id TEXT, vkey INTEGER, label TEXT, text TEXT, markup TEXT,
  PRIMARY KEY (version_id, vkey)
) WITHOUT ROWID;
CREATE TABLE heading (version_id TEXT, vkey INTEGER, level INTEGER, text TEXT);
CREATE INDEX heading_idx ON heading (version_id, vkey);
CREATE TABLE crossref (version_id TEXT, vkey INTEGER, text TEXT);
CREATE INDEX crossref_idx ON crossref (version_id, vkey);
CREATE TABLE book_alias (alias TEXT, code TEXT, PRIMARY KEY (alias, code)) WITHOUT ROWID;
CREATE VIRTUAL TABLE verse_fts USING fts5(
  norm_text, version_id UNINDEXED, vkey UNINDEXED,
  tokenize = 'unicode61 remove_diacritics 0'
);
"""


def read_version_dir(path: Path) -> list[usfm.Book]:
    files = sorted(p for p in path.iterdir() if p.suffix.lower() in (".sfm", ".usfm"))
    books = []
    for f in files:
        b = usfm.parse(f.read_text(encoding="utf-8-sig"))
        books.append(b)
    return books


def build(sources: Path, out: Path, sample: bool, allow_unverified: bool,
          only: list[str] | None = None) -> int:
    catalog = load_books()
    registry = load_versions()
    version_dirs = sorted(p for p in sources.iterdir() if p.is_dir())
    if only:
        version_dirs = [p for p in version_dirs if p.name in only]
    if not version_dirs:
        print(f"no version directories under {sources}", file=sys.stderr)
        return 1

    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists():
        out.unlink()
    db = sqlite3.connect(out)
    db.executescript(SCHEMA)
    errors = 0
    aliases: dict[str, set[str]] = {}

    for vdir in version_dirs:
        vid = vdir.name
        reg = registry.get(vid)
        if reg is None:
            print(f"[{vid}] not registered in content/versions.json", file=sys.stderr)
            errors += 1
            continue
        status = reg["license"]["status"]
        if status != "confirmed" and not allow_unverified:
            print(f"[{vid}] license status is '{status}'; refusing to package "
                  "(use --allow-unverified for dev builds)", file=sys.stderr)
            errors += 1
            continue

        books = [b for b in read_version_dir(vdir) if b.code in catalog]
        books.sort(key=lambda b: catalog[b.code].num)
        report = validate_version(vid, books, catalog, complete=not sample)
        for w in report.warnings:
            print(f"[{vid}] warning: {w}")
        for e in report.errors:
            print(f"[{vid}] ERROR: {e}", file=sys.stderr)
        errors += len(report.errors)

        h = hashlib.sha256()
        for ordinal, b in enumerate(books, 1):
            info = catalog[b.code]
            db.execute(
                "INSERT INTO book VALUES (?,?,?,?,?,?,?,?,?)",
                (vid, b.code, info.num, ordinal,
                 info.name if reg["language"] == "amh" else (b.long_title or info.en),
                 info.short if reg["language"] == "amh" else (b.title or info.en),
                 info.abbrev if reg["language"] == "amh" else info.en_abbrevs[0].title(),
                 info.testament, max(b.chapters_seen, default=0)),
            )
            for a in book_aliases(info, tuple(x for x in (b.title,) if x)):
                aliases.setdefault(a, set()).add(b.code)
            for v in b.verses:
                k = vkey(info.num, v.chapter, v.verse)
                text = v.text
                markup = json.dumps(v.markup, ensure_ascii=False, separators=(",", ":"))
                h.update(f"{k}\t{text}\n".encode())
                db.execute("INSERT INTO verse VALUES (?,?,?,?,?)", (vid, k, v.label, text, markup))
                db.execute("INSERT INTO verse_fts (norm_text, version_id, vkey) VALUES (?,?,?)",
                           (index_terms(text), vid, k))
            for hd in b.headings:
                db.execute("INSERT INTO heading VALUES (?,?,?,?)",
                           (vid, vkey(info.num, hd.chapter, hd.verse), hd.level, hd.text))
            for x in b.crossrefs:
                db.execute("INSERT INTO crossref VALUES (?,?,?)",
                           (vid, vkey(info.num, x.chapter, x.verse), x.text))

        audio = reg.get("audio") or {}
        db.execute(
            "INSERT INTO version VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
            (vid, reg["name"], reg["local_name"], reg["abbrev"], reg["language"], reg["canon"],
             reg["license"]["attribution"], status, h.hexdigest(),
             audio.get("provider"), audio.get("fileset_id"), int(bool(audio.get("allow_download")))),
        )
        print(f"[{vid}] {len(books)} books, "
              f"{sum(len(b.verses) for b in books)} verses")

    for alias, codes in aliases.items():
        for code in codes:
            db.execute("INSERT INTO book_alias VALUES (?,?)", (alias, code))
    meta = {
        "schema_version": str(SCHEMA_VERSION),
        "built_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "is_sample": "1" if sample else "0",
    }
    db.executemany("INSERT INTO meta VALUES (?,?)", meta.items())
    db.execute("INSERT INTO verse_fts(verse_fts) VALUES ('optimize')")
    db.commit()
    db.execute("VACUUM")
    db.close()

    if errors:
        print(f"{errors} error(s); output removed", file=sys.stderr)
        out.unlink(missing_ok=True)
        return 1
    print(f"wrote {out} ({out.stat().st_size // 1024} KiB)")
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sources", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--sample", action="store_true",
                    help="partial sample content: skip completeness checks, mark DB as sample")
    ap.add_argument("--allow-unverified", action="store_true",
                    help="package versions whose license is not yet confirmed (dev only)")
    ap.add_argument("--only", nargs="*", help="limit to these version IDs")
    a = ap.parse_args(argv)
    return build(a.sources, a.out, a.sample, a.allow_unverified, a.only)


if __name__ == "__main__":
    sys.exit(main())
