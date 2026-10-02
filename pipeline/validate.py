"""Content validation run by build_db.py on every build."""

from __future__ import annotations

import unicodedata
from dataclasses import dataclass, field

from abible.catalog import BookInfo
from abible.usfm import Book


@dataclass
class Report:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


def validate_version(vid: str, books: list[Book], catalog: dict[str, BookInfo],
                     complete: bool = True) -> Report:
    r = Report()
    codes = {b.code for b in books}

    if complete:
        missing = [c for c in catalog if c not in codes]
        if missing:
            r.errors.append(f"missing books: {' '.join(missing)}")

    for b in books:
        info = catalog[b.code]
        if not b.verses:
            r.errors.append(f"{b.code}: no verses")
            continue
        if complete:
            chapters = sorted(set(b.chapters_seen))
            if chapters != list(range(1, info.chapters + 1)):
                # Versification differs between traditions (e.g. Joel, Malachi);
                # report it so the versification map can be checked.
                r.warnings.append(f"{b.code}: chapters {chapters[:1]}..{chapters[-1:]} "
                                  f"(expected 1..{info.chapters})")

        seen: set[tuple[int, int]] = set()
        last: tuple[int, int] | None = None
        bridged_to = 0
        for v in b.verses:
            ref = f"{b.code} {v.chapter}:{v.label or v.verse}"
            key = (v.chapter, v.verse)
            if key in seen:
                r.errors.append(f"{ref}: duplicate verse")
            seen.add(key)
            text = v.text
            if not text:
                r.errors.append(f"{ref}: empty verse")
            if "\\" in text:
                r.errors.append(f"{ref}: unparsed USFM marker in text: {text[:60]!r}")
            if unicodedata.normalize("NFC", text) != text:
                r.errors.append(f"{ref}: text is not NFC-normalized")
            if complete and last and last[0] == v.chapter and v.verse != last[1] + 1 \
                    and v.verse > bridged_to + 1:
                r.warnings.append(f"{ref}: gap after verse {last[1]}")
            if v.label and "-" in v.label:
                try:
                    bridged_to = int(v.label.split("-")[1].rstrip("abc"))
                except ValueError:
                    pass
            last = key
    return r
