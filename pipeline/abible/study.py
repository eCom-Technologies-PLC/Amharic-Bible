"""Study resources that are not Bible texts: lexicons, cross-references,
people/places/events, a Bible dictionary and commentary.

Every loader returns plain rows; build_db.py writes them and records the
resource's license and attribution. All references are converted to the app's
version-independent verse keys (66-book canon, KJV-style numbering).
"""

from __future__ import annotations

import json
import re
import tomllib
from dataclasses import dataclass
from pathlib import Path

from .catalog import BookInfo, vkey
from .original import OSIS_OT, nfc

OSIS_NT = {
    "Matt": "MAT", "Mark": "MRK", "Luke": "LUK", "John": "JHN", "Acts": "ACT", "Rom": "ROM",
    "1Cor": "1CO", "2Cor": "2CO", "Gal": "GAL", "Eph": "EPH", "Phil": "PHP", "Col": "COL",
    "1Thess": "1TH", "2Thess": "2TH", "1Tim": "1TI", "2Tim": "2TI", "Titus": "TIT", "Phlm": "PHM",
    "Heb": "HEB", "Jas": "JAS", "1Pet": "1PE", "2Pet": "2PE", "1John": "1JN", "2John": "2JN",
    "3John": "3JN", "Jude": "JUD", "Rev": "REV",
}
OSIS = {**OSIS_OT, **OSIS_NT}


def osis_vkey(ref: str, catalog: dict[str, BookInfo]) -> int | None:
    """'Gen.1.1' -> 1001001; None for books outside the 66-book canon."""
    parts = ref.split(".")
    if len(parts) != 3 or parts[0] not in OSIS:
        return None
    try:
        return vkey(catalog[OSIS[parts[0]]].num, int(parts[1]), int(parts[2]))
    except ValueError:
        return None


# ----------------------------------------------------------------- lexicon


@dataclass
class LexEntry:
    id: str  # "H7225", "G3056"
    lang: str  # "heb", "arc", "grc"
    lemma: str
    translit: str
    pron: str
    definition: str
    derivation: str
    usage: str  # KJV renderings


_JS_OBJECT = re.compile(r"=\s*(\{.*\})\s*;?\s*(?:module\.exports.*)?$", re.S)


def load_strongs(js_text: str) -> list[LexEntry]:
    """Open Scriptures strongs-{hebrew,greek}-dictionary.js."""
    data = json.loads(_JS_OBJECT.search(js_text).group(1))
    out = []
    for sid, e in data.items():
        deriv = (e.get("derivation") or "").strip()
        lang = "grc" if sid.startswith("G") else ("arc" if "(Aramaic)" in deriv else "heb")
        out.append(LexEntry(
            id=f"{sid[0]}{int(sid[1:])}", lang=lang, lemma=nfc((e.get("lemma") or "").strip()),
            translit=nfc((e.get("xlit") or e.get("translit") or "").strip()), pron=(e.get("pron") or "").strip(),
            definition=nfc((e.get("strongs_def") or "").strip()), derivation=nfc(deriv),
            usage=nfc((e.get("kjv_def") or "").strip()),
        ))
    return out


# ----------------------------------------------------------------- cross-references


def load_openbible_xrefs(text: str, catalog: dict[str, BookInfo], min_votes: int = 1):
    """OpenBible.info cross_references.txt -> (from_vkey, to_start, to_end, votes)."""
    out = []
    for line in text.splitlines()[1:]:
        cols = line.split("\t")
        if len(cols) < 3:
            continue
        votes = int(cols[2])
        if votes < min_votes:
            continue
        src = osis_vkey(cols[0], catalog)
        start, _, end = cols[1].partition("-")
        a = osis_vkey(start, catalog)
        b = osis_vkey(end, catalog) if end else a
        if src and a and b:
            out.append((src, a, b, votes))
    return out


# ----------------------------------------------------------------- people, places, events


@dataclass
class Entity:
    id: str  # "person:david_994"
    kind: str  # person | place | event
    name: str
    summary: str
    start_year: int | None
    end_year: int | None
    lat: float | None
    lon: float | None
    vkeys: list[int]


def _num(v) -> float | None:
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def _year(v) -> int | None:
    n = _num(v)
    return int(n) if n is not None else None


def _first(v) -> str:
    if isinstance(v, list):
        v = v[0] if v else ""
    return re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", (v or "")).strip()


