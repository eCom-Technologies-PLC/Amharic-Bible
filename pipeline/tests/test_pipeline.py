import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import build_db  # noqa: E402
from abible import usfm  # noqa: E402
from abible.catalog import alias_key, load_books, split_vkey, vkey  # noqa: E402
from abible.geez import geez_to_int, index_terms, int_to_geez, normalize  # noqa: E402

VECTORS = json.loads((HERE / "normalize_vectors.json").read_text(encoding="utf-8"))
FIXTURES = HERE / "fixtures" / "usfm"


class GeezTest(unittest.TestCase):
    def test_normalize_vectors(self):
        for src, want in VECTORS["normalize"]:
            self.assertEqual(normalize(src), want, src)

    def test_index_terms_vectors(self):
        for src, want in VECTORS["index_terms"]:
            self.assertEqual(index_terms(src), want, src)

    def test_alias_vectors(self):
        for src, want in VECTORS["alias_key"]:
            self.assertEqual(alias_key(src), want, src)

    def test_numerals_round_trip(self):
        for n, g in VECTORS["geez_numerals"]:
            self.assertEqual(int_to_geez(n), g)
            self.assertEqual(geez_to_int(g), n)
        for n in range(1, 2000):
            self.assertEqual(geez_to_int(int_to_geez(n)), n)

    def test_spelling_variants_match(self):
        self.assertEqual(normalize("ሐጢአት"), normalize("ኃጢአት"))
        self.assertEqual(normalize("ዓለም"), normalize("አለም"))
        self.assertEqual(normalize("ፀሐይ"), normalize("ጸሀይ"))


class CatalogTest(unittest.TestCase):
    def test_books(self):
        books = load_books()
        self.assertEqual(len(books), 66)
        self.assertEqual(sorted(b.num for b in books.values()), list(range(1, 67)))
        self.assertEqual(books["JHN"].num, 43)
        self.assertEqual(sum(b.chapters for b in books.values()), 1189)

    def test_vkey(self):
        self.assertEqual(vkey(43, 3, 16), 43003016)
        self.assertEqual(split_vkey(43003016), (43, 3, 16))

    def test_aliases_unique_per_testament_book(self):
        # Abbreviations must not collide, or reference parsing is ambiguous.
        seen = {}
        for b in load_books().values():
            for a in {alias_key(b.abbrev), alias_key(b.short), alias_key(b.code)}:
                self.assertNotIn(a, seen, f"{a} used by {seen.get(a)} and {b.code}")
                seen[a] = b.code


class UsfmTest(unittest.TestCase):
    def test_paragraph_note_and_spacing(self):
        b = usfm.parse("\\id GEN\n\\c 1\n\\p\n\\v 1 In the beginning, God\\f + \\fr 1:1 \\ft A note.\\f* created.\n")
        v = b.verses[0]
        self.assertEqual(v.text, "In the beginning, God created.")
        self.assertEqual(v.markup[0], ["p"])
        self.assertIn(["n", "A note."], v.markup)

    def test_poetry_and_heading(self):
        b = usfm.parse("\\id PSA\n\\c 23\n\\d Title.\n\\q1\n\\v 1 one;\n\\q2 two.\n")
        v = b.verses[0]
        self.assertEqual(v.markup, [["q", 1], ["t", "one;"], ["q", 2], ["t", "two."]])
        self.assertEqual(v.text, "one; two.")
        self.assertEqual((b.headings[0].level, b.headings[0].text), (9, "Title."))

    def test_words_of_jesus_and_attributes(self):
        b = usfm.parse('\\id JHN\n\\c 3\n\\v 16 \\wj For God \\w loved|strong="G25"\\w* the world.\\wj*\n')
        self.assertEqual(b.verses[0].markup, [["wj", "For God loved the world."]])

    def test_bridged_verse(self):
        b = usfm.parse("\\id GEN\n\\c 1\n\\v 1-2 Both verses.\n\\v 3 Next.\n")
        self.assertEqual((b.verses[0].verse, b.verses[0].label), (1, "1-2"))

    def test_crossref_captured(self):
        b = usfm.parse("\\id JHN\n\\c 3\n\\v 16 Text.\\x - \\xo 3:16 \\xt Rom 5:8\\x*\n")
        self.assertEqual(b.verses[0].text, "Text.")
        self.assertEqual(b.crossrefs[0].text, "Rom 5:8")


class BuildTest(unittest.TestCase):
    def test_build_sample_db(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / "content.db"
            rc = build_db.build(FIXTURES, out, sample=True, allow_unverified=True)
            self.assertEqual(rc, 0)
            db = sqlite3.connect(out)
            text = db.execute("SELECT text FROM verse WHERE version_id='AMH1962' AND vkey=43003016").fetchone()[0]
            self.assertTrue(text.startswith("እግዚአብሔር አንድያ ልጁን"))
            # Search tolerates spelling variants and fused prefixes.
            q = "SELECT vkey FROM verse_fts WHERE verse_fts MATCH ? AND version_id='AMH1962'"
            hits = {r[0] for r in db.execute(q, (normalize("ዓለም") + "*",))}
            self.assertIn(43003017, hits)
            self.assertEqual(db.execute("SELECT value FROM meta WHERE key='is_sample'").fetchone()[0], "1")
            codes = {r[0] for r in db.execute("SELECT code FROM book_alias WHERE alias=?", (alias_key("ዮሐ"),))}
            self.assertEqual(codes, {"JHN"})

    def test_unverified_license_is_refused(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / "content.db"
            rc = build_db.build(FIXTURES, out, sample=True, allow_unverified=False)
            self.assertEqual(rc, 1)
            self.assertFalse(out.exists())


if __name__ == "__main__":
    unittest.main()
