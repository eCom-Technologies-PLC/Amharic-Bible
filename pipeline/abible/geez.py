"""Ge'ez (Ethiopic) text utilities: search normalization and Ge'ez numerals.

Normalization also covers the original-language versions: Hebrew points and
accents and Greek accents and breathings are ignored, and final letter forms
(ך ם ן ף ץ, ς) match their regular forms, so a plain query finds pointed text.

The Dart app has a line-for-line port in app/lib/core/geez.dart. Both are
checked against the shared vectors in pipeline/tests/normalize_vectors.json,
so any change here must be mirrored there.
"""

from __future__ import annotations

import re
import unicodedata

# Homophone consonant series folded onto one base series. Each series is 8
# consecutive code points: the 7 vowel orders plus the labialized form.
_SERIES_FOLDS = [
    (0x1210, 0x1200),  # ሐ -> ሀ
    (0x1280, 0x1200),  # ኀ -> ሀ
    (0x12B8, 0x1200),  # ኸ -> ሀ
    (0x1220, 0x1230),  # ሠ -> ሰ
    (0x12D0, 0x12A0),  # ዐ -> አ
    (0x1340, 0x1338),  # ፀ -> ጸ
]

# Vowel spellings used interchangeably: 4th order (ሃ, ኣ) folds to 1st (ሀ, አ).
_VOWEL_FOLDS = {0x1203: 0x1200, 0x12A3: 0x12A0}


def _assigned(cp: int) -> bool:
    try:
        unicodedata.name(chr(cp))
        return True
    except ValueError:
        return False


def _build_char_map() -> dict[int, int]:
    m: dict[int, int] = {}
    for src, dst in _SERIES_FOLDS:
        for off in range(8):
            if _assigned(src + off) and _assigned(dst + off):
                m[src + off] = dst + off
    # Apply vowel folds on top of (and after) the series folds.
    for k, v in list(m.items()):
        m[k] = _VOWEL_FOLDS.get(v, v)
    m.update(_VOWEL_FOLDS)
    return m


CHAR_MAP: dict[int, int] = _build_char_map()

GEEZ_ONES = "፩፪፫፬፭፮፯፰፱"  # U+1369..U+1371 -> 1..9
GEEZ_TENS = "፲፳፴፵፶፷፸፹፺"  # U+1372..U+137A -> 10..90
GEEZ_HUNDRED = "፻"  # U+137B
GEEZ_TEN_THOUSAND = "፼"  # U+137C
_GEEZ_NUM_RE = re.compile("[፩-፼]+")

# Ethiopic punctuation U+1360..U+1368 (፠ ፡ ። ፣ ፤ ፥ ፦ ፧ ፨) plus any Unicode
# punctuation or symbol.
_PUNCT_RE = re.compile(r"[፠-፨]")


# Combining marks ignored by search: Latin/Greek diacritics (accents,
# breathings, iota subscript) and Hebrew points and cantillation. Hebrew
# punctuation in the same block (maqaf ־, paseq ׀, sof pasuq ׃, nun hafukha ׆)
# is left to the punctuation rule below.
_MARKS_RE = re.compile("[\u0300-\u036F\u0591-\u05BD\u05BF\u05C1\u05C2\u05C4\u05C5\u05C7]")

# Final letter forms -> regular forms (applied after lowercasing).
FINAL_FORMS = {ord("ך"): "כ", ord("ם"): "מ", ord("ן"): "נ", ord("ף"): "פ", ord("ץ"): "צ", ord("ς"): "σ"}


def geez_to_int(s: str) -> int:
    total = 0
    cur = 0
    for ch in s:
        if ch in GEEZ_ONES:
            cur += GEEZ_ONES.index(ch) + 1
        elif ch in GEEZ_TENS:
            cur += (GEEZ_TENS.index(ch) + 1) * 10
        elif ch == GEEZ_HUNDRED:
            cur = (cur or 1) * 100
        elif ch == GEEZ_TEN_THOUSAND:
            total = (total + (cur or 1)) * 10000
            cur = 0
        else:
            raise ValueError(f"not a Ge'ez numeral: {ch!r}")
    return total + cur


def int_to_geez(n: int) -> str:
    if n <= 0:
        return str(n)
    s = str(n)
    if len(s) % 2:
        s = "0" + s
    pairs = [int(s[i : i + 2]) for i in range(0, len(s), 2)]
    out = []
    seen_nonzero = False
    for i, p in enumerate(pairs):
        pos = len(pairs) - 1 - i  # 0 = least significant pair
        tens, ones = divmod(p, 10)
        digits = (GEEZ_TENS[tens - 1] if tens else "") + (GEEZ_ONES[ones - 1] if ones else "")
        if pos == 0:
            out.append(digits)
            continue
        sep = GEEZ_HUNDRED if pos % 2 == 1 else GEEZ_TEN_THOUSAND
        if p == 0:
            if sep == GEEZ_TEN_THOUSAND and seen_nonzero:
                out.append(sep)
            continue
        seen_nonzero = True
        out.append(("" if p == 1 else digits) + sep)
    return "".join(out)


def normalize(text: str) -> str:
    """Normalize text for search: same output for spelling variants."""
    text = unicodedata.normalize("NFC", text)
    text = text.translate(CHAR_MAP)
    text = unicodedata.normalize("NFC", _MARKS_RE.sub("", unicodedata.normalize("NFD", text)))
    text = _GEEZ_NUM_RE.sub(lambda m: f" {geez_to_int(m.group())} ", text)
    text = _PUNCT_RE.sub(" ", text)
    text = "".join(
        " " if unicodedata.category(ch)[0] in "PS" else ch for ch in text
    )
    text = text.lower().translate(FINAL_FORMS)
    return " ".join(text.split())


# Amharic proclitic prepositions/possessive often fused to the next word
# (በ "in/by", ለ "for", ከ "from", የ "of"). Stripping them at index time lets a
# search for ኢየሱስ also find በኢየሱስ.
_PREFIXES = ("በ", "ለ", "ከ", "የ")


# Hebrew prefixes written as part of the word: ו "and", then one of ה "the",
# ב "in", ל "to", כ "as", מ "from", ש "that" (וּבָאָרֶץ -> בארץ, ארץ). Stems
# keep at least three letters, so ארץ also finds וּבָאָרֶץ.
_HEBREW_PREFIXES = "בהלכמש"


def _hebrew_stems(word: str) -> list[str]:
    out = []
    if len(word) > 3 and word[0] == "ו":
        word = word[1:]
        out.append(word)
    if len(word) > 3 and word[0] in _HEBREW_PREFIXES:
        out.append(word[1:])
    return out


def index_terms(text: str) -> str:
    """Normalized text plus prefix-stripped variants, for the FTS index."""
    words = normalize(text).split()
    extra = [w[1:] for w in words if len(w) > 2 and w[0] in _PREFIXES]
    extra += [s for w in words for s in _hebrew_stems(w)]
    return " ".join(words + extra)