def load_theographic(folder: Path, catalog: dict[str, BookInfo]) -> list[Entity]:
    """Theographic Bible Metadata json/ folder (people, places, events, verses)."""
    def load(name):
        return json.loads((folder / f"{name}.json").read_text(encoding="utf-8"))

    verse_keys = {}
    for r in load("verses"):
        k = osis_vkey(r["fields"].get("osisRef", ""), catalog)
        if k:
            verse_keys[r["id"]] = k

    def keys(f):
        return sorted({verse_keys[v] for v in f.get("verses", []) if v in verse_keys})

    out = []
    for r in load("people"):
        f = r["fields"]
        if not f.get("name"):
            continue
        out.append(Entity(f"person:{f['slug']}", "person", f.get("displayTitle") or f["name"],
                          _first(f.get("dictText")), _year(f.get("birthYear")), _year(f.get("deathYear")),
                          None, None, keys(f)))
    for r in load("places"):
        f = r["fields"]
        if not f.get("displayTitle"):
            continue
        out.append(Entity(f"place:{f['slug']}", "place", f["displayTitle"], _first(f.get("dictText")),
                          None, None, _num(f.get("latitude")), _num(f.get("longitude")), keys(f)))
    for r in load("events"):
        f = r["fields"]
        if not f.get("title"):
            continue
        year = _year(f.get("startDate"))
        out.append(Entity(f"event:{f['eventID']}", "event", f["title"], "", year, year, None, None, keys(f)))
    return [e for e in out if e.vkeys]


def load_easton(folder: Path) -> list[tuple[str, str, str]]:
    """Easton's Bible Dictionary (public domain) from Theographic: (id, term, text)."""
    data = json.loads((folder / "easton.json").read_text(encoding="utf-8"))
    out = []
    for r in data:
        f = r["fields"]
        if f.get("termLabel") and f.get("dictText"):
            out.append((f["def_id"], f["termLabel"].strip(), _first(f["dictText"])))
    return out


# ----------------------------------------------------------------- commentary


@dataclass
class Comment:
    author: str
    tradition: str  # the source's own grouping, e.g. "Early Fathers (Pre-Nicaea)"
    year: int | None
    work: str
    url: str
    vkey_start: int
    vkey_end: int
    text: str


_FILE_REF = re.compile(r"^(.+?) (\d+)_(\d+)(?:-(\d+)(?:_(\d+))?)?$")


def _ref_range(stem: str, by_en: dict[str, BookInfo]) -> tuple[int, int] | None:
    """'John 3_16-17' -> (43003016, 43003017); 'John 3_16-4_2' spans chapters."""
    m = _FILE_REF.match(stem)
    if not m or m.group(1) not in by_en:
        return None
    b = by_en[m.group(1)].num
    ch, v = int(m.group(2)), int(m.group(3))
    if m.group(5):
        end = vkey(b, int(m.group(4)), int(m.group(5)))
    elif m.group(4):
        end = vkey(b, ch, int(m.group(4)))
    else:
        end = vkey(b, ch, v)
    return vkey(b, ch, v), end


def load_hcf(root: Path, catalog: dict[str, BookInfo], max_year: int, exclude: set[str]) -> list[Comment]:
    """Historical Christian Faith Commentaries-Database: <Author>/<Book C_V>.toml.

    Only authors with metadata (year, tradition) up to max_year are kept, and
    only entries that name their source work, so every comment can be cited.
    """
    by_en = {b.en: b for b in catalog.values()}
    by_en["Song of Solomon"] = by_en["Song of Songs"]
    out = []
    for meta in sorted(root.glob("*/metadata.toml")):
        info = tomllib.loads(meta.read_text(encoding="utf-8"))
        year = info.get("default_year")
        tradition = info.get("father_category", "")
        if year is None or year > max_year or tradition in exclude:
            continue
        author = meta.parent.name
        for f in sorted(meta.parent.glob("*.toml")):
            if f.name == "metadata.toml":
                continue
            rng = _ref_range(f.stem, by_en)
            if not rng:
                continue
            try:
                doc = tomllib.loads(f.read_text(encoding="utf-8"))
            except tomllib.TOMLDecodeError:
                continue
            for c in doc.get("commentary", []):
                text = (c.get("quote") or "").strip()
                work = (c.get("source_title") or "").strip()
                if not text or not work:
                    continue
                out.append(Comment(author + (c.get("append_to_author_name") or ""), tradition,
                                   c.get("time") or year, work, (c.get("source_url") or "").strip(),
                                   rng[0], rng[1], text))
    return out
