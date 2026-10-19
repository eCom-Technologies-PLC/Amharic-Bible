"""OSIS book names (used by the Hebrew and Greek sources) and a small USFM writer."""

from __future__ import annotations

# OSIS book ID -> USFM code, in canonical order.
OSIS_TO_USFM = {
    "Gen": "GEN", "Exod": "EXO", "Lev": "LEV", "Num": "NUM", "Deut": "DEU", "Josh": "JOS",
    "Judg": "JDG", "Ruth": "RUT", "1Sam": "1SA", "2Sam": "2SA", "1Kgs": "1KI", "2Kgs": "2KI",
    "1Chr": "1CH", "2Chr": "2CH", "Ezra": "EZR", "Neh": "NEH", "Esth": "EST", "Job": "JOB",
    "Ps": "PSA", "Prov": "PRO", "Eccl": "ECC", "Song": "SNG", "Isa": "ISA", "Jer": "JER",
    "Lam": "LAM", "Ezek": "EZK", "Dan": "DAN", "Hos": "HOS", "Joel": "JOL", "Amos": "AMO",
    "Obad": "OBA", "Jonah": "JON", "Mic": "MIC", "Nah": "NAM", "Hab": "HAB", "Zeph": "ZEP",
    "Hag": "HAG", "Zech": "ZEC", "Mal": "MAL",
    "Matt": "MAT", "Mark": "MRK", "Luke": "LUK", "John": "JHN", "Acts": "ACT", "Rom": "ROM",
    "1Cor": "1CO", "2Cor": "2CO", "Gal": "GAL", "Eph": "EPH", "Phil": "PHP", "Col": "COL",
    "1Thess": "1TH", "2Thess": "2TH", "1Tim": "1TI", "2Tim": "2TI", "Titus": "TIT", "Phlm": "PHM",
    "Heb": "HEB", "Jas": "JAS", "1Pet": "1PE", "2Pet": "2PE", "1John": "1JN", "2John": "2JN",
    "3John": "3JN", "Jude": "JUD", "Rev": "REV",
}

OT_OSIS = list(OSIS_TO_USFM)[:39]
NT_OSIS = list(OSIS_TO_USFM)[39:]


def usfm_ref(osis_ref: str) -> str:
    """"Gen.32.1" -> "GEN 32:1";  "1Kgs.18.34!a" -> "1KI 18:34a"."""
    ref, _, part = osis_ref.partition("!")
    book, chapter, verse = ref.split(".")
    return f"{OSIS_TO_USFM[book]} {chapter}:{verse}{part}"


class UsfmWriter:
    """Builds a USFM book one verse at a time."""

    def __init__(self, code: str, description: str, title: str | None = None):
        self.lines = [f"\\id {code} {description}", "\\usfm 3.0"]
        if title:
            self.lines.append(f"\\mt1 {title}")
        self.chapter = 0
        self.para = False  # a paragraph break is due before the next verse

    def verse(self, chapter: int, verse: int, text: str) -> None:
        if chapter != self.chapter:
            self.chapter = chapter
            self.lines.append(f"\\c {chapter}")
            self.para = True
        if self.para:
            self.lines.append("\\p")
            self.para = False
        self.lines.append(f"\\v {verse} {text}")

    def paragraph(self) -> None:
        self.para = True

    def text(self) -> str:
        return "\n".join(self.lines) + "\n"


def word(surface: str, **attrs: str) -> str:
    """A USFM \\w word with attributes (kept for word study; the app shows only the word)."""
    a = " ".join(f'{k.replace("_", "-")}="{v}"' for k, v in attrs.items() if v)
    return f"\\w {surface}|{a}\\w*" if a else surface


def footnote(text: str) -> str:
    return f"\\f + \\ft {text}\\f*"
