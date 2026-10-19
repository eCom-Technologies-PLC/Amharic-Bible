"""SBL Greek New Testament (XML) -> USFM.

The SBLGNT is CC BY 4.0 (https://github.com/LogosBible/SBLGNT). Conversion
choices:

- Paragraphs follow the edition's <p> elements.
- The apparatus sigla (⸀ ⸁ ⸂ ⸃ ⸄ ⸅) point to a critical apparatus the app does
  not ship, so they are removed. Brackets [ ] and ⟦ ⟧ (doubtful text) stay.
- Verse numbers follow the edition; VERSE_MAP below lines its few
  differences up with the KJV versification the other versions use.
"""

from __future__ import annotations

import re
import unicodedata
import xml.etree.ElementTree as ET

from .osis import OSIS_TO_USFM, UsfmWriter

DESCRIPTION = "SBL Greek New Testament"

# SBLGNT (NA/UBS numbering) -> KJV, in the format of versification.py.
VERSE_MAP = [
    # "Greet one another with a holy kiss. All the saints greet you." is one
    # verse in the SBLGNT and two in the KJV.
    ["2CO 13:12a", "2CO 13:12"],
    ["2CO 13:12b", "2CO 13:13"],
    ["2CO 13:13", "2CO 13:14"],
    # 3 John 15 is the end of KJV verse 14.
    ["3JN 1:15", "3JN 1:14b"],
    # Revelation 12:18 is the start of KJV 13:1.
    ["REV 12:18", "REV 13:1a"],
]

# Verse ids in the XML: "John 1:1", "1 Corinthians 1:1".
_REF_RE = re.compile(r"^(.+) (\d+):(\d+)$")
_SIGLA_RE = re.compile(r"[⸀⸁⸂⸃⸄⸅]\d*")


def _local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def convert_book(xml: bytes | str, osis_id: str) -> tuple[str, str]:
    """One SBLGNT book file -> (USFM code, USFM text)."""
    if isinstance(xml, bytes):
        xml = xml.decode("utf-8-sig")
    root = ET.fromstring(xml.lstrip("﻿"))
    code = OSIS_TO_USFM[osis_id]
    title = next(("".join(e.itertext()).strip() for e in root if _local(e.tag) == "title"), None)
    out = UsfmWriter(code, DESCRIPTION, title)

    ref: tuple[int, int] | None = None
    buf: list[str] = []

    def flush():
        if ref is not None and buf:
            text = re.sub(r"\s+", " ", _SIGLA_RE.sub("", "".join(buf))).strip()
            text = unicodedata.normalize("NFC", text)  # a few words in the source are not NFC
            out.verse(ref[0], ref[1], text)
        buf.clear()

    for p in root:
        if _local(p.tag) != "p":
            continue
        children = list(p)
        if children and _local(children[0].tag) == "verse-number":
            flush()
            out.paragraph()
        else:
            buf.append(" \\p ")  # a paragraph that starts mid-verse
        for el in children:
            tag = _local(el.tag)
            if tag == "verse-number":
                flush()
                m = _REF_RE.match(el.get("id", ""))
                if not m:
                    raise ValueError(f"bad verse id {el.get('id')!r} in {osis_id}")
                ref = (int(m.group(2)), int(m.group(3)))
            elif tag == "w":
                buf.append("".join(el.itertext()))
            elif tag == "prefix":
                buf.append(el.text or "")
            elif tag == "suffix":
                # An empty suffix is the space between two words.
                buf.append(el.text if el.text and el.text.strip() else " ")
    flush()
    return code, out.text()
