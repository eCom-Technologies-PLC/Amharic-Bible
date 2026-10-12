"""Chapter audio hosted as plain MP3 files (provider "direct").

Public-domain recordings such as eBible.org's World English Bible audio are
published as one MP3 per chapter in a directory listing, with the USFM book
code and chapter in the file name (e.g. "02_GEN_01.mp3",
"eng-webbe_012_1KI_01.mp3"). fetch_sources.py reads the listing into
audio.json next to the version's USFM files; build_db.py loads it into the
audio_chapter table, so the app can stream or download chapters without the
Bible Brain proxy.
"""

from __future__ import annotations

import re
from urllib.parse import unquote, urljoin

_HREF_RE = re.compile(r"""href\s*=\s*["']([^"'#?]+\.mp3)["']""", re.IGNORECASE)
# Book code and chapter at the end of the file name: ..._GEN_01.mp3, ...-PSA-119.mp3
_NAME_RE = re.compile(r"(?:^|[_\-\s])([1-4A-Za-z][A-Za-z0-9]{2})[_\-\s]0*(\d{1,3})\.mp3$", re.IGNORECASE)


def parse_listing(html: str, base_url: str, book_codes: set[str]) -> dict[str, dict[int, str]]:
    """Map book code -> chapter -> absolute MP3 URL from an HTML listing.

    Links whose name has no known book code are ignored. The first link for
    a chapter wins.
    """
    out: dict[str, dict[int, str]] = {}
    for href in _HREF_RE.findall(html):
        name = unquote(href.rsplit("/", 1)[-1])
        m = _NAME_RE.search(name)
        if not m:
            continue
        code, chapter = m.group(1).upper(), int(m.group(2))
        if code not in book_codes or chapter < 1:
            continue
        out.setdefault(code, {}).setdefault(chapter, urljoin(base_url, href))
    return out


def chapter_count(tracks: dict[str, dict[int, str]]) -> int:
    return sum(len(c) for c in tracks.values())
