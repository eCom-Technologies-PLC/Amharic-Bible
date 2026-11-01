"""Original-language texts with word-level data.

Two sources:
  - Open Scriptures Hebrew Bible (OSHB): OSIS XML of the Westminster Leningrad
    Codex with lemmas (Strong's-based) and morphology. Hebrew and Aramaic.
    Versification follows the WLC; VerseMap.xml maps it to the KJV-style
    numbering every other version in the app uses.
  - Robinson-Pierpont Byzantine Greek NT (RP2018): one CSV per book with
    Strong's numbers and parsing codes, plus an accented CSV whose {TAG a > b}
    notes record where other editions (NA27/28, ECM) or Byzantine
    manuscripts read differently.

Both produce OriginalBook objects: verses in the same shape as the USFM parser
(so the reader, search and copy work unchanged) plus words and variants.
"""

from __future__ import annotations

import csv
import io
import re
import unicodedata
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field

from .usfm import Verse

OSIS_OT = {
    "Gen": "GEN", "Exod": "EXO", "Lev": "LEV", "Num": "NUM", "Deut": "DEU", "Josh": "JOS",
    "Judg": "JDG", "Ruth": "RUT", "1Sam": "1SA", "2Sam": "2SA", "1Kgs": "1KI", "2Kgs": "2KI",
    "1Chr": "1CH", "2Chr": "2CH", "Ezra": "EZR", "Neh": "NEH", "Esth": "EST", "Job": "JOB",
    "Ps": "PSA", "Prov": "PRO", "Eccl": "ECC", "Song": "SNG", "Isa": "ISA", "Jer": "JER",
    "Lam": "LAM", "Ezek": "EZK", "Dan": "DAN", "Hos": "HOS", "Joel": "JOL", "Amos": "AMO",
    "Obad": "OBA", "Jonah": "JON", "Mic": "MIC", "Nah": "NAM", "Hab": "HAB", "Zeph": "ZEP",
    "Hag": "HAG", "Zech": "ZEC", "Mal": "MAL",
}

# File names used by the RP2018 CSVs -> USFM codes.
RP_NT = {
    "MAT": "MAT", "MAR": "MRK", "LUK": "LUK", "JOH": "JHN", "ACT": "ACT", "ROM": "ROM",
    "1CO": "1CO", "2CO": "2CO", "GAL": "GAL", "EPH": "EPH", "PHP": "PHP", "COL": "COL",
    "1TH": "1TH", "2TH": "2TH", "1TI": "1TI", "2TI": "2TI", "TIT": "TIT", "PHM": "PHM",
    "HEB": "HEB", "JAM": "JAS", "1PE": "1PE", "2PE": "2PE", "1JO": "1JN", "2JO": "2JN",
    "3JO": "3JN", "JUD": "JUD", "REV": "REV",
}

_NS = re.compile(r"^\{[^}]*\}")


@dataclass
class Word:
    text: str  # surface form as printed (accents, vowels and cantillation kept)
    strongs: str | None  # "H7225", "G3056"
    lemma: str | None  # source lemma field, e.g. "b/7225" or the Greek dictionary form
    morph: str | None  # "HR/Ncfsa" (OSHB) or "N-NSM" (Robinson)


@dataclass
class Variant:
    chapter: int
    verse: int
    source: str  # "qere", "NA", "NA27", "NA28", "ECM", "Byz"
    base: str  # what the printed text reads ("" when the variant adds words)
    reading: str  # what the other source reads ("" when it omits them)


@dataclass
class OriginalBook:
    code: str
    verses: list[Verse] = field(default_factory=list)
    words: dict[tuple[int, int], list[Word]] = field(default_factory=dict)
    variants: list[Variant] = field(default_factory=list)
    chapters_seen: list[int] = field(default_factory=list)
    title: str | None = None
    long_title: str | None = None
    abbrev: str | None = None
    headings: list = field(default_factory=list)
    crossrefs: list = field(default_factory=list)


def nfc(s: str) -> str:
    return unicodedata.normalize("NFC", s)


# ----------------------------------------------------------------- OSHB


def _local(tag: str) -> str:
    return _NS.sub("", tag)


def _osis_ref(ref: str) -> tuple[str, int, int]:
    book, ch, v = ref.split(".")
    return book, int(ch), int(v)


def load_versemap(xml_text: str) -> dict[tuple[str, int, int], tuple[int, int]]:
    """WLC (book, chapter, verse) -> KJV (chapter, verse), from OSHB VerseMap.xml."""
    out = {}
    for el in ET.fromstring(xml_text).iter():
        # Half-verse splits ("1Kgs.18.34!a") can't be represented with whole
        # verse keys; those verses keep their WLC numbers.
        if _local(el.tag) == "verse" and el.get("wlc") and el.get("kjv") and "!" not in el.get("wlc"):
            b, c, v = _osis_ref(el.get("wlc"))
            _, kc, kv = _osis_ref(el.get("kjv").split("!")[0])
            out[(b, c, v)] = (kc, kv)
    return out


def _map_verse(vmap: dict, book: str, ch: int, v: int) -> tuple[int, int]:
    if (book, ch, v) in vmap:
        return vmap[(book, ch, v)]
    # Psalm superscriptions are verse 1 (or 1-2) in the WLC and unnumbered in
    # the KJV: a WLC verse before the first remapped verse of a chapter whose
    # numbering shifts down belongs to the title, stored as verse 0.
    mapped = [(wv, kc, kv) for (b, c, wv), (kc, kv) in vmap.items() if b == book and c == ch]
    if mapped:
        first_wv, kc, kv = min(mapped)
        if v < first_wv and kc == ch and kv < first_wv:
            return ch, max(0, v - (first_wv - kv))
    return ch, v


