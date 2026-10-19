"""Open Scriptures Hebrew Bible (Westminster Leningrad Codex, OSIS XML) -> USFM.

The WLC text is public domain; OSHB's lemma and morphology tags are CC BY 4.0
(https://github.com/openscriptures/morphhb). Conversion choices:

- Words keep their points and accents. OSHB marks morpheme boundaries with "/"
  inside words; these are removed from the text (the lemma and morphology
  attributes keep them for word study).
- Ketiv/qere: the text shows the qere (what is read), with the ketiv (what is
  written) in a footnote.
- Maqqef, sof pasuq and paseq stay in the text. Open and closed paragraph
  marks (פ / ס) become paragraph breaks.
- Verse numbers are the WLC's own; VerseMap.xml (OSHB's WLC -> KJV table) is
  converted to the versification map that build_db.py applies.

Do not NFC-normalize this text: NFC reorders Hebrew points (see the OSHB README).
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET

from .osis import OSIS_TO_USFM, UsfmWriter, footnote, usfm_ref, word

DESCRIPTION = "Westminster Leningrad Codex (Open Scriptures Hebrew Bible)"

_SEG_TEXT = {"x-maqqef": "־", "x-sof-pasuq": "׃", "x-paseq": "׀", "x-reversednun": "׆"}
_PARAGRAPH_SEGS = {"x-pe", "x-samekh"}


def _local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _surface(w: ET.Element) -> str:
    return "".join(w.itertext()).replace("/", "").strip()


def _word(w: ET.Element) -> str:
    return word(_surface(w), lemma=w.get("lemma", ""), x_morph=w.get("morph", ""))


def _space(tail: str | None) -> str:
    return " " if tail and not tail.strip() else ""


class _Verse:
    def __init__(self):
        self.out: list[str] = []
        self.ketiv: list[str] = []  # ketiv words waiting for their qere note
        self.paragraph_after = False

    def flush_ketiv(self):
        # A ketiv without a following note is shown as written.
        self.out.extend(self.ketiv)
        self.ketiv = []

    def render(self, children) -> None:
        for el in children:
            tag = _local(el.tag)
            ketiv = el.get("type") == "x-ketiv" or el.get("subType") == "x-ketiv"
            if tag == "w" and ketiv:
                self.ketiv.append(_word(el) + _space(el.tail))
                continue
            if tag == "seg" and ketiv:
                self.ketiv.append(_SEG_TEXT.get(el.get("type"), "") + _space(el.tail))
                continue
            if tag == "note":
                if el.get("type") == "variant":
                    self.ketiv = []
                    self.qere(el)
                    self.out.append(_space(el.tail))
                continue  # editorial notes on the WLC/BHS are not shown
            self.flush_ketiv()
            if tag == "w":
                self.out.append(_word(el))
            elif tag == "seg":
                kind = el.get("type")
                if kind in _PARAGRAPH_SEGS:
                    self.paragraph_after = True
                else:
                    self.out.append(_SEG_TEXT.get(kind, "".join(el.itertext())))
            self.out.append(_space(el.tail))
        self.flush_ketiv()

    def qere(self, note: ET.Element) -> None:
        catch = next((c for c in note if _local(c.tag) == "catchWord"), None)
        rdg = next((c for c in note if _local(c.tag) == "rdg"), None)
        if rdg is not None:
            self.render(list(rdg))
        written = "".join(catch.itertext()).replace("/", "").strip() if catch is not None else ""
        if written:
            self.out.append(footnote(f"Ketiv: {written}"))

    def text(self) -> str:
        return re.sub(r"\s+", " ", "".join(self.out)).strip()


def convert_book(xml: bytes | str) -> tuple[str, str]:
    """One OSHB book file -> (USFM code, USFM text)."""
    root = ET.fromstring(xml)
    book = next(e for e in root.iter() if _local(e.tag) == "div" and e.get("type") == "book")
    code = OSIS_TO_USFM[book.get("osisID")]
    out = UsfmWriter(code, DESCRIPTION)
    for v in book.iter():
        if _local(v.tag) != "verse":
            continue
        _, chapter, verse = v.get("osisID").split(".")
        rendered = _Verse()
        rendered.render(list(v))
        out.verse(int(chapter), int(verse), rendered.text())
        if rendered.paragraph_after:
            out.paragraph()
    return code, out.text()


def verse_map(xml: bytes | str) -> list[list[str]]:
    """OSHB VerseMap.xml -> [[wlc_ref, kjv_ref], ...] in USFM references."""
    root = ET.fromstring(xml)
    return [[usfm_ref(v.get("wlc")), usfm_ref(v.get("kjv"))]
            for v in root.iter() if _local(v.tag) == "verse"]
