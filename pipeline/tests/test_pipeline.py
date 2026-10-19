import gzip
import hashlib
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
import validate  # noqa: E402
from abible import oshb, sblgnt, usfm, versification  # noqa: E402
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


OSIS_NS = 'xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace"'


class OshbTest(unittest.TestCase):
    def convert(self, verses: str) -> usfm.Book:
        xml = f'<osis {OSIS_NS}><osisText><div type="book" osisID="Gen"><chapter osisID="Gen.8">{verses}' \
              '</chapter></div></osisText></osis>'
        code, text = oshb.convert_book(xml)
        self.assertEqual(code, "GEN")
        return usfm.parse(text)

    def test_words_maqqef_and_sof_pasuq(self):
        b = self.convert('<verse osisID="Gen.8.1"><w lemma="5921 a" morph="HR">עַל</w><seg type="x-maqqef">־</seg>'
                         '<w lemma="d/776" morph="HTd/Ncbsa">הָ/אָֽרֶץ</w><seg type="x-sof-pasuq">׃</seg>\n'
                         '<note n="c">We read one or more accents in L differently.</note></verse>')
        self.assertEqual(b.verses[0].text, "עַל־הָאָֽרֶץ׃")

    def test_qere_in_text_and_ketiv_in_footnote(self):
        b = self.convert('<verse osisID="Gen.8.17"><w type="x-ketiv" lemma="3318" morph="HVhv2ms">הוצא</w>'
                         '<note type="variant"><catchWord>הוצא</catchWord><rdg type="x-qere">'
                         '<w lemma="3318" morph="HVhv2ms">הַיְצֵ֣א</w></rdg></note>\n'
                         '<w lemma="854" morph="HR/Sp2fs">אִתָּ֑/ךְ</w></verse>')
        v = b.verses[0]
        self.assertEqual(v.text, "הַיְצֵ֣א אִתָּ֑ךְ")
        self.assertIn(["n", "Ketiv: הוצא"], v.markup)

    def test_paragraph_marks_break_before_next_verse(self):
        b = self.convert('<verse osisID="Gen.8.1"><w lemma="1">א</w>\n<seg type="x-pe">פ</seg></verse>'
                         '<verse osisID="Gen.8.2"><w lemma="2">ב</w></verse>')
        self.assertEqual(b.verses[0].text, "א")
        self.assertEqual(b.verses[1].markup, [["p"], ["t", "ב"]])

    def test_verse_map(self):
        xml = '<verseMap><book osisID="Mal"><verse wlc="Mal.3.19" kjv="Mal.4.1" type="full"/>' \
              '<verse wlc="Ps.13.6!a" kjv="Ps.13.5" type="partial"/></book></verseMap>'
        self.assertEqual(oshb.verse_map(xml), [["MAL 3:19", "MAL 4:1"], ["PSA 13:6a", "PSA 13:5"]])


class SblgntTest(unittest.TestCase):
    def test_convert(self):
        xml = ('\ufeff<book id="1Co"><title>ΠΡΟΣ ΚΟΡΙΝΘΙΟΥΣ Α</title><p>'
               '<verse-number id="1 Corinthians 1:1">1:1</verse-number><w>Παῦλος</w><suffix></suffix>'
               '<prefix> ⸀</prefix><w>κλητὸς</w><suffix>, </suffix></p><p><w>ἀπόστολος</w><suffix>. </suffix>'
               '<verse-number id="1 Corinthians 1:2">2</verse-number><w>τῇ</w><suffix></suffix></p></book>')
        code, text = sblgnt.convert_book(xml, "1Cor")
        self.assertEqual(code, "1CO")
        b = usfm.parse(text)
        self.assertEqual(b.long_title, "ΠΡΟΣ ΚΟΡΙΝΘΙΟΥΣ Α")
        # Apparatus sigla are removed; a paragraph can start mid-verse.
        self.assertEqual(b.verses[0].markup, [["p"], ["t", "Παῦλος κλητὸς,"], ["p"], ["t", "ἀπόστολος."]])
        self.assertEqual(b.verses[1].markup, [["t", "τῇ"]])


