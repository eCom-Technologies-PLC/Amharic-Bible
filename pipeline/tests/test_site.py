"""Static chapter pages (build_site.py), built from the app's sample database."""
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import build_site  # noqa: E402

SAMPLE_DB = Path(__file__).resolve().parents[2] / 'app' / 'assets' / 'content' / 'content.db'


class SiteTest(unittest.TestCase):
    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        self.out = Path(self._dir.name)

    def tearDown(self):
        self._dir.cleanup()

    def page(self, *parts):
        return (self.out / 'bible' / Path(*parts) / 'index.html').read_text(encoding='utf-8')

    def test_chapter_pages_have_text_anchors_and_a_way_into_the_app(self):
        counts = build_site.build_site(SAMPLE_DB, self.out, site_url='https://bible.example.org/')
        self.assertEqual(counts['WEB'], 3)
        john = self.page('web', 'jhn', '3')
        self.assertIn('<title>John 3 · Amharic Bible (WEB)</title>', john)
        self.assertIn('id="v16"', john)  # verses can be linked: .../jhn/3/#v16
        self.assertIn('<span class="wj">For God so loved the world', john)
        self.assertIn('href="../../../../read?ref=JHN.3"', john)  # into the app, whatever the site's base path
        self.assertIn('<link rel="canonical" href="https://bible.example.org/bible/web/jhn/3/">', john)
        self.assertIn('rel="prev" href="../../../../bible/web/psa/23/"', john)  # the previous chapter that exists
        self.assertIn('id="n1"', john)  # its footnote, listed under the text
        self.assertIn('public domain', john)  # the version's credit

    def test_poetry_headings_and_right_to_left_text(self):
        build_site.build_site(SAMPLE_DB, self.out)
        psalm = self.page('web', 'psa', '23')
        self.assertIn('<p class="d">A Psalm by David.</p>', psalm)  # a psalm's own title
        self.assertIn('class="q1"', psalm)
        self.assertIn('<main lang="he" dir="rtl">', self.page('wlc', 'psa', '23'))
        self.assertIn('<main lang="grc">', self.page('rp2018', 'jhn', '1'))

    def test_indexes_and_sitemap(self):
        build_site.build_site(SAMPLE_DB, self.out, site_url='https://bible.example.org')
        self.assertIn('href="jhn/"', self.page('web'))
        self.assertIn('href="3/"', self.page('web', 'jhn'))
        self.assertIn('href="web/"', (self.out / 'bible' / 'index.html').read_text(encoding='utf-8'))
        sitemap = (self.out / 'sitemap.xml').read_text(encoding='utf-8')
        self.assertIn('<loc>https://bible.example.org/bible/web/jhn/3/</loc>', sitemap)
        self.assertIn('Sitemap: https://bible.example.org/sitemap.xml', (self.out / 'robots.txt').read_text())

    def test_versions_whose_license_needs_checking_are_left_out_unless_allowed(self):
        counts = build_site.build_site(SAMPLE_DB, self.out)
        self.assertNotIn('AMH1962', counts)
        self.assertFalse((self.out / 'bible' / 'amh1962').exists())
        counts = build_site.build_site(SAMPLE_DB, self.out, versions=['AMH1962'], allow_unverified=True)
        self.assertEqual(list(counts), ['AMH1962'])
        amharic = self.page('amh1962', 'jhn', '3')
        self.assertIn('<html lang="am">', amharic)
        self.assertIn('በመተግበሪያው ክፈት', amharic)  # "Open in the app", in Amharic
        self.assertIn('<span>የዮሐንስ ወንጌል</span>ዮሐንስ 3', amharic)

    def test_no_sitemap_without_the_sites_address(self):
        build_site.build_site(SAMPLE_DB, self.out)
        self.assertFalse((self.out / 'sitemap.xml').exists())
        self.assertNotIn('rel="canonical"', self.page('web', 'jhn', '3'))

    def test_the_release_file_list_is_stamped_into_the_service_worker(self):
        (self.out / 'sw.js').write_text('const RELEASE = null;\nconst CACHE = 1;\n', encoding='utf-8')
        (self.out / 'main.dart.js').write_text('main', encoding='utf-8')
        (self.out / 'assets').mkdir()
        (self.out / 'assets' / 'FontManifest.json').write_text('[]', encoding='utf-8')
        (self.out / 'assets' / 'NOTICES').write_text('licenses', encoding='utf-8')
        (self.out / 'canvaskit').mkdir()
        (self.out / 'canvaskit' / 'canvaskit.wasm').write_bytes(b'wasm')
        build_site.build_site(SAMPLE_DB, self.out)  # the pages are not part of the release
        release = build_site.stamp_release(self.out)
        sw = (self.out / 'sw.js').read_text(encoding='utf-8')
        listed = json.loads(sw.split('const RELEASE = ', 1)[1].split(';\n', 1)[0])
        self.assertEqual(listed['id'], release)
        self.assertEqual(set(listed['files']), {'main.dart.js', 'assets/FontManifest.json'})
        self.assertIn('const CACHE = 1;', sw)  # the rest of the worker is untouched
        self.assertIsNone(build_site.stamp_release(self.out))  # once per build
        # A changed file is a new release.
        before = build_site.release_files(self.out)['main.dart.js']
        (self.out / 'main.dart.js').write_text('main, changed', encoding='utf-8')
        self.assertNotEqual(build_site.release_files(self.out)['main.dart.js'], before)

    def test_the_release_names_its_engine_and_lists_paths_as_urls(self):
        (self.out / 'sw.js').write_text('const RELEASE = null;\n', encoding='utf-8')
        (self.out / 'flutter_bootstrap.js').write_text(
            '_flutter.buildConfig = {"engineRevision":"1a2b3c","builds":[]};', encoding='utf-8')
        (self.out / 'assets').mkdir()
        (self.out / 'assets' / 'ዮሐንስ 3.png').write_bytes(b'png')
        build_site.stamp_release(self.out)
        sw = (self.out / 'sw.js').read_text(encoding='utf-8')
        listed = json.loads(sw.split('const RELEASE = ', 1)[1].rsplit(';', 1)[0])
        self.assertEqual(listed['engine'], '1a2b3c')  # CanvasKit for other engines is dropped
        # As in the address the browser asks for, so the worker finds it.
        self.assertIn('assets/%E1%8B%AE%E1%88%90%E1%8A%95%E1%88%B5%203.png', listed['files'])

    def test_the_release_line_matches_the_service_worker(self):
        sw = Path(__file__).resolve().parents[2] / 'app' / 'web' / 'sw.js'
        self.assertIn(build_site.RELEASE_PLACEHOLDER, sw.read_text(encoding='utf-8'))


if __name__ == '__main__':
    unittest.main()
