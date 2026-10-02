#!/usr/bin/env python3
"""Generate the bundled reading plans (app/assets/plans/plans.json).

Each plan splits a list of chapters into N days of nearly equal length,
keeping chapters in canonical order. A day's readings are compressed into
per-book chapter ranges: {"b": "GEN", "f": 1, "t": 3}.

Usage: python pipeline/build_plans.py [--out app/assets/plans/plans.json]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from abible.catalog import REPO, load_books  # noqa: E402

PLANS = [
    {
        "id": "bible-year",
        "name": {"am": "መጽሐፍ ቅዱስን በአንድ ዓመት", "en": "The Bible in a year"},
        "description": {
            "am": "ሙሉውን መጽሐፍ ቅዱስ ከዘፍጥረት እስከ ራእይ በ365 ቀናት ያንብቡ።",
            "en": "Read the whole Bible, Genesis to Revelation, in 365 days.",
        },
        "books": "ALL",
        "days": 365,
    },
    {
        "id": "nt-90",
        "name": {"am": "አዲስ ኪዳን በ90 ቀናት", "en": "New Testament in 90 days"},
        "description": {
            "am": "አዲስ ኪዳንን በሦስት ወራት ውስጥ ያንብቡ።",
            "en": "Read the New Testament in three months.",
        },
        "books": "NT",
        "days": 90,
    },
    {
        "id": "gospels-30",
        "name": {"am": "ወንጌላት በ30 ቀናት", "en": "The Gospels in 30 days"},
        "description": {
            "am": "አራቱን ወንጌላት በአንድ ወር ያንብቡ።",
            "en": "Read the four Gospels in one month.",
        },
        "books": ["MAT", "MRK", "LUK", "JHN"],
        "days": 30,
    },
    {
        "id": "psalms-proverbs-60",
        "name": {"am": "መዝሙረ ዳዊትና ምሳሌ በ60 ቀናት", "en": "Psalms and Proverbs in 60 days"},
        "description": {
            "am": "መዝሙረ ዳዊትንና መጽሐፈ ምሳሌን በሁለት ወራት ያንብቡ።",
            "en": "Read Psalms and Proverbs in two months.",
        },
        "books": ["PSA", "PRO"],
        "days": 60,
    },
]


def split_even(items: list, n: int) -> list[list]:
    """Split items into n contiguous groups whose sizes differ by at most 1."""
    if n <= 0:
        raise ValueError("n must be positive")
    if n > len(items):
        raise ValueError(f"{n} days but only {len(items)} chapters")
    base, extra = divmod(len(items), n)
    out, i = [], 0
    for d in range(n):
        size = base + (1 if d < extra else 0)
        out.append(items[i : i + size])
        i += size
    return out


def compress(chapters: list[tuple[str, int]]) -> list[dict]:
    """[(GEN,1),(GEN,2),(EXO,1)] -> [{b:GEN,f:1,t:2},{b:EXO,f:1,t:1}]"""
    out: list[dict] = []
    for book, ch in chapters:
        if out and out[-1]["b"] == book and out[-1]["t"] == ch - 1:
            out[-1]["t"] = ch
        else:
            out.append({"b": book, "f": ch, "t": ch})
    return out


def build() -> dict:
    books = sorted(load_books().values(), key=lambda b: b.num)
    plans = []
    for spec in PLANS:
        sel = spec["books"]
        if sel == "ALL":
            chosen = books
        elif sel in ("OT", "NT"):
            chosen = [b for b in books if b.testament == sel]
        else:
            by_code = {b.code: b for b in books}
            chosen = [by_code[c] for c in sel]
        chapters = [(b.code, c) for b in chosen for c in range(1, b.chapters + 1)]
        days = [compress(day) for day in split_even(chapters, spec["days"])]
        plans.append({
            "id": spec["id"],
            "name": spec["name"],
            "description": spec["description"],
            "days": days,
        })
    return {"version": 1, "plans": plans}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=REPO / "app" / "assets" / "plans" / "plans.json")
    a = ap.parse_args(argv)
    a.out.parent.mkdir(parents=True, exist_ok=True)
    a.out.write_text(json.dumps(build(), ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"wrote {a.out} ({a.out.stat().st_size // 1024} KiB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
