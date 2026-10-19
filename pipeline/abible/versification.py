"""Renumber a version's verses into the canonical (KJV-style) versification.

Every version in content.db shares one verse-key scheme, so the side-by-side
view, highlights, notes and plans line up across versions. A source that
numbers verses differently (the Hebrew Masoretic text, the Greek NA/UBS text)
ships a map that build_db.py applies after parsing.

A map is a list of [source_ref, canonical_ref] pairs, e.g.
  ["MAL 3:19", "MAL 4:1"]       the whole verse moves
  ["PSA 13:6a", "PSA 13:5"]     the first part of the source verse ...
  ["PSA 13:6b", "PSA 13:6"]     ... and the second part map to different verses
  ["1KI 18:34a", "1KI 18:33b"]  the source verse's start ends canonical 18:33

Rules:
- A verse not in the map keeps its number.
- If only one part (a or b) of a source verse is listed, the other part keeps
  the verse's own number.
- Source verses that end up sharing a canonical verse are joined; a source verse
  that covers several canonical verses becomes a bridged verse ("5-6").
- Except at the start of a Psalm: there, verses whose canonical number is also
  taken by a later verse are the title (the KJV does not number it), which
  becomes a heading (\\d) before verse 1.
"""

from __future__ import annotations

import json
import re
from dataclasses import replace
from pathlib import Path

from .usfm import Book, CrossRef, Heading, Verse

MAP_FILE = "versification.json"

_REF_RE = re.compile(r"^([0-9A-Z]{3}) (\d+):(\d+)([ab]?)$")

Key = tuple[int, int]


def parse_ref(ref: str) -> tuple[str, int, int, str]:
    m = _REF_RE.match(ref)
    if not m:
        raise ValueError(f"bad versification reference {ref!r}")
    return m.group(1), int(m.group(2)), int(m.group(3)), m.group(4)


def load(path: Path) -> list[list[str]]:
    return json.loads(path.read_text(encoding="utf-8"))["map"]


def write(path: Path, entries: list[list[str]], source: str) -> None:
    for a, b in entries:  # fail early on a malformed map
        parse_ref(a), parse_ref(b)
    path.write_text(json.dumps({"source": source, "map": entries}, ensure_ascii=False, indent=0) + "\n",
                    encoding="utf-8")


def _join(markups: list[list]) -> list:
    out: list = []
    for m in markups:
        m = [list(t) for t in m]
        if out and m and out[-1][0] in ("t", "wj", "n") and m[0][0] in ("t", "wj"):
            if out[-1][0] == m[0][0]:
                out[-1][1] += " " + m.pop(0)[1]
            else:
                m[0][1] = " " + m[0][1]
        out.extend(m)
    return out


def _mark_psalm_titles(book: Book, targets: dict[Key, list[Key]]) -> None:
    """Give a Psalm's leading title verses no canonical verse."""
    chapters: dict[int, list[Key]] = {}
    for v in book.verses:
        chapters.setdefault(v.chapter, []).append((v.chapter, v.verse))
    for keys in chapters.values():
        for i, key in enumerate(keys):
            later = {t for k in keys[i + 1:] for t in targets[k]}
            if not set(targets[key]) <= later:
                break
            targets[key] = []


def remap(book: Book, entries: list[list[str]]) -> tuple[Book, list[str]]:
    """Return the book in canonical numbering, plus warnings."""
    warnings: list[str] = []
    explicit: dict[Key, list[tuple[str, Key]]] = {}
    for src, dst in entries:
        sb, sc, sv, spart = parse_ref(src)
        db, dc, dv, _ = parse_ref(dst)
        if sb != book.code:
            continue
        if db != sb:
            raise ValueError(f"versification map crosses books: {src} -> {dst}")
        explicit.setdefault((sc, sv), []).append((spart, (dc, dv)))

    def targets_of(key: Key) -> list[Key]:
        es = explicit.get(key)
        if es is None:
            return [key]
        t = {dst for _, dst in es}
        parts = {p for p, _ in es}
        if parts and "" not in parts and parts != {"a", "b"}:
            t.add(key)  # the unlisted part keeps the verse's number
        return sorted(t)

    targets = {(v.chapter, v.verse): targets_of((v.chapter, v.verse)) for v in book.verses}
    if book.code == "PSA":
        _mark_psalm_titles(book, targets)
    if all(t == [k] for k, t in targets.items()):
        return book, warnings

    # Group source verses that share a canonical verse.
    groups: list[list[Verse]] = []
    group_of: dict[Key, int] = {}
    titles: list[Verse] = []
    for v in book.verses:
        t = targets[(v.chapter, v.verse)]
        if not t:
            titles.append(v)
            continue
        hit = next((group_of[k] for k in t if k in group_of), None)
        if hit is None:
            hit = len(groups)
            groups.append([])
        groups[hit].append(v)
        for k in t:
            group_of[k] = hit

    verses: list[Verse] = []
    for g in groups:
        keys = sorted({k for v in g for k in targets[(v.chapter, v.verse)]})
        chapter = keys[0][0]
        nums = [n for c, n in keys if c == chapter]
        if len(nums) < len(keys):
            warnings.append(f"{book.code} {g[0].chapter}:{g[0].verse} covers verses in two chapters; "
                            f"numbered {chapter}:{nums[0]}")
        lo, hi = nums[0], nums[-1]
        if len(g) == 1 and keys == [(g[0].chapter, g[0].verse)]:
            verses.append(g[0])
            continue
        label = f"{lo}-{hi}" if hi > lo else None
        verses.append(Verse(chapter, lo, label, _join([v.markup for v in g])))
    verses.sort(key=lambda v: (v.chapter, v.verse))

    # Where each source verse now starts: its first canonical verse, or for a
    # title, the verse it precedes.
    position: dict[Key, Key] = {}
    order = [(v.chapter, v.verse) for v in book.verses]
    for key in order:
        if targets[key]:
            position[key] = targets[key][0]
    for i in range(len(order) - 1, -1, -1):
        key = order[i]
        if key not in position:
            nxt = order[i + 1] if i + 1 < len(order) else None
            if nxt is not None and nxt[0] == key[0] and nxt in position:
                position[key] = position[nxt]

    def at(chapter: int, verse: int) -> Key:
        return position.get((chapter, verse), (chapter, verse))

    headings = [Heading(*at(h.chapter, h.verse), h.level, h.text) for h in book.headings]
    pending: list[str] = []
    for i, v in enumerate(titles):
        key = (v.chapter, v.verse)
        if key not in position:
            warnings.append(f"{book.code} {v.chapter}:{v.verse} has no canonical verse; dropped")
            continue
        pending.append(v.text)
        nxt = titles[i + 1] if i + 1 < len(titles) else None
        if nxt is None or position.get((nxt.chapter, nxt.verse)) != position[key]:
            headings.append(Heading(*position[key], 9, " ".join(pending)))
            pending = []
    headings.sort(key=lambda h: (h.chapter, h.verse))  # stable: titles follow section headings

    crossrefs = [CrossRef(*at(x.chapter, x.verse), x.text) for x in book.crossrefs]
    chapters = sorted({v.chapter for v in verses})
    return replace(book, verses=verses, headings=headings, crossrefs=crossrefs, chapters_seen=chapters), warnings
