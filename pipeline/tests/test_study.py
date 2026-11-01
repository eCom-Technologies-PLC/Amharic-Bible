"""Original-language texts and study resources (lexicon, cross-references,
people/places/events, commentary)."""

import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import build_db  # noqa: E402
import package_packs  # noqa: E402
from abible import original, study  # noqa: E402
from abible.catalog import load_books  # noqa: E402

FIXTURES = HERE / "fixtures" / "usfm"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


class HebrewTest(unittest.TestCase):
    def setUp(self):
        wlc = FIXTURES / "WLC"
        self.vmap = original.load_versemap(read(wlc / "VerseMap.xml"))
        self.gen = original.parse_oshb(read(wlc / "Gen.xml"), self.vmap)
        self.ps = original.parse_oshb(read(wlc / "Ps.xml"), self.vmap)

    def test_words(self):
        first = self.gen.words[(1, 1)][0]
        self.assertEqual((first.text, first.strongs, first.lemma, first.morph),
                         ("בְּרֵאשִׁ֖ית", "H7225", "b/7225", "HR/Ncfsa"))
        self.assertTrue(self.gen.verses[0].text.endswith("׃"))  # sof pasuq kept
        self.assertIn("כָּל־הַחַיָּ֨ה", self.gen.verses[3].text)  # maqqef joins words

    def test_aramaic_words_are_tagged(self):
        jegar, sahadutha = self.gen.words[(31, 47)][3:5]
        self.assertEqual((jegar.morph, sahadutha.morph), ("ANp", "ANp"))

    def test_qere(self):
        self.assertEqual([(v.chapter, v.verse, v.source, v.reading) for v in self.gen.variants],
                         [(8, 17, "qere", "הַיְצֵ֣א")])

    def test_psalm_titles_become_verse_zero(self):
        keys = [(v.chapter, v.verse) for v in self.ps.verses]
        # WLC Ps 3:1 is the superscription; WLC 3:2 is the KJV's 3:1.
        self.assertEqual(keys[:3], [(3, 0), (3, 1), (3, 2)])
        self.assertIn((23, 1), keys)  # Ps 23 numbers the same in both
        self.assertEqual(self.ps.chapters_seen, [3, 23])

    def test_two_verse_superscription(self):
        vmap = {("Ps", 51, 3): (51, 1), ("Ps", 51, 4): (51, 2)}
        self.assertEqual([original._map_verse(vmap, "Ps", 51, v) for v in (1, 2, 3)],
                         [(51, 0), (51, 0), (51, 1)])
        self.assertEqual(original._map_verse(vmap, "Ps", 50, 1), (50, 1))

    def test_whole_chapter_shift(self):
        # Malachi 3:19-24 in the WLC are 4:1-6 in the KJV.
        vmap = {("Mal", 3, 19): (4, 1)}
        self.assertEqual(original._map_verse(vmap, "Mal", 3, 19), (4, 1))
        self.assertEqual(original._map_verse(vmap, "Mal", 3, 18), (3, 18))


class GreekTest(unittest.TestCase):
    def setUp(self):
        rp = FIXTURES / "RP2018"
        self.jhn = original.parse_rp("JOH", read(rp / "parsed" / "JOH.csv"), read(rp / "text" / "JOH.csv"))

    def test_accented_words_align_with_tags(self):
        self.assertEqual(self.jhn.code, "JHN")
        w = self.jhn.words[(1, 1)][4]
        self.assertEqual((w.text, w.strongs, w.lemma, w.morph), ("λόγος", "G3056", "λογος", "N-NSM"))
        # Every word takes the accented form, not the unaccented parsing form.
        self.assertTrue(all(w.text != w.lemma for ws in self.jhn.words.values() for w in ws if len(w.lemma) > 1))

    def test_apparatus(self):
        by = {(v.chapter, v.verse): v for v in self.jhn.variants}
        self.assertEqual((by[(1, 18)].source, by[(1, 18)].base, by[(1, 18)].reading),
                         ("NA", "ὁ μονογενὴς υἱός", "μονογενὴς θεός"))
        self.assertEqual((by[(3, 16)].base, by[(3, 16)].reading), ("αὐτοῦ", ""))  # NA omits the word
        self.assertEqual((by[(5, 4)].base, by[(5, 4)].reading), ("", ""))  # NA omits the verse
        self.assertNotIn("{", " ".join(v.text for v in self.jhn.verses))


