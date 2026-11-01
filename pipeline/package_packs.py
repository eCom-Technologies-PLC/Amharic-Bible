#!/usr/bin/env python3
"""Compress study packs for download and write the manifest the app reads.

Usage: python pipeline/package_packs.py --packs build/packs [--out build/packs]

For every <ID>.db written by build_db.py this writes <ID>.db.gz and adds an
entry to manifest.json:

  {"format": 1, "schema_version": 2, "built_at": "...",
   "packs": [{"id": "WLC", "kind": "version", "name": "...", "language": "heb",
              "file": "WLC.db.gz", "bytes": 40480768, "gz_bytes": 13021337,
              "sha256": "<of the .gz>", "attribution": "...", "license_status": "confirmed"}]}

Upload the .gz files and manifest.json to one folder on a static host that
supports HTTP range requests (so interrupted downloads resume), and build the
app with --dart-define=STUDY_PACKS_URL=<that folder's URL>.
"""

from __future__ import annotations

import argparse
import datetime as dt
import gzip
import hashlib
import json
import shutil
import sqlite3
import sys
from pathlib import Path

MANIFEST_FORMAT = 1


def describe(db_path: Path) -> dict:
    """Pack id, kind, name, language and license from the pack's own tables."""
    db = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    try:
        meta = dict(db.execute("SELECT key, value FROM meta"))
        pid = meta.get("pack")
        if not pid:
            raise ValueError(f"{db_path.name} is not a pack (no meta.pack)")
        v = db.execute("SELECT name, language, attribution, license_status FROM version WHERE id = ?", (pid,)).fetchone()
        if v:
            info = {"kind": "version", "name": v[0], "language": v[1], "attribution": v[2], "license_status": v[3]}
        else:
            r = db.execute("SELECT kind, name, attribution, license_status FROM resource WHERE id = ?", (pid,)).fetchone()
            if not r:
                raise ValueError(f"{db_path.name}: no version or resource row for {pid}")
            info = {"kind": r[0], "name": r[1], "language": None, "attribution": r[2], "license_status": r[3]}
        return {"id": pid, "schema_version": int(meta["schema_version"]), "built_at": meta.get("built_at"), **info}
    finally:
        db.close()


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def package(packs: Path, out: Path) -> dict:
    out.mkdir(parents=True, exist_ok=True)
    entries = []
    schema = None
    for db_path in sorted(packs.glob("*.db")):
        info = describe(db_path)
        if schema is None:
            schema = info["schema_version"]
        elif info["schema_version"] != schema:
            raise ValueError(f"{db_path.name}: schema {info['schema_version']} differs from {schema}")
        gz = out / f"{db_path.name}.gz"
        with db_path.open("rb") as src, gzip.GzipFile(gz, "wb", compresslevel=9, mtime=0) as dst:
            shutil.copyfileobj(src, dst, 1 << 20)
        entries.append({
            "id": info["id"], "kind": info["kind"], "name": info["name"], "language": info["language"],
            "file": gz.name, "bytes": db_path.stat().st_size, "gz_bytes": gz.stat().st_size, "sha256": sha256(gz),
            "attribution": info["attribution"], "license_status": info["license_status"],
        })
        print(f"[{info['id']}] {db_path.stat().st_size // 1024} KiB -> {gz.stat().st_size // 1024} KiB")
    if not entries:
        raise ValueError(f"no packs in {packs}")
    manifest = {
        "format": MANIFEST_FORMAT,
        "schema_version": schema,
        "built_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "packs": entries,
    }
    (out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    return manifest


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--packs", type=Path, required=True)
    ap.add_argument("--out", type=Path)
    a = ap.parse_args(argv)
    try:
        package(a.packs, a.out or a.packs)
    except ValueError as e:
        print(e, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
