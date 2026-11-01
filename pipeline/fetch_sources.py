#!/usr/bin/env python3
"""Download the sources listed in content/versions.json and content/resources.json
into content/sources/<ID>/.

Source types:
  usfm_zip  a zip of USFM files (eBible.org)
  git       a public Git repository; "files" maps glob patterns in the repo to
            sub-folders of content/sources/<ID>/ ("" for the folder itself)
  files     individual files; "files" maps a file name to its URL

Usage: python pipeline/fetch_sources.py [ID ...]
"""

from __future__ import annotations

import io
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from abible.catalog import CONTENT, load_resources, load_versions  # noqa: E402

USER_AGENT = {"User-Agent": "amharic-bible-pipeline"}


def _download(url: str) -> bytes:
    req = urllib.request.Request(url, headers=USER_AGENT)
    with urllib.request.urlopen(req, timeout=300) as resp:
        return resp.read()


def _reset(dest: Path) -> None:
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)


def fetch(vid: str, reg: dict, dest_root: Path) -> None:
    src = reg["source"]
    dest = dest_root / vid
    kind = src["type"]
    if kind == "usfm_zip":
        print(f"[{vid}] downloading {src['url']}")
        data = _download(src["url"])
        _reset(dest)
        n = 0
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            for name in z.namelist():
                if name.lower().endswith((".sfm", ".usfm")):
                    (dest / Path(name).name).write_bytes(z.read(name))
                    n += 1
        print(f"[{vid}] {n} USFM files -> {dest}")
    elif kind == "files":
        _reset(dest)
        for name, url in src["files"].items():
            print(f"[{vid}] downloading {url}")
            (dest / name).write_bytes(_download(url))
    elif kind == "git":
        print(f"[{vid}] cloning {src['repo']}")
        with tempfile.TemporaryDirectory() as tmp:
            subprocess.run(["git", "clone", "--quiet", "--depth", "1", src["repo"], tmp], check=True)
            _reset(dest)
            n = 0
            for pattern, sub in src["files"].items():
                for f in sorted(Path(tmp).glob(pattern)):
                    if not f.is_file() or ".git" in f.parts:
                        continue
                    # Keep sub-folders for recursive patterns (e.g. <author>/<ref>.toml).
                    rel = f.relative_to(tmp) if pattern.startswith("**") else Path(f.name)
                    target = dest / sub / rel
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(f, target)
                    n += 1
        print(f"[{vid}] {n} files -> {dest}")
    else:
        raise SystemExit(f"[{vid}] unsupported source type {kind}")


def main(argv: list[str]) -> int:
    registry = {**load_versions(), **load_resources()}
    ids = argv or list(registry)
    for vid in ids:
        fetch(vid, registry[vid], CONTENT / "sources")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
