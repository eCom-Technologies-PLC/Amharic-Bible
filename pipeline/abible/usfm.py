"""Minimal USFM parser for Bible text: books, chapters, verses, headings,
footnotes, cross-references and paragraph/poetry structure.

Output per verse:
  text   - plain display text (no notes), used for copy/share/search
  markup - list of tokens the app renders:
             ["p"]          paragraph break before the following text
             ["q", level]   poetry line break (indent level 1..3)
             ["t", text]    normal text run
             ["wj", text]   words of Jesus run
             ["n", text]    footnote anchor at this point
  label  - verse label when bridged ("1-2"), otherwise None
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

# A single space after an opening marker belongs to the marker; after a
# closing marker (e.g. \f*) it is part of the text.
_TOKEN_RE = re.compile(r"\\(\+?[a-z]+[0-9]*(?:\*|(?=[ \t]?)))(?:(?<!\*)[ \t])?|([^\\]+)")
_ATTR_RE = re.compile(r"\|[^|]*$")  # \w word|strong="H1234"\w*

PARA_MARKERS = {"p", "m", "pi", "pi1", "pi2", "mi", "nb", "pc", "pm", "pmo", "pmc", "pmr",
                "li", "li1", "li2", "li3", "b", "lim", "lim1", "lim2"}
POETRY_MARKERS = {"q": 1, "q1": 1, "q2": 2, "q3": 3, "qm": 1, "qm1": 1, "qm2": 2, "qr": 1, "qc": 1, "qa": 1}
HEADING_MARKERS = {"s": 1, "s1": 1, "s2": 2, "s3": 3, "ms": 1, "ms1": 1, "mr": 2, "sr": 2, "d": 9}
LINE_MARKERS = {"ide", "rem", "h", "toc1", "toc2", "toc3", "toca1", "toca2", "toca3",
                "mt", "mt1", "mt2", "mt3", "mte", "mte1", "imt", "imt1", "is", "is1", "ip",
                "ipr", "iot", "io", "io1", "io2", "ie", "cl", "cp", "cd", "sts", "usfm", "r"}
NOTE_MARKERS = {"f": "f", "fe": "f", "ef": "f", "x": "x", "ex": "x"}
NOTE_SKIP_PARTS = {"fr", "xo", "fv", "fm", "xop"}


@dataclass
class Verse:
    chapter: int
    verse: int
    label: str | None = None
    markup: list = field(default_factory=list)

    @property
    def text(self) -> str:
        parts = [tok[1] if tok[0] in ("t", "wj") else " "
                 for tok in self.markup if tok[0] != "n"]
        return re.sub(r"\s+", " ", "".join(parts)).strip()


@dataclass
class Heading:
    chapter: int
    verse: int  # the heading precedes this verse
    level: int
    text: str


@dataclass
class CrossRef:
    chapter: int
    verse: int
    text: str  # raw target text, e.g. "ዮሐ 1፥1"


@dataclass
class Book:
    code: str
    title: str | None = None  # \h running header
    long_title: str | None = None  # \toc1 or \mt
    verses: list[Verse] = field(default_factory=list)
    headings: list[Heading] = field(default_factory=list)
    crossrefs: list[CrossRef] = field(default_factory=list)
    chapters_seen: list[int] = field(default_factory=list)


def _ws(s: str) -> str:
    return re.sub(r"\s+", " ", s)


class _Parser:
    def __init__(self):
        self.book: Book | None = None
        self.chapter = 0
        self.cur: Verse | None = None
        self.pending_break: list | None = None
        self.pending_headings: list[tuple[int, str]] = []
        self.chars: list[str] = []
        self.expect: str | None = None  # marker awaiting its argument: id / c / v
        self.line_marker: str | None = None
        self.line_buf: list[str] = []
        self.note_kind: str | None = None
        self.note_buf: list[str] = []
        self.note_part = "keep"

    # ---- helpers ----
    def flush_line(self):
        m = self.line_marker
        if m is None:
            return
        txt = _ws("".join(self.line_buf)).strip()
        if m in HEADING_MARKERS and txt:
            self.pending_headings.append((HEADING_MARKERS[m], txt))
        elif m == "h" and self.book and txt:
            self.book.title = txt
        elif m in ("toc1", "mt", "mt1") and self.book and txt and not self.book.long_title:
            self.book.long_title = txt
        self.line_marker, self.line_buf = None, []

    def emit(self, kind: str, text: str):
        cur = self.cur
        if cur is None:
            return
        if self.pending_break is not None:
            if kind in ("t", "wj") and not text.strip():
                return  # don't place a break before pure whitespace
            cur.markup.append(self.pending_break)
            self.pending_break = None
        if kind in ("t", "wj") and cur.markup and cur.markup[-1][0] == kind:
            cur.markup[-1][1] += text
        else:
            cur.markup.append([kind, text])

    def start_verse(self, arg: str):
        m = re.match(r"(\d+)\w?(?:[-,](\d+)\w?)?", arg)
        if not m:
            raise ValueError(f"bad verse number {arg!r} in {self.book.code} {self.chapter}")
        num = int(m.group(1))
        label = arg if m.group(2) else None
        self.cur = Verse(self.chapter, num, label)
        self.book.verses.append(self.cur)
        for level, txt in self.pending_headings:
            self.book.headings.append(Heading(self.chapter, num, level, txt))
        self.pending_headings = []

    def take_arg(self, text: str) -> str:
        """Consume a marker argument from the start of text; return the rest."""
        stripped = text.lstrip()
        parts = stripped.split(None, 1)
        if not parts:
            return ""
        arg, rest = parts[0], (parts[1] if len(parts) > 1 else "")
        kind, self.expect = self.expect, None
        if kind == "id":
            self.book = Book(code=arg.upper())
            self.line_marker, self.line_buf = "ide", []  # ignore rest of \id line
        elif kind == "c":
            self.chapter = int(re.match(r"\d+", arg).group())
            self.book.chapters_seen.append(self.chapter)
            self.cur = None
        elif kind == "v":
            self.start_verse(arg)
        return rest

    # ---- main loop ----
    def text(self, text: str):
        if self.expect:
            text = self.take_arg(text)
            if not text:
                return
        if self.note_kind:
            if self.note_part == "caller":
                parts = text.split(None, 1)
                text = parts[1] if len(parts) > 1 else ""
                self.note_part = "keep"
            if self.note_part == "keep":
                self.note_buf.append(text)
            return
        if self.line_marker is not None:
            self.line_buf.append(text)
            return
        if self.chars and self.chars[-1] == "w":
            text = _ATTR_RE.sub("", text)
        self.emit("wj" if "wj" in self.chars else "t", text)

    def marker(self, raw: str):
        name = raw.lstrip("+")
        closing = name.endswith("*")
        name = name.rstrip("*")

        if name in NOTE_MARKERS:
            if closing:
                body = _ws("".join(self.note_buf)).strip()
                if self.cur is not None and body:
                    if self.note_kind == "x":
                        self.book.crossrefs.append(CrossRef(self.cur.chapter, self.cur.verse, body))
                    else:
                        self.emit("n", body)
                self.note_kind, self.note_buf = None, []
            else:
                self.note_kind, self.note_buf, self.note_part = NOTE_MARKERS[name], [], "caller"
            return
        if self.note_kind:
            if not closing:
                self.note_part = "skip" if name in NOTE_SKIP_PARTS else "keep"
            return

        if name in ("id", "c", "v"):
            self.flush_line()
            self.expect = name
            return
        if name in HEADING_MARKERS or name in LINE_MARKERS:
            self.flush_line()
            self.line_marker, self.line_buf = name, []
            return
        if name in PARA_MARKERS or name in POETRY_MARKERS:
            self.flush_line()
            self.pending_break = ["q", POETRY_MARKERS[name]] if name in POETRY_MARKERS else ["p"]
            return
        if closing:
            if name in self.chars:
                while self.chars and self.chars.pop() != name:
                    pass
        else:
            self.chars.append(name)  # character style; text is kept, style dropped except wj

    def end_of_line(self):
        if self.line_marker is not None:
            self.flush_line()
        elif self.cur is not None and self.cur.markup and self.cur.markup[-1][0] in ("t", "wj"):
            self.cur.markup[-1][1] += " "

    def finish(self) -> Book:
        self.flush_line()
        if self.book is None:
            raise ValueError("USFM has no \\id line")
        for v in self.book.verses:
            for tok in v.markup:
                if tok[0] in ("t", "wj"):
                    tok[1] = _ws(tok[1])
            texts = [t for t in v.markup if t[0] in ("t", "wj")]
            if texts:
                texts[0][1] = texts[0][1].lstrip()
                texts[-1][1] = texts[-1][1].rstrip()
            for i, tok in enumerate(v.markup[:-1]):
                if tok[0] in ("t", "wj") and v.markup[i + 1][0] in ("p", "q"):
                    tok[1] = tok[1].rstrip()
            v.markup = [t for t in v.markup if not (t[0] in ("t", "wj") and t[1] == "")]
            while v.markup and v.markup[-1][0] in ("p", "q"):
                v.markup.pop()
        return self.book


def parse(src: str) -> Book:
    p = _Parser()
    for line in src.splitlines():
        for m in _TOKEN_RE.finditer(line):
            if m.group(1) is not None:
                p.marker(m.group(1))
            else:
                p.text(m.group(2))
        p.end_of_line()
    return p.finish()
