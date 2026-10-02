#!/usr/bin/env python3
"""Generate the bundled reading plans (app/assets/plans/plans.json).

Each plan splits one or more lists of chapters ("streams") into N days,
keeping chapters in canonical order. With several streams, every day has a
part of each (e.g. some Old Testament and some New Testament). Days are
balanced by chapter count ("split": "chapters", the original four plans,
kept stable for people already reading them) or by verse count ("verses",
so Psalm 119 is not one day's reading next to Psalm 117). A day's readings
are compressed into per-book chapter ranges: {"b": "GEN", "f": 1, "t": 3}.

Each plan also gets "minutes": the estimated reading time per day. The file
also carries "verse_counts" (book code -> verses per chapter, in canonical
order) for the plans people build in the app.

Usage: python pipeline/build_plans.py [--out app/assets/plans/plans.json]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from abible.catalog import CONTENT, REPO, load_books  # noqa: E402

# Average reading time per verse, from the length of full-Bible audio
# recordings (about 75 hours for 31,102 verses).
SECONDS_PER_VERSE = 9

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
    {
        "id": "mark-7",
        "name": {"am": "የማርቆስ ወንጌል በ7 ቀናት", "en": "Mark in 7 days"},
        "description": {
            "am": "አጭሩንና ፈጣኑን ወንጌል በአንድ ሳምንት ያንብቡ።",
            "en": "Read the shortest, fastest-moving Gospel in one week.",
        },
        "books": ["MRK"],
        "days": 7,
        "split": "verses",
    },
    {
        "id": "romans-7",
        "name": {"am": "ሮሜ በ7 ቀናት", "en": "Romans in 7 days"},
        "description": {
            "am": "የወንጌልን ትምህርት በሮሜ መልእክት በአንድ ሳምንት ያንብቡ።",
            "en": "Read Paul's fullest letter on the gospel in one week.",
        },
        "books": ["ROM"],
        "days": 7,
        "split": "verses",
    },
    {
        "id": "proverbs-31",
        "name": {"am": "ምሳሌ በ31 ቀናት", "en": "Proverbs in 31 days"},
        "description": {
            "am": "በየቀኑ አንድ የምሳሌ ምዕራፍ፤ በአንድ ወር።",
            "en": "One chapter of Proverbs a day, for a month.",
        },
        "books": ["PRO"],
        "days": 31,
    },
    {
        "id": "psalms-30",
        "name": {"am": "መዝሙረ ዳዊት በ30 ቀናት", "en": "Psalms in 30 days"},
        "description": {
            "am": "መዝሙረ ዳዊትን በሙሉ በአንድ ወር ይጸልዩና ያንብቡ።",
            "en": "Pray and read through all the Psalms in a month.",
        },
        "books": ["PSA"],
        "days": 30,
        "split": "verses",
    },
    {
        "id": "acts-letters-30",
        "name": {"am": "የሐዋርያት ሥራና የመጀመሪያዎቹ መልእክቶች", "en": "Acts and the early letters"},
        "description": {
            "am": "የቤተ ክርስቲያንን ጅማሬ በሐዋርያት ሥራ፣ ከዚያም ገላትያንና ተሰሎንቄን በአንድ ወር ያንብቡ።",
            "en": "The early church in Acts, then Galatians and Thessalonians, in a month.",
        },
        "books": ["ACT", "GAL", "1TH", "2TH"],
        "days": 30,
        "split": "verses",
    },
    {
        "id": "torah-90",
        "name": {"am": "ኦሪት (ከዘፍጥረት እስከ ዘዳግም) በ90 ቀናት", "en": "The Torah in 90 days"},
        "description": {
            "am": "አምስቱን የሙሴ መጻሕፍት በሦስት ወራት ያንብቡ።",
            "en": "Read the five books of Moses, Genesis to Deuteronomy, in three months.",
        },
        "books": ["GEN-DEU"],
        "days": 90,
        "split": "verses",
    },
    {
        "id": "wisdom-90",
        "name": {"am": "የጥበብ መጻሕፍት በ90 ቀናት", "en": "Wisdom books in 90 days"},
        "description": {
            "am": "ኢዮብን፣ መዝሙረ ዳዊትን፣ ምሳሌን፣ መክብብንና መኃልየ መኃልይን በሦስት ወራት ያንብቡ።",
            "en": "Job, Psalms, Proverbs, Ecclesiastes and Song of Songs in three months.",
        },
        "books": ["JOB-SNG"],
        "days": 90,
        "split": "verses",
    },
    {
        "id": "nt-wisdom-180",
        "name": {"am": "አዲስ ኪዳን ከመዝሙርና ምሳሌ ጋር በ6 ወራት", "en": "New Testament with Psalms and Proverbs"},
        "description": {
            "am": "በየቀኑ ከአዲስ ኪዳን እና ከመዝሙረ ዳዊት ወይም ከምሳሌ፤ በስድስት ወራት።",
            "en": "Each day, some New Testament and some Psalms or Proverbs, over six months.",
        },
        "streams": [["NT"], ["PSA", "PRO"]],
        "days": 180,
        "split": "verses",
    },
    {
        "id": "ot-history-180",
        "name": {"am": "የብሉይ ኪዳን ታሪክ መጻሕፍት በ6 ወራት", "en": "Old Testament history in 6 months"},
        "description": {
            "am": "ከኢያሱ እስከ አስቴር ያለውን የእስራኤልን ታሪክ በስድስት ወራት ያንብቡ።",
            "en": "Israel's story from Joshua to Esther, in six months.",
        },
        "books": ["JOS-EST"],
        "days": 180,
        "split": "verses",
    },
    {
        "id": "prophets-180",
        "name": {"am": "ነቢያት በ6 ወራት", "en": "The Prophets in 6 months"},
        "description": {
            "am": "ከኢሳይያስ እስከ ሚልክያስ ያሉትን ነቢያት በስድስት ወራት ያንብቡ።",
            "en": "Isaiah to Malachi, the major and minor prophets, in six months.",
        },
        "books": ["ISA-MAL"],
        "days": 180,
        "split": "verses",
    },
    {
        "id": "bible-year-mixed",
        "name": {"am": "መጽሐፍ ቅዱስ በአንድ ዓመት፤ ብሉይና አዲስ በየቀኑ", "en": "The Bible in a year, Old and New together"},
        "description": {
            "am": "በየቀኑ ከብሉይ ኪዳን፣ እንዲሁም ከአዲስ ኪዳን ወይም ከመዝሙረ ዳዊት፤ በ365 ቀናት።",
            "en": "Each day, some Old Testament plus some New Testament or Psalms, in 365 days.",
        },
        "streams": [["GEN-JOB", "PRO-MAL"], ["NT", "PSA"]],
        "days": 365,
        "split": "verses",
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


def split_balanced(weights: list[int], n: int) -> list[tuple[int, int]]:
    """Split indexes 0..len-1 into n contiguous, non-empty [start, end) ranges
    whose weight sums are as even as possible: each cut goes at the chapter
    boundary nearest that day's share of the running total."""
    m = len(weights)
    if n <= 0:
        raise ValueError("n must be positive")
    if n > m:
        raise ValueError(f"{n} days but only {m} chapters")
    cum = [0]
    for w in weights:
        cum.append(cum[-1] + w)
    total = cum[-1]
    out, start = [], 0
    for d in range(n - 1):
        target = total * (d + 1) / n
        lo, hi = start + 1, m - (n - d - 1)  # leave a chapter for each later day
        end = min(range(lo, hi + 1), key=lambda k: (abs(cum[k] - target), k))
        out.append((start, end))
        start = end
    out.append((start, m))
    return out