def _strongs_he(lemma: str | None) -> str | None:
    """'b/7225' -> 'H7225'; '1254 a' -> 'H1254'; prefixes (b, c, d, k, l, m, s) are skipped."""
    if not lemma:
        return None
    for part in lemma.split("/"):
        m = re.match(r"\+?(\d+)", part.strip())
        if m:
            return f"H{int(m.group(1))}"
    return None


def parse_oshb(xml_text: str, vmap: dict) -> OriginalBook:
    root = ET.fromstring(xml_text)
    book_div = next(el for el in root.iter() if _local(el.tag) == "div" and el.get("type") == "book")
    osis_book = book_div.get("osisID")
    ob = OriginalBook(OSIS_OT[osis_book])
    by_key: dict[tuple[int, int], list[str]] = {}

    def add_text(key, piece, join=False):
        parts = by_key.setdefault(key, [])
        if join and parts:
            parts[-1] += piece
        else:
            parts.append(piece)

    for vel in book_div.iter():
        if _local(vel.tag) != "verse" or not vel.get("osisID"):
            continue
        _, ch, v = _osis_ref(vel.get("osisID"))
        key = _map_verse(vmap, osis_book, ch, v)
        words = ob.words.setdefault(key, [])
        joined = False  # after a maqqef the next word attaches without a space
        for el in vel:
            tag = _local(el.tag)
            if tag == "w":
                text = nfc((el.text or "").replace("/", ""))
                words.append(Word(text, _strongs_he(el.get("lemma")), el.get("lemma"), el.get("morph")))
                add_text(key, text, join=joined)
                joined = False
            elif tag == "seg":
                kind = el.get("type", "")
                if kind == "x-maqqef":
                    add_text(key, el.text or "־", join=True)
                    joined = True
                elif kind == "x-sof-pasuq":
                    add_text(key, el.text or "׃", join=True)
            elif tag == "note":
                rdg = next((r for r in el if _local(r.tag) == "rdg" and r.get("type") == "x-qere"), None)
                if rdg is not None:
                    qere = " ".join(nfc((w.text or "").replace("/", "")) for w in rdg if _local(w.tag) == "w")
                    base = words[-1].text if words else ""
                    ob.variants.append(Variant(key[0], key[1], "qere", base, qere))

    for (ch, v), parts in sorted(by_key.items()):
        ob.verses.append(Verse(ch, v, markup=[["t", " ".join(parts)]]))
        if v > 0 and ch not in ob.chapters_seen:
            ob.chapters_seen.append(ch)
    ob.words = {k: w for k, w in ob.words.items() if w}
    return ob


# ----------------------------------------------------------------- RP2018 Greek

_RP_TOKEN = re.compile(r"(\S+) (\d+) \{([^}]+)\}")
_RP_NOTE = re.compile(r"\{((?:NA|ECM|Byz)[0-9/]*) ([^}]*)\}")
_GREEK_WORD = re.compile(r"[^\s.,;·:’'()\[\]—–¶-]+’?")


def _strip_marks(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", s) if not unicodedata.combining(c)).lower()


def _rows(csv_text: str) -> dict[tuple[int, int], str]:
    return {(int(r["chapter"]), int(r["verse"])): r["text"] for r in csv.DictReader(io.StringIO(csv_text))}


def parse_rp(code_rp: str, parsed_csv: str, text_csv: str) -> OriginalBook:
    """parsed_csv: strongs/with-parsing; text_csv: ccat/with-variants (accented, with notes)."""
    ob = OriginalBook(RP_NT[code_rp])
    parsed = _rows(parsed_csv)
    texts = _rows(text_csv)
    for (ch, v) in sorted(parsed):
        raw = texts.get((ch, v), "")
        for m in _RP_NOTE.finditer(raw):
            source, body = m.group(1), m.group(2).strip()
            if body == "~":
                # NA (or another edition) omits the whole verse.
                ob.variants.append(Variant(ch, v, source, "", ""))
                continue
            base, _, reading = (x.strip() for x in body.partition(">"))
            # "-" on either side marks words the other edition omits or adds.
            ob.variants.append(Variant(ch, v, source, nfc("" if base == "-" else base),
                                       nfc("" if reading == "-" else reading)))
        text = nfc(re.sub(r"\s+", " ", _RP_NOTE.sub("", raw)).strip())
        paragraph = text.startswith("¶")  # ¶ marks a paragraph start in the RP text
        text = text.replace("¶", "")
        tokens = _RP_TOKEN.findall(parsed[(ch, v)])
        surfaces = _GREEK_WORD.findall(text)
        # The accented text and the parsed text hold the same words in the same
        # order; when a verse doesn't line up, fall back to the parsed form.
        aligned = len(surfaces) == len(tokens) and all(
            _strip_marks(s)[:1] == _strip_marks(t[0])[:1] for s, t in zip(surfaces, tokens))
        words = []
        for i, (form, num, morph) in enumerate(tokens):
            surface = surfaces[i] if aligned else form
            words.append(Word(nfc(surface), f"G{int(num)}", nfc(form), morph))
        ob.words[(ch, v)] = words
        markup = [["p"]] if paragraph else []
        ob.verses.append(Verse(ch, v, markup=markup + [["t", text or " ".join(t[0] for t in tokens)]]))
        if ch not in ob.chapters_seen:
            ob.chapters_seen.append(ch)
    return ob
