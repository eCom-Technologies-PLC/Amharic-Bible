import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import build_db  # noqa: E402
import build_plans  # noqa: E402
import curated_plans  # noqa: E402
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


class PlansTest(unittest.TestCase):
    def test_split_even(self):
        groups = build_plans.split_even(list(range(10)), 3)
        self.assertEqual([len(g) for g in groups], [4, 3, 3])
        self.assertEqual(sum(groups, []), list(range(10)))

    def test_compress(self):
        self.assertEqual(build_plans.compress([("GEN", 49), ("GEN", 50), ("EXO", 1)]),
                         [{"b": "GEN", "f": 49, "t": 50}, {"b": "EXO", "f": 1, "t": 1}])

    def test_plans_cover_every_chapter_once(self):
        data = build_plans.build()
        books = load_books()
        for plan in data["plans"]:
            seen = [(r["b"], c) for day in plan["days"] for r in day for c in range(r["f"], r["t"] + 1)]
            self.assertEqual(len(seen), len(set(seen)), plan["id"])
            self.assertTrue(all(day for day in plan["days"]), plan["id"])
        year = next(p for p in data["plans"] if p["id"] == "bible-year")
        self.assertEqual(len(year["days"]), 365)
        total = sum(r["t"] - r["f"] + 1 for day in year["days"] for r in day)
        self.assertEqual(total, sum(b.chapters for b in books.values()))
        self.assertEqual(year["days"][0][0], {"b": "GEN", "f": 1, "t": 4})

    def test_split_balanced(self):
        ranges = build_plans.split_balanced([1, 1, 10, 1, 1, 1, 1, 1, 1, 1, 1], 3)
        self.assertEqual(ranges[0][0], 0)
        self.assertEqual(ranges[-1][1], 11)
        self.assertTrue(all(a < z for a, z in ranges))
        self.assertTrue(all(ranges[i][1] == ranges[i + 1][0] for i in range(len(ranges) - 1)))
        # Cuts land nearest each day's share (total 20, so about 6.7 per day).
        self.assertEqual(ranges, [(0, 2), (2, 4), (4, 11)])
        # Every day gets a chapter even when weights are lopsided.
        self.assertEqual(build_plans.split_balanced([100, 1, 1], 3), [(0, 1), (1, 2), (2, 3)])
        with self.assertRaises(ValueError):
            build_plans.split_balanced([1, 1], 3)

    def test_select_books(self):
        books = sorted(load_books().values(), key=lambda b: b.num)
        codes = [b.code for b in build_plans.select_books(["GEN-DEU", "MAT"], books)]
        self.assertEqual(codes, ["GEN", "EXO", "LEV", "NUM", "DEU", "MAT"])
        self.assertEqual(len(build_plans.select_books("NT", books)), 27)
        self.assertEqual(len(build_plans.select_books(["1SA-2KI"], books)), 4)

    def test_verse_counts_match_books(self):
        counts = build_plans.load_verse_counts()
        books = load_books()
        self.assertEqual(set(counts), set(books))
        for code, b in books.items():
            self.assertEqual(len(counts[code]), b.chapters, code)
        self.assertEqual(sum(sum(v) for v in counts.values()), 31102)
        self.assertEqual(counts["PSA"][118], 176)
        bundled = build_plans.build()["verse_counts"]
        self.assertEqual(list(bundled)[:2], ["GEN", "EXO"])
        self.assertEqual(bundled, {c: counts[c] for c in bundled})

    def test_plan_lengths_and_streams(self):
        plans = {p["id"]: p for p in build_plans.build()["plans"]}
        lengths = {i: len(p["days"]) for i, p in plans.items()}
        # At least one plan for each period: week, month, 3 months, 6 months, year.
        for lo, hi in [(1, 7), (8, 31), (32, 92), (93, 183), (184, 366)]:
            self.assertTrue(any(lo <= n <= hi for n in lengths.values()), (lo, hi))
        self.assertTrue(all(p["minutes"] >= 1 for p in plans.values()))
        focuses = {"all", "ot", "nt", "gospels", "wisdom"}
        self.assertTrue(all(p["focus"] and set(p["focus"]) <= focuses for p in plans.values()))
        for f in focuses:  # the assistant has something for every answer
            self.assertTrue(any(f in p["focus"] for p in plans.values()), f)
        # Mixed plans read from every stream every day.
        for day in plans["bible-year-mixed"]["days"]:
            testaments = {load_books()[r["b"]].testament for r in day}
            self.assertIn("OT", testaments)
        self.assertEqual(lengths["proverbs-31"], 31)
        self.assertTrue(all(len(day) == 1 and day[0]["f"] == day[0]["t"] for day in plans["proverbs-31"]["days"]))

    def test_parse_passage(self):
        self.assertEqual(build_plans.parse_passage("MAT 5"), [("MAT", 5)])
        self.assertEqual(build_plans.parse_passage("1KI 20-22"), [("1KI", 20), ("1KI", 21), ("1KI", 22)])

    def test_curated_passages_exist(self):
        books = load_books()
        for spec in curated_plans.CURATED_PLANS:
            passages = spec.get("sequence") or [p for day in spec["readings"] for p in day]
            for passage in passages:
                for book, ch in build_plans.parse_passage(passage):
                    self.assertIn(book, books, (spec["id"], passage))
                    self.assertTrue(1 <= ch <= books[book].chapters, (spec["id"], passage))

    def test_time_order_sequences_read_each_chapter_once(self):
        books = load_books()

        def chapters(seq):
            return [c for p in seq for c in build_plans.parse_passage(p)]

        gospels = chapters(curated_plans.LIFE_OF_JESUS)
        self.assertEqual(sorted(gospels), sorted(
            (b, c) for b in ("MAT", "MRK", "LUK", "JHN") for c in range(1, books[b].chapters + 1)))
        bible = chapters(curated_plans.CHRONOLOGICAL)
        self.assertEqual(len(bible), len(set(bible)))
        self.assertEqual(set(bible), {(b, c) for b in books for c in range(1, books[b].chapters + 1)})
        # Starts at creation, ends with Revelation; Job comes before Abraham.
        self.assertEqual(bible[0], ("GEN", 1))
        self.assertEqual(bible[-1], ("REV", 22))
        self.assertLess(bible.index(("JOB", 1)), bible.index(("GEN", 12)))

    def test_curated_plans_are_bundled(self):
        plans = {p["id"]: p for p in build_plans.build()["plans"]}
        self.assertEqual(len(plans["sermon-parables-7"]["days"]), 7)
        self.assertEqual(plans["psalms-comfort-7"]["days"][0],
                         [{"b": "PSA", "f": 23, "t": 23}, {"b": "PSA", "f": 121, "t": 121}])
        self.assertEqual(len(plans["life-of-jesus-89"]["days"]), 89)
        self.assertEqual(plans["life-of-jesus-89"]["days"][0], [{"b": "JHN", "f": 1, "t": 1}])
        self.assertEqual(len(plans["bible-chronological-365"]["days"]), 365)

    def test_bundled_plans_are_up_to_date(self):
        bundled = json.loads((HERE.parents[1] / "app/assets/plans/plans.json").read_text(encoding="utf-8"))
        self.assertEqual(bundled, build_plans.build(), "run python pipeline/build_plans.py")


if __name__ == "__main__":
    unittest.main()
