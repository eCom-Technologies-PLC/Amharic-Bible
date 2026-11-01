#!/usr/bin/env python3
"""Build the app's read-only content database from Bible texts and study resources.

Usage:
  python pipeline/build_db.py --sources content/sources --out build/content.db
  python pipeline/build_db.py --sources pipeline/tests/fixtures/usfm \
      --out app/assets/content/content.db --sample --allow-unverified

--sources holds one directory per version or resource ID (e.g. AMH1962/,
WEB/, WLC/, STRONGS/). Versions are registered in content/versions.json
(USFM, or the "oshb" / "rp_csv" original-language formats); study resources
in content/resources.json. Anything marked "bundle": false is written to
<out dir>/packs/<ID>.db instead of the main database (full builds only), so
large scholar resources stay out of the app download.
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

from abible import original, study, usfm  # noqa: E402
from abible.catalog import book_aliases, load_books, load_resources, load_versions, vkey  # noqa: E402
from abible.geez import index_terms  # noqa: E402
from validate import validate_version  # noqa: E402

SCHEMA_VERSION = 2

SCHEMA = """
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE version (
  id TEXT PRIMARY KEY, name TEXT, local_name TEXT, abbrev TEXT, language TEXT,
  canon TEXT, attribution TEXT, license_status TEXT, content_hash TEXT,
  audio_provider TEXT, audio_fileset_id TEXT, audio_allow_download INTEGER,
  coverage TEXT, edition TEXT, license_summary TEXT
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
-- Original-language words, one row per word in printed order.
CREATE TABLE word (
  version_id TEXT, vkey INTEGER, pos INTEGER, text TEXT, strongs TEXT, lemma TEXT, morph TEXT,
  PRIMARY KEY (version_id, vkey, pos)
) WITHOUT ROWID;
CREATE INDEX word_strongs ON word (strongs, vkey);
-- Textual variants: qere readings (WLC) and other editions' readings (RP2018 apparatus).
CREATE TABLE variant (version_id TEXT, vkey INTEGER, source TEXT, base TEXT, reading TEXT);
CREATE INDEX variant_idx ON variant (version_id, vkey);
CREATE TABLE resource (
  id TEXT PRIMARY KEY, kind TEXT, name TEXT, attribution TEXT, license_status TEXT, license_summary TEXT
);
CREATE TABLE lexicon (
  id TEXT PRIMARY KEY, lang TEXT, lemma TEXT, translit TEXT, pron TEXT,
  definition TEXT, derivation TEXT, usage TEXT, resource_id TEXT
);
CREATE TABLE xref (vkey INTEGER, to_start INTEGER, to_end INTEGER, votes INTEGER);
CREATE INDEX xref_idx ON xref (vkey);
CREATE TABLE entity (
  id TEXT PRIMARY KEY, kind TEXT, name TEXT, summary TEXT, start_year INTEGER, end_year INTEGER,
  lat REAL, lon REAL, verse_count INTEGER, resource_id TEXT
);
CREATE TABLE entity_verse (vkey INTEGER, entity_id TEXT, PRIMARY KEY (vkey, entity_id)) WITHOUT ROWID;
CREATE INDEX entity_verse_entity ON entity_verse (entity_id, vkey);
CREATE TABLE dictionary (id TEXT PRIMARY KEY, term TEXT, text TEXT, resource_id TEXT);
CREATE INDEX dictionary_term ON dictionary (term COLLATE NOCASE);
CREATE TABLE commentary (
  resource_id TEXT, vkey_start INTEGER, vkey_end INTEGER, author TEXT, tradition TEXT,
  year INTEGER, work TEXT, url TEXT, text TEXT
);
CREATE INDEX commentary_idx ON commentary (vkey_start, vkey_end);
"""

def read_version_dir(path: Path, reg: dict) -> list:
    fmt = reg.get("format", "usfm")
    if fmt == "oshb":
        vmap_file = path / "VerseMap.xml"
        vmap = original.load_versemap(vmap_file.read_text(encoding="utf-8")) if vmap_file.exists() else {}
        return [original.parse_oshb(f.read_text(encoding="utf-8"), vmap)
                for f in sorted(path.glob("*.xml")) if f.name != "VerseMap.xml"]
    if fmt == "rp_csv":
        return [original.parse_rp(f.stem, f.read_text(encoding="utf-8"),
                                  (path / "text" / f.name).read_text(encoding="utf-8"))
                for f in sorted((path / "parsed").glob("*.csv"))]
    files = sorted(p for p in path.iterdir() if p.suffix.lower() in (".sfm", ".usfm"))
    return [usfm.parse(f.read_text(encoding="utf-8-sig")) for f in files]


def license_ok(rid: str, reg: dict, allow_unverified: bool) -> bool:
    status = reg["license"]["status"]
    if status != "confirmed" and not allow_unverified:
        print(f"[{rid}] license status is '{status}'; refusing to package "
              "(use --allow-unverified for dev builds)", file=sys.stderr)
        return False
    return True


def insert_resource(db: sqlite3.Connection, rid: str, reg: dict) -> None:
    db.execute("INSERT INTO resource VALUES (?,?,?,?,?,?)",
               (rid, reg["kind"], reg["name"], reg["license"]["attribution"],
                reg["license"]["status"], reg["license"]["summary"]))


def build_version(db, vid, reg, vdir, catalog, sample, aliases) -> int:
    """Insert one Bible version; returns the number of validation errors."""
    coverage = reg.get("coverage")  # "OT" / "NT" for texts covering one testament
    books = [b for b in read_version_dir(vdir, reg) if b.code in catalog]
    books.sort(key=lambda b: catalog[b.code].num)
    expected = {c: b for c, b in catalog.items() if not coverage or b.testament == coverage}
    report = validate_version(vid, books, expected, complete=not sample)
    for w in report.warnings:
        print(f"[{vid}] warning: {w}")
    for e in report.errors:
        print(f"[{vid}] ERROR: {e}", file=sys.stderr)

    h = hashlib.sha256()
    words = variants = 0
    lang = reg["language"]
    for ordinal, b in enumerate(books, 1):
        info = catalog[b.code]
        if lang == "amh":
            abbrev = info.abbrev
        elif lang == "eng" or not b.abbrev:
            abbrev = info.en_abbrevs[0].title()
        else:
            abbrev = b.abbrev  # other languages: the source's own \toc3 abbreviation
        db.execute(
            "INSERT INTO book VALUES (?,?,?,?,?,?,?,?,?)",
            (vid, b.code, info.num, ordinal,
             info.name if lang == "amh" else (b.long_title or info.en),
             info.short if lang == "amh" else (b.title or info.en),
             abbrev, info.testament, max(b.chapters_seen, default=0)),
        )
        for a in book_aliases(info, tuple(x for x in (b.title, b.abbrev) if x)):
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
        if isinstance(b, original.OriginalBook):
            for (ch, vs), ws in b.words.items():
                k = vkey(info.num, ch, vs)
                db.executemany("INSERT INTO word VALUES (?,?,?,?,?,?,?)",
                               [(vid, k, i, w.text, w.strongs, w.lemma, w.morph) for i, w in enumerate(ws)])
                words += len(ws)
            for var in b.variants:
                db.execute("INSERT INTO variant VALUES (?,?,?,?,?)",
                           (vid, vkey(info.num, var.chapter, var.verse), var.source, var.base, var.reading))
                variants += 1

    audio = reg.get("audio") or {}
    db.execute(
        "INSERT INTO version VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (vid, reg["name"], reg["local_name"], reg["abbrev"], lang, reg["canon"],
         reg["license"]["attribution"], reg["license"]["status"], h.hexdigest(),
         audio.get("provider"), audio.get("fileset_id"), int(bool(audio.get("allow_download"))),
         coverage, reg.get("edition"), reg["license"]["summary"]),
    )
    extra = f", {words} words, {variants} variants" if words else ""
    print(f"[{vid}] {len(books)} books, {sum(len(b.verses) for b in books)} verses{extra}")
    return len(report.errors)


def build_resource(db, rid, reg, rdir, catalog) -> int:
    """Insert one study resource; returns the number of validation errors."""
    kind, opts = reg["kind"], reg.get("options", {})
    insert_resource(db, rid, reg)
    if kind == "lexicon":
        rows = []
        for f in sorted(rdir.glob("*.js")):
            rows += study.load_strongs(f.read_text(encoding="utf-8"))
        db.executemany("INSERT OR REPLACE INTO lexicon VALUES (?,?,?,?,?,?,?,?,?)",
                       [(e.id, e.lang, e.lemma, e.translit, e.pron, e.definition, e.derivation, e.usage, rid)
                        for e in rows])
        print(f"[{rid}] {len(rows)} lexicon entries")
    elif kind == "crossrefs":
        rows = []
        for f in sorted(rdir.glob("*.txt")):
            rows += study.load_openbible_xrefs(f.read_text(encoding="utf-8"), catalog, opts.get("min_votes", 1))
        db.executemany("INSERT INTO xref VALUES (?,?,?,?)", rows)
        print(f"[{rid}] {len(rows)} cross-references")
    elif kind == "entities":
        ents = study.load_theographic(rdir, catalog)
        for e in ents:
            db.execute("INSERT INTO entity VALUES (?,?,?,?,?,?,?,?,?,?)",
                       (e.id, e.kind, e.name, e.summary, e.start_year, e.end_year, e.lat, e.lon, len(e.vkeys), rid))
            db.executemany("INSERT OR IGNORE INTO entity_verse VALUES (?,?)", [(k, e.id) for k in e.vkeys])
        terms = study.load_easton(rdir) if (rdir / "easton.json").exists() else []
        db.executemany("INSERT OR REPLACE INTO dictionary VALUES (?,?,?,?)", [(*t, rid) for t in terms])
        print(f"[{rid}] {len(ents)} people, places and events; {len(terms)} dictionary entries")
    elif kind == "commentary":
        rows = study.load_hcf(rdir, catalog, opts.get("max_year", 9999), set(opts.get("exclude_traditions", [])))
        db.executemany("INSERT INTO commentary VALUES (?,?,?,?,?,?,?,?,?)",
                       [(rid, c.vkey_start, c.vkey_end, c.author, c.tradition, c.year, c.work, c.url, c.text)
                        for c in rows])
        print(f"[{rid}] {len(rows)} commentary entries")
    else:
        print(f"[{rid}] unknown resource kind {kind}", file=sys.stderr)
        return 1
    return 0


def check_study_links(conns: list[sqlite3.Connection]) -> list[str]:
    """Warnings for words whose Strong's number has no lexicon entry (across the database and its packs)."""
    lex = {r[0] for c in conns for r in c.execute("SELECT id FROM lexicon")}
    used = {r[0] for c in conns for r in c.execute("SELECT DISTINCT strongs FROM word WHERE strongs IS NOT NULL")}
    if not lex or not used:
        return []
    missing = sorted(used - lex)
    return [f"{len(missing)} Strong's numbers used in texts have no lexicon entry: {' '.join(missing[:10])}"] if missing else []


def finish(db: sqlite3.Connection, meta: dict) -> None:
    db.executemany("INSERT INTO meta VALUES (?,?)", meta.items())
    db.commit()
    db.execute("VACUUM")
    db.close()


def build(sources: Path, out: Path, sample: bool, allow_unverified: bool,
          only: list[str] | None = None) -> int:
    catalog = load_books()
    versions = load_versions()
    resources = load_resources()
    dirs = sorted(p for p in sources.iterdir() if p.is_dir())
    if only:
        dirs = [p for p in dirs if p.name in only]
    if not dirs:
        print(f"no version directories under {sources}", file=sys.stderr)
        return 1

    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists():
        out.unlink()
    db = sqlite3.connect(out)
    db.executescript(SCHEMA)
    errors = 0
    aliases: dict[str, set[str]] = {}
    packs: list[tuple[Path, sqlite3.Connection, str]] = []
    meta = {
        "schema_version": str(SCHEMA_VERSION),
        "built_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "is_sample": "1" if sample else "0",
    }

    def target(rid: str, reg: dict) -> sqlite3.Connection:
        """The main database, or a pack for content that isn't bundled with the app.

        Packs have the full schema, so the app can query them like content.db.
        Sample builds put everything in the main database.
        """
        if reg.get("bundle", True) or sample:
            return db
        pack = out.parent / "packs" / f"{rid}.db"
        pack.parent.mkdir(parents=True, exist_ok=True)
        pack.unlink(missing_ok=True)
        pdb = sqlite3.connect(pack)
        pdb.executescript(SCHEMA)
        packs.append((pack, pdb, rid))
        return pdb

    # Versions first, so resource checks can see the words they link to.
    for d in sorted(dirs, key=lambda p: p.name in resources):
        rid = d.name
        reg = versions.get(rid) or resources.get(rid)
        if reg is None:
            print(f"[{rid}] not registered in content/versions.json or content/resources.json", file=sys.stderr)
            errors += 1
        elif not license_ok(rid, reg, allow_unverified):
            errors += 1
        elif rid in versions:
            errors += build_version(target(rid, reg), rid, reg, d, catalog, sample, aliases)
        else:
            errors += build_resource(target(rid, reg), rid, reg, d, catalog)

    for w in check_study_links([db, *(pdb for _, pdb, _ in packs)]):
        print(f"warning: {w}")
    for alias, codes in aliases.items():
        for code in codes:
            db.execute("INSERT INTO book_alias VALUES (?,?)", (alias, code))
    db.execute("INSERT INTO verse_fts(verse_fts) VALUES ('optimize')")
    finish(db, meta)
    for pack, pdb, rid in packs:
        pdb.execute("INSERT INTO verse_fts(verse_fts) VALUES ('optimize')")
        finish(pdb, {**meta, "pack": rid})

    if errors:
        print(f"{errors} error(s); output removed", file=sys.stderr)
        out.unlink(missing_ok=True)
        for pack, _, _ in packs:
            pack.unlink(missing_ok=True)
        return 1
    print(f"wrote {out} ({out.stat().st_size // 1024} KiB)")
    for pack, _, _ in packs:
        print(f"wrote {pack} ({pack.stat().st_size // 1024} KiB)")
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sources", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--sample", action="store_true",
                    help="partial sample content: skip completeness checks, mark DB as sample")
    ap.add_argument("--allow-unverified", action="store_true",
                    help="package versions whose license is not yet confirmed (dev only)")
    ap.add_argument("--only", nargs="*", help="limit to these version or resource IDs")
    a = ap.parse_args(argv)
    return build(a.sources, a.out, a.sample, a.allow_unverified, a.only)


if __name__ == "__main__":
    sys.exit(main())