def _book(code: str, verses: list[tuple[int, int, str]]) -> usfm.Book:
    return usfm.Book(code=code, verses=[usfm.Verse(c, v, None, [["t", t]]) for c, v, t in verses],
                     chapters_seen=sorted({c for c, _, _ in verses}))


class VersificationTest(unittest.TestCase):
    def test_unmapped_book_is_unchanged(self):
        b = _book("GEN", [(1, 1, "a")])
        self.assertIs(versification.remap(b, [["MAL 3:19", "MAL 4:1"]])[0], b)

    def test_moved_verses(self):
        b, warnings = versification.remap(_book("MAL", [(3, 18, "x"), (3, 19, "y"), (3, 20, "z")]),
                                          [["MAL 3:19", "MAL 4:1"], ["MAL 3:20", "MAL 4:2"]])
        self.assertEqual([(v.chapter, v.verse, v.text) for v in b.verses], [(3, 18, "x"), (4, 1, "y"), (4, 2, "z")])
        self.assertEqual(b.chapters_seen, [3, 4])
        self.assertEqual(warnings, [])

    def test_psalm_title_becomes_heading(self):
        src = _book("PSA", [(51, 1, "title1"), (51, 2, "title2"), (51, 3, "one"), (51, 4, "two")])
        b, _ = versification.remap(src, [["PSA 51:2", "PSA 51:1"], ["PSA 51:3", "PSA 51:1"],
                                         ["PSA 51:4", "PSA 51:2"]])
        self.assertEqual([(v.verse, v.text) for v in b.verses], [(1, "one"), (2, "two")])
        self.assertEqual([(h.chapter, h.verse, h.level, h.text) for h in b.headings], [(51, 1, 9, "title1 title2")])

    def test_verses_sharing_a_number_are_joined(self):
        # WLC 1 Sam 21:1 is the end of KJV 20:42.
        b, _ = versification.remap(_book("1SA", [(20, 42, "go in peace"), (21, 1, "and he arose"), (21, 2, "nob")]),
                                   [["1SA 21:1", "1SA 20:42"], ["1SA 21:2", "1SA 21:1"]])
        self.assertEqual([(v.chapter, v.verse, v.text) for v in b.verses],
                         [(20, 42, "go in peace and he arose"), (21, 1, "nob")])

    def test_split_verse_becomes_bridge(self):
        b, _ = versification.remap(_book("PSA", [(13, 5, "four"), (13, 6, "five and six")]),
                                   [["PSA 13:5", "PSA 13:4"], ["PSA 13:6a", "PSA 13:5"], ["PSA 13:6b", "PSA 13:6"]])
        self.assertEqual([(v.verse, v.label, v.text) for v in b.verses], [(4, None, "four"), (5, "5-6", "five and six")])

    def test_one_listed_part_keeps_the_other(self):
        b, _ = versification.remap(_book("1KI", [(18, 33, "a"), (18, 34, "b"), (18, 35, "c")]),
                                   [["1KI 18:34a", "1KI 18:33b"]])
        self.assertEqual([(v.verse, v.label, v.text) for v in b.verses], [(33, "33-34", "a b"), (35, None, "c")])

    def test_cross_chapter_verse_warns(self):
        _, warnings = versification.remap(_book("ISA", [(63, 19, "x"), (64, 1, "y")]),
                                          [["ISA 63:19b", "ISA 64:1"], ["ISA 64:1", "ISA 64:2"]])
        self.assertEqual(len(warnings), 1)

    def test_sblgnt_map(self):
        b, _ = versification.remap(_book("2CO", [(13, 11, "a"), (13, 12, "kiss. saints"), (13, 13, "grace")]),
                                   sblgnt.VERSE_MAP)
        self.assertEqual([(v.verse, v.label) for v in b.verses], [(11, None), (12, "12-13"), (14, None)])
        b, _ = versification.remap(_book("REV", [(12, 17, "a"), (12, 18, "stood"), (13, 1, "beast")]),
                                   sblgnt.VERSE_MAP)
        self.assertEqual([(v.chapter, v.verse, v.text) for v in b.verses], [(12, 17, "a"), (13, 1, "stood beast")])


