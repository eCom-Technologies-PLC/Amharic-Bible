#!/usr/bin/env python3
"""Download USFM sources listed in content/versions.json into content/sources/<ID>/.

Usage: python pipeline/fetch_sources.py [VERSION_ID ...]
"""

from __future__ import annotations

import io
import sys
import urllib.request
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from abible.catalog import CONTENT, load_versions  # noqa: E402


def fetch(vid: str, reg: dict, dest_root: Path) -> None:
    src = reg["source"]
    if src["type"] != "usfm_zip":
        raise SystemExit(f"[{vid}] unsupported source type {src['type']}")
    print(f"[{vid}] downloading {src['url']}")
    req = urllib.request.Request(src["url"], headers={"User-Agent": "amharic-bible-pipeline"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = resp.read()
    dest = dest_root / vid
    dest.mkdir(parents=True, exist_ok=True)
    for old in dest.iterdir():
        old.unlink()
    n = 0
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        for name in z.namelist():
            if name.lower().endswith((".sfm", ".usfm")):
                (dest / Path(name).name).write_bytes(z.read(name))
                n += 1
    print(f"[{vid}] {n} USFM files -> {dest}")


def main(argv: list[str]) -> int:
    registry = load_versions()
    ids = argv or list(registry)
    for vid in ids:
        fetch(vid, registry[vid], CONTENT / "sources")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
