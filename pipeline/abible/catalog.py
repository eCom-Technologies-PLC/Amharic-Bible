"""Book catalog, version registry and verse-key helpers."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path

from .geez import normalize

REPO = Path(__file__).resolve().parents[2]
CONTENT = REPO / "content"


def vkey(book_num: int, chapter: int, verse: int) -> int:
    """Verse key BBCCCVVV, e.g. John 3:16 -> 43003016."""
    return book_num * 1_000_000 + chapter * 1_000 + verse


def split_vkey(key: int) -> tuple[int, int, int]:
    return key // 1_000_000, key // 1_000 % 1_000, key % 1_000


@dataclass(frozen=True)
class BookInfo:
    num: int
    code: str
    testament: str
    chapters: int
    name: str
    short: str
    abbrev: str
    en: str
    en_abbrevs: tuple[str, ...]


def load_books(path: Path = CONTENT / "books.json") -> dict[str, BookInfo]:
    data = json.loads(path.read_text(encoding="utf-8"))
    return {
        b["code"]: BookInfo(
            b["num"], b["code"], b["testament"], b["chapters"], b["name"], b["short"],
            b["abbrev"], b["en"], tuple(b["en_abbrevs"]),
        )
        for b in data["books"]
    }


def load_versions(path: Path = CONTENT / "versions.json") -> dict[str, dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    return {v["id"]: v for v in data["versions"]}


_ORDINAL_RE = re.compile(r"^(\d)\s*(?:ኛ|st|nd|rd|th)?")


def alias_key(s: str) -> str:
    """Key used to match a typed book name against aliases.

    "1ኛ ቆሮ" / "1 ቆሮ" / "1ቆሮ" -> "1ቆሮ";  "1 Cor." -> "1cor".
    Mirrored by aliasKey() in app/lib/core/geez.dart.
    """
    s = normalize(s)
    s = _ORDINAL_RE.sub(lambda m: m.group(1), s)
    return s.replace(" ", "")


def book_aliases(b: BookInfo, extra: tuple[str, ...] = ()) -> set[str]:
    names = {b.name, b.short, b.abbrev, b.en, b.code, *b.en_abbrevs, *extra}
    return {alias_key(n) for n in names if n and alias_key(n)}