class ResourceTest(unittest.TestCase):
    def test_strongs(self):
        rows = {e.id: e for e in study.load_strongs(read(FIXTURES / "STRONGS" / "hebrew.js"))}
        self.assertEqual(rows["H7225"].lemma, "רֵאשִׁית")
        self.assertEqual(rows["H7225"].lang, "heb")
        self.assertEqual(rows["H3026"].lang, "arc")  # "(Aramaic)" in the derivation

    def test_cross_references(self):
        rows = study.load_openbible_xrefs(read(FIXTURES / "OBXREF" / "cross_references.txt"), load_books())
        self.assertIn((1001001, 43001001, 43001003, 304), rows)

    def test_hcf_filters(self):
        cat = load_books()
        entry = '[[commentary]]\nquote="""\nText.\n"""\nsource_title="Work"\n\n[[commentary]]\nquote="No source."\n'
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            for author, year, tradition in (("Old", 400, "Early Fathers (Pre-Nicaea)"),
                                            ("New", 1950, "Reformation & Modern"),
                                            ("Late", 1600, "Reformation & Modern")):
                (root / author).mkdir()
                (root / author / "metadata.toml").write_text(
                    f"default_year={year}\nfather_category='{tradition}'\n", encoding="utf-8")
                (root / author / "John 3_16-17.toml").write_text(entry, encoding="utf-8")
                (root / author / "Sirach 1_1.toml").write_text(entry, encoding="utf-8")  # outside the 66 books
            rows = study.load_hcf(root, cat, max_year=1700, exclude={"Reformation & Modern"})
            self.assertEqual([(c.author, c.vkey_start, c.vkey_end, c.work, c.text) for c in rows],
                             [("Old", 43003016, 43003017, "Work", "Text.")])

    def test_missing_lexicon_entries_are_reported(self):
        db = sqlite3.connect(":memory:")
        db.executescript(build_db.SCHEMA)
        db.execute("INSERT INTO lexicon (id) VALUES ('H1')")
        db.execute("INSERT INTO word VALUES ('WLC', 1001001, 0, 'x', 'H1', NULL, NULL)")
        self.assertEqual(build_db.check_study_links([db]), [])
        db.execute("INSERT INTO word VALUES ('WLC', 1001001, 1, 'y', 'H2', NULL, NULL)")
        self.assertEqual(len(build_db.check_study_links([db])), 1)
        db.close()


