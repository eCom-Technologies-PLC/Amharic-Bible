#!/usr/bin/env python3
"""Download the sources listed in content/versions.json into content/sources/<ID>/.

Usage: python pipeline/fetch_sources.py [VERSION_ID ...]

Source types:
  usfm_zip    a zip of USFM files (eBible.org)
  oshb_osis   Open Scriptures Hebrew Bible OSIS files under base_url (<Gen>.xml ...
              plus VerseMap.xml), converted to USFM and a versification map
  sblgnt_xml  SBL Greek New Testament XML files under base_url (<Matt>.xml ...),
              converted to USFM
"""

from __future__ import annotations

import io
import sys
import urllib.request
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from abible import oshb, sblgnt, versification  # noqa: E402
from abible.catalog import CONTENT, load_books, load_versions  # noqa: E402
from abible.osis import NT_OSIS, OT_OSIS  # noqa: E402


def download(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "amharic-bible-pipeline"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        return resp.read()


def usfm_name(code: str) -> str:
    return f"{load_books()[code].num:02d}{code}.usfm"


def fetch(vid: str, reg: dict, dest_root: Path) -> None:
    src = reg["source"]
    kind = src["type"]
    # Download and convert everything first, so a failed download keeps the old files.
    files: dict[str, bytes] = {}
    if kind == "oshb_osis":
        print(f"[{vid}] downloading {src['base_url']}")
        for osis_id in OT_OSIS:
            code, text = oshb.convert_book(download(f"{src['base_url']}{osis_id}.xml"))
            files[usfm_name(code)] = text.encode()
        entries = oshb.verse_map(download(f"{src['base_url']}VerseMap.xml"))
        source = "OSHB VerseMap.xml (WLC -> KJV)"
    elif kind == "sblgnt_xml":
        print(f"[{vid}] downloading {src['base_url']}")
        for osis_id in NT_OSIS:
            code, text = sblgnt.convert_book(download(f"{src['base_url']}{osis_id}.xml"), osis_id)
            files[usfm_name(code)] = text.encode()
        entries, source = sblgnt.VERSE_MAP, "SBLGNT -> KJV (abible/sblgnt.py)"
    elif kind == "usfm_zip":
        print(f"[{vid}] downloading {src['url']}")
        with zipfile.ZipFile(io.BytesIO(download(src["url"]))) as z:
            for name in z.namelist():
                if name.lower().endswith((".sfm", ".usfm")):
                    files[Path(name).name] = z.read(name)
        entries = None
    else:
        raise SystemExit(f"[{vid}] unsupported source type {kind}")

    dest = dest_root / vid
    dest.mkdir(parents=True, exist_ok=True)
    for old in dest.iterdir():
        old.unlink()
    for name, data in files.items():
        (dest / name).write_bytes(data)
    if entries is not None:
        versification.write(dest / versification.MAP_FILE, entries, source)
    print(f"[{vid}] {len(files)} USFM files -> {dest}")


def main(argv: list[str]) -> int:
    registry = load_versions()
    ids = argv or list(registry)
    for vid in ids:
        fetch(vid, registry[vid], CONTENT / "sources")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