def load_verse_counts(path: Path = CONTENT / "verse_counts.json") -> dict[str, list[int]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    return {k: v for k, v in data.items() if not k.startswith("_")}


def select_books(sel, books: list) -> list:
    """"ALL", "OT", "NT", or a list of codes and inclusive ranges ("JOS-EST",
    "NT")."""
    if sel == "ALL":
        return books
    if isinstance(sel, str):
        sel = [sel]
    by_code = {b.code: b for b in books}
    out = []
    for item in sel:
        if item in ("OT", "NT"):
            out += [b for b in books if b.testament == item]
        elif "-" in item[1:]:
            first, last = item.split("-")
            out += [b for b in books if by_code[first].num <= b.num <= by_code[last].num]
        else:
            out.append(by_code[item])
    return out


def build() -> dict:
    books = sorted(load_books().values(), key=lambda b: b.num)
    verses = load_verse_counts()
    plans = []
    for spec in PLANS:
        n = spec["days"]
        streams = spec.get("streams", [spec.get("books")])
        days: list[list[tuple[str, int]]] = [[] for _ in range(n)]
        total_verses = 0
        for sel in streams:
            chapters = [(b.code, c) for b in select_books(sel, books) for c in range(1, b.chapters + 1)]
            weights = [verses[b][c - 1] for b, c in chapters]
            total_verses += sum(weights)
            if spec.get("split", "chapters") == "verses":
                groups = [chapters[a:z] for a, z in split_balanced(weights, n)]
            else:
                groups = split_even(chapters, n)
            for d, g in enumerate(groups):
                days[d] += g
        plans.append({
            "id": spec["id"],
            "name": spec["name"],
            "description": spec["description"],
            "minutes": max(1, round(total_verses / n * SECONDS_PER_VERSE / 60)),
            "days": [compress(day) for day in days],
        })
    # Verses per chapter, in canonical book order: the app balances the
    # plans people build themselves with it.
    counts = {b.code: verses[b.code] for b in books}
    return {"version": 1, "plans": plans, "verse_counts": counts}


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
