#!/usr/bin/env python3
"""Download USFM sources listed in content/versions.json into content/sources/<ID>/.

Versions whose audio provider is "direct" also get content/sources/<ID>/audio.json:
the chapter MP3 URLs read from the first audio index that lists the most chapters.

Usage: python pipeline/fetch_sources.py [VERSION_ID ...]
"""

from __future__ import annotations

import io
import json
import sys
import urllib.request
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from abible.audio import chapter_count, parse_listing  # noqa: E402
from abible.catalog import CONTENT, load_books, load_versions  # noqa: E402


def _get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "amharic-bible-pipeline"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        return resp.read()


def fetch_audio(vid: str, audio: dict, dest: Path) -> None:
    codes = set(load_books())
    best: tuple[str, dict] | None = None
    for url in audio["index_urls"]:
        try:
            html = _get(url).decode("utf-8", "replace")
        except OSError as e:
            print(f"[{vid}] audio index {url}: {e}")
            continue
        tracks = parse_listing(html, url, codes)
        print(f"[{vid}] audio index {url}: {chapter_count(tracks)} chapters in {len(tracks)} books")
        if tracks and (best is None or chapter_count(tracks) > chapter_count(best[1])):
            best = (url, tracks)
    if best is None:
        raise SystemExit(f"[{vid}] no chapter MP3s found in {audio['index_urls']}")
    url, tracks = best
    doc = {"source": url, "chapters": {b: {str(c): u for c, u in sorted(cs.items())} for b, cs in tracks.items()}}
    (dest / "audio.json").write_text(json.dumps(doc, indent=1) + "\n", encoding="utf-8")
    print(f"[{vid}] audio: {chapter_count(tracks)} chapters from {url}")


def fetch(vid: str, reg: dict, dest_root: Path) -> None:
    src = reg["source"]
    if src["type"] != "usfm_zip":
        raise SystemExit(f"[{vid}] unsupported source type {src['type']}")
    print(f"[{vid}] downloading {src['url']}")
    data = _get(src["url"])
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
    audio = reg.get("audio") or {}
    if audio.get("provider") == "direct":
        fetch_audio(vid, audio, dest)


def main(argv: list[str]) -> int:
    registry = load_versions()
    ids = argv or list(registry)
    for vid in ids:
        fetch(vid, registry[vid], CONTENT / "sources")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