class BuildTest(unittest.TestCase):
    def test_sample_db_has_study_data(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / "content.db"
            self.assertEqual(build_db.build(FIXTURES, out, sample=True, allow_unverified=True), 0)
            db = sqlite3.connect(out)
            q = "SELECT vkey FROM verse_fts WHERE verse_fts MATCH ? AND version_id=?"
            # Search ignores accents and vowel points.
            self.assertIn(43001001, {r[0] for r in db.execute(q, ('"λογοσ"*', "RP2018"))})
            self.assertIn(1001001, {r[0] for r in db.execute(q, ('"בראשית"*', "WLC"))})
            self.assertEqual(db.execute("SELECT coverage FROM version WHERE id='WLC'").fetchone()[0], "OT")
            self.assertEqual(db.execute("SELECT COUNT(*) FROM word WHERE strongs='G3056'").fetchone()[0], 3)
            self.assertIn("first", db.execute("SELECT definition FROM lexicon WHERE id='H7225'").fetchone()[0])
            self.assertIn((43001001, 43001003), set(db.execute("SELECT to_start, to_end FROM xref WHERE vkey=1001001")))
            self.assertIn("event:1", {r[0] for r in db.execute("SELECT entity_id FROM entity_verse WHERE vkey=1001001")})
            self.assertEqual(db.execute("SELECT author FROM commentary WHERE vkey_start <= 43003016 "
                                        "AND vkey_end >= 43003016").fetchone()[0], "Augustine of Hippo")
            self.assertEqual(db.execute("SELECT license_status FROM resource WHERE id='HCF'").fetchone()[0], "verify")
            db.close()

    def test_unbundled_resources_go_to_packs(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / "content.db"
            rc = build_db.build(FIXTURES, out, sample=False, allow_unverified=False, only=["STRONGS", "OBXREF"])
            self.assertEqual(rc, 0)
            main = sqlite3.connect(out)
            self.assertEqual(main.execute("SELECT COUNT(*) FROM lexicon").fetchone()[0], 0)
            main.close()
            pack = sqlite3.connect(Path(d) / "packs" / "STRONGS.db")
            self.assertGreater(pack.execute("SELECT COUNT(*) FROM lexicon").fetchone()[0], 100)
            self.assertEqual(pack.execute("SELECT value FROM meta WHERE key='pack'").fetchone()[0], "STRONGS")
            pack.close()

    def test_unverified_resource_is_refused(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / "content.db"
            self.assertEqual(build_db.build(FIXTURES, out, sample=True, allow_unverified=False, only=["HCF"]), 1)
            self.assertFalse(out.exists())


class PackageTest(unittest.TestCase):
    def test_manifest_and_compressed_packs(self):
        import gzip
        import hashlib
        import json
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / "content.db"
            self.assertEqual(build_db.build(FIXTURES, out, sample=False, allow_unverified=False,
                                            only=["STRONGS", "OBXREF"]), 0)
            packs = Path(d) / "packs"
            manifest = package_packs.package(packs, packs)
            self.assertEqual(manifest["schema_version"], build_db.SCHEMA_VERSION)
            self.assertEqual(json.loads((packs / "manifest.json").read_text())["packs"], manifest["packs"])
            by = {p["id"]: p for p in manifest["packs"]}
            self.assertEqual(set(by), {"STRONGS", "OBXREF"})
            s = by["STRONGS"]
            self.assertEqual((s["kind"], s["file"], s["license_status"]), ("lexicon", "STRONGS.db.gz", "confirmed"))
            gz = (packs / "STRONGS.db.gz").read_bytes()
            self.assertEqual(hashlib.sha256(gz).hexdigest(), s["sha256"])
            self.assertEqual(len(gz), s["gz_bytes"])
            self.assertEqual(gzip.decompress(gz), (packs / "STRONGS.db").read_bytes())
            self.assertEqual(len(gzip.decompress(gz)), s["bytes"])

    def test_version_pack_is_described_as_a_version(self):
        with tempfile.TemporaryDirectory() as d:
            src = Path(d) / "src"
            (src / "WLC").mkdir(parents=True)
            for f in (FIXTURES / "WLC").iterdir():
                (src / "WLC" / f.name).write_bytes(f.read_bytes())
            out = Path(d) / "content.db"
            # A non-sample build of two books fails validation, so build the sample and mark it as a pack.
            self.assertEqual(build_db.build(src, out, sample=True, allow_unverified=False), 0)
            db = sqlite3.connect(out)
            db.execute("INSERT INTO meta VALUES ('pack', 'WLC')")
            db.commit()
            db.close()
            packs = Path(d) / "packs"
            packs.mkdir()
            out.rename(packs / "WLC.db")
            entry = package_packs.package(packs, packs)["packs"][0]
            self.assertEqual((entry["id"], entry["kind"], entry["language"]), ("WLC", "version", "heb"))


if __name__ == "__main__":
    unittest.main()