class ValidateTest(unittest.TestCase):
    def test_testaments_and_hebrew_normalization(self):
        catalog = load_books()
        # Not NFC: dagesh (ccc 21) before qamats (ccc 18), as the WLC writes it.
        heb = _book("GEN", [(1, 1, "\u05d1\u05bc\u05b8")])
        nt = [code for code, b in catalog.items() if b.testament == "NT"]
        r = validate.validate_version("WLC", [heb], catalog, complete=False, language="hbo")
        self.assertEqual(r.errors, [])
        r = validate.validate_version("X", [heb], catalog, complete=False, language="eng")
        self.assertEqual(len(r.errors), 1)
        r = validate.validate_version("WLC", [heb], catalog, complete=True, testaments=("OT",), language="hbo")
        self.assertTrue(r.errors[0].startswith("missing books: EXO"))
        self.assertFalse(any(code in r.errors[0] for code in nt))


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
            db.close()

    def test_hebrew_and_greek(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / "content.db"
            self.assertEqual(build_db.build(FIXTURES, out, sample=True, allow_unverified=True), 0)
            db = sqlite3.connect(out)
            q = "SELECT vkey FROM verse_fts WHERE verse_fts MATCH ? AND version_id=?"
            # Unpointed queries find pointed text; prefixes and final forms are folded.
            self.assertIn(1001001, {r[0] for r in db.execute(q, (normalize("ארץ") + "*", "WLC"))})
            self.assertIn(43003016, {r[0] for r in db.execute(q, (normalize("ΚΌΣΜΟΝ") + "*", "SBLGNT"))})
            # Psalm 3: the title is a heading and WLC 3:2 is verse 1.
            heading = db.execute("SELECT level, text FROM heading WHERE version_id='WLC' AND vkey=19003001").fetchone()
            self.assertEqual(heading[0], 9)
            self.assertTrue(heading[1].startswith("מִזְמ֥וֹר"))
            text = db.execute("SELECT text FROM verse WHERE version_id='WLC' AND vkey=19003001").fetchone()[0]
            self.assertTrue(text.startswith("יְ֭הוָה"))
            # Original-language versions use Amharic book names.
            name = db.execute("SELECT short_name FROM book WHERE version_id='SBLGNT' AND code='JHN'").fetchone()[0]
            self.assertEqual(name, load_books()["JHN"].short)
            db.close()

    def test_packs(self):
        with tempfile.TemporaryDirectory() as d:
            out, packs = Path(d) / "content.db", Path(d) / "packs"
            self.assertEqual(build_db.build(FIXTURES, out, sample=True, allow_unverified=True, packs=packs), 0)
            # Versions with "bundle": false leave content.db for their own pack.
            db = sqlite3.connect(out)
            self.assertEqual({r[0] for r in db.execute("SELECT id FROM version")}, {"AMH1962", "WEB"})
            db.close()
            manifest = json.loads((packs / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual([p["id"] for p in manifest["packs"]], ["SBLGNT", "WLC"])
            for p in manifest["packs"]:
                data = (packs / p["file"]).read_bytes()
                self.assertEqual((len(data), hashlib.sha256(data).hexdigest()), (p["bytes"], p["sha256"]))
                raw = gzip.decompress(data)
                self.assertEqual(len(raw), p["db_bytes"])
                path = Path(d) / f"{p['id']}.db"
                path.write_bytes(raw)
                pack = sqlite3.connect(path)
                self.assertEqual([r[0] for r in pack.execute("SELECT id FROM version")], [p["id"]])
                self.assertEqual(pack.execute("SELECT value FROM meta WHERE key='pack'").fetchone()[0], p["id"])
                self.assertGreater(pack.execute("SELECT count(*) FROM verse_fts").fetchone()[0], 0)
                pack.close()
            self.assertEqual(list(packs.glob("*.db")), [])  # only the compressed packs remain

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

    def test_bundled_plans_are_up_to_date(self):
        bundled = json.loads((HERE.parents[1] / "app/assets/plans/plans.json").read_text(encoding="utf-8"))
        self.assertEqual(bundled, build_plans.build(), "run python pipeline/build_plans.py")


if __name__ == "__main__":
    unittest.main()
