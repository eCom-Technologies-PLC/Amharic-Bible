#!/usr/bin/env python3
"""Static chapter pages for the web app's site.

The web app is drawn by Flutter on a canvas, which search engines and link
previews can't read. This writes a plain HTML page for every chapter of the
chosen versions, next to the app's own files, so that "ዮሐንስ 3:16" can be
found, the page opens at once on a slow connection, and "Open in the app"
leads into the reader. Pages live at bible/<version>/<book>/<chapter>/, with
an index of versions, books and chapters, and a sitemap when the site's
address is given.

Run it on a finished web build:

    flutter build web --release            (in app/)
    python pipeline/build_site.py --db app/assets/content/content.db --out app/build/web \\
        --site-url https://bible.example.org

Versions whose license still says "verify" are left out unless
--allow-unverified is given, as in build_db.py.

It also stamps the release's file list into the built service worker (sw.js),
which then keeps those files and the page when it installs and starts the app
from them, so a repeat visit waits for nothing, however slow the connection.
Run it once per build: a build that already has its list is left as it is.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import sqlite3
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import quote

# Text for the pages, in Amharic for Amharic versions and in English otherwise.
LABELS = {
    'am': {
        'app': 'መጽሐፍ ቅዱስ',
        'open': 'በመተግበሪያው ክፈት',
        'books': 'መጻሕፍት',
        'versions': 'ትርጉሞች',
        'ot': 'ብሉይ ኪዳን',
        'nt': 'አዲስ ኪዳን',
        'notes': 'የግርጌ ማስታወሻዎች',
        'previous': 'ያለፈው ምዕራፍ',
        'next': 'ቀጣይ ምዕራፍ',
        'chapters': 'ምዕራፎች',
    },
    'en': {
        'app': 'Amharic Bible',
        'open': 'Open in the app',
        'books': 'Books',
        'versions': 'Versions',
        'ot': 'Old Testament',
        'nt': 'New Testament',
        'notes': 'Notes',
        'previous': 'Previous chapter',
        'next': 'Next chapter',
        'chapters': 'Chapters',
    },
}

# Language tags for the versions' text (versions.json uses ISO 639-3); Hebrew
# and Aramaic read right to left.
LANG_TAGS = {'amh': 'am', 'eng': 'en', 'deu': 'de', 'grc': 'grc', 'heb': 'he', 'arc': 'arc'}
RTL = {'heb', 'arc'}

# The app's reading colors (app_theme.dart, app_colors.dart), light and dark.
STYLE = """
:root{--page:#F5F3EE;--ink:#1B1C19;--muted:#4B4A43;--primary:#1E6B4E;--rubric:#9B2F23;--wj:#A8261E;--rule:#D9D4C7}
@media (prefers-color-scheme:dark){:root{--page:#131614;--ink:#E2E3DD;--muted:#BFC6BF;--primary:#8ED5B3;--rubric:#FFB4A6;--wj:#FF9D93;--rule:#323735}}
html{background:var(--page);color:var(--ink)}
body{margin:0 auto;max-width:680px;padding:16px 16px 48px;font:19px/1.7 "Noto Serif Ethiopic","Abyssinica SIL","Nyala","Kefa","Ebrima","Noto Serif","Noto Serif Hebrew",serif}
header,footer,nav,.open,.index{font:15px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,"Noto Sans Ethiopic",sans-serif}
a{color:var(--primary)}
header{display:flex;flex-wrap:wrap;gap:8px;align-items:baseline;padding-bottom:8px;border-bottom:1px solid var(--rule)}
header a{text-decoration:none}
.book{margin:24px 0 0;text-align:center;color:var(--rubric);font-weight:600}
h1{margin:0 0 8px;text-align:center;font-weight:400;font-size:40px;line-height:1.25}
h1 span{display:block;font-size:19px;color:var(--rubric);font-weight:600}
h2{font-size:19px;margin:24px 0 8px}
.d{color:var(--muted);letter-spacing:.02em;font-size:15px}
p{margin:8px 0}
.q1,.q2,.q3{margin:0}.q1{margin-inline-start:12px}.q2{margin-inline-start:36px}.q3{margin-inline-start:60px}
.v{color:var(--primary);font-size:.6em;vertical-align:super;margin-inline-end:.15em}
.wj{color:var(--wj)}
sup a{text-decoration:none}
nav.chapters{display:flex;justify-content:space-between;gap:16px;margin:32px 0 16px}
.open a{display:inline-block;padding:12px 24px;border-radius:12px;background:var(--primary);color:var(--page);text-decoration:none;font-weight:600}
.open{text-align:center;margin:24px 0}
ol.notes{font-size:15px;color:var(--muted)}
footer{margin-top:32px;padding-top:8px;border-top:1px solid var(--rule);color:var(--muted)}
.index ul{list-style:none;padding:0;display:flex;flex-wrap:wrap;gap:8px}
.index li a{display:inline-block;min-width:48px;padding:12px;text-align:center;border:1px solid var(--rule);border-radius:12px;text-decoration:none}
.index h2{font-family:inherit}
"""


@dataclass(frozen=True)
class Version:
    id: str
    abbrev: str
    name: str
    language: str  # ISO 639-3, as in versions.json
    attribution: str
    license_status: str

    @property
    def ui(self) -> str:
        return 'am' if self.language == 'amh' else 'en'

    @property
    def slug(self) -> str:
        return self.id.lower()


@dataclass(frozen=True)
class Book:
    code: str
    num: int
    name: str
    short_name: str
    testament: str

    @property
    def slug(self) -> str:
        return self.code.lower()


def _e(text: str) -> str:
    return html.escape(text, quote=True)


def _page(*, lang: str, title: str, description: str, root: str, canonical: str | None,
          body: str, site_name: str) -> str:
    """A whole HTML page. [root] is the relative way back to the site's root."""
    meta = [
        f'<meta name="description" content="{_e(description)}">',
        '<meta property="og:type" content="article">',
        f'<meta property="og:title" content="{_e(title)}">',
        f'<meta property="og:description" content="{_e(description)}">',
        f'<meta property="og:site_name" content="{_e(site_name)}">',
        f'<meta property="og:locale" content="{"am_ET" if lang == "am" else "en_US"}">',
    ]
    if canonical:
        meta += [f'<link rel="canonical" href="{_e(canonical)}">', f'<meta property="og:url" content="{_e(canonical)}">']
    head = '\n'.join(meta)
    return f"""<!DOCTYPE html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{_e(title)}</title>
{head}
<meta name="theme-color" content="#F5F3EE" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#131614" media="(prefers-color-scheme: dark)">
<link rel="icon" href="{root}favicon.png">
<style>{STYLE}</style>
</head>
<body>
{body}
</body>
</html>
"""


def render_chapter(
    version: Version,
    book: Book,
    chapter: int,
    verses: list[tuple[int, str | None, str, str]],
    headings: dict[int, list[tuple[int, str]]],
    previous: tuple[Book, int] | None,
    following: tuple[Book, int] | None,
    site_url: str | None = None,
) -> str:
    """One chapter: [verses] are (vkey, label, text, markup) in order, [headings]
    by vkey as (level, text); [previous]/[following] are neighbouring chapters."""
    t = LABELS[version.ui]
    root = '../../../../'
    blocks: list[str] = []
    notes: list[str] = []
    current: list[str] | None = None
    current_class = ''

    def close() -> None:
        nonlocal current
        if current:
            cls = f' class="{current_class}"' if current_class else ''
            blocks.append(f'<p{cls}>{"".join(current).strip()}</p>')
        current = None

    def open_block(cls: str) -> None:
        nonlocal current, current_class
        close()
        current = []
        current_class = cls

    for vkey, label, text, markup in verses:
        for level, heading in headings.get(vkey, []):
            close()
            # Level 9 marks a psalm's own title (\d); others are section headings.
            blocks.append(f'<p class="d">{_e(heading)}</p>' if level == 9 else f'<h2>{_e(heading)}</h2>')
        number = label or str(vkey % 1000)
        number_pending = True
        tokens = json.loads(markup) if markup else [['t', text]]
        for tok in tokens:
            kind = tok[0]
            if kind == 'p':
                open_block('')
                continue
            if kind == 'q':
                open_block(f'q{min(int(tok[1]) if len(tok) > 1 else 1, 3)}')
                continue
            if current is None:
                open_block('')
            if number_pending:
                current.append(f' <span class="v" id="v{vkey % 1000}">{_e(number)}</span>')
                number_pending = False
            if kind == 'n':
                notes.append(tok[1])
                n = len(notes)
                current.append(f'<sup><a href="#n{n}" id="r{n}">{n}</a></sup>')
            elif kind == 'wj':
                current.append(f'<span class="wj">{_e(tok[1])}</span>')
            else:
                current.append(_e(tok[1]))
    close()

    title = f'{book.short_name} {chapter}'
    plain = ' '.join(text for _, _, text, _ in verses)
    description = plain if len(plain) <= 160 else plain[:157].rsplit(' ', 1)[0] + '…'
    canonical = f'{site_url}/bible/{version.slug}/{book.slug}/{chapter}/' if site_url else None

    def link(target: tuple[Book, int] | None, rel: str, label: str) -> str:
        if target is None:
            return '<span></span>'
        b, c = target
        href = f'{root}bible/{version.slug}/{b.slug}/{c}/'
        arrow = f'‹ {_e(b.short_name)} {c}' if rel == 'prev' else f'{_e(b.short_name)} {c} ›'
        return f'<a rel="{rel}" href="{href}" title="{_e(label)}">{arrow}</a>'

    notes_html = ''
    if notes:
        items = ''.join(f'<li id="n{i}"><a href="#r{i}">↑</a> {_e(n)}</li>' for i, n in enumerate(notes, 1))
        notes_html = f'<h2>{_e(t["notes"])}</h2><ol class="notes">{items}</ol>'
    # The chapter is in the version's language (Hebrew right to left); the
    # page around it is in the reader's.
    text_lang = LANG_TAGS.get(version.language, version.language)
    text_dir = ' dir="rtl"' if version.language in RTL else ''
    long_name = f'<span>{_e(book.name)}</span>' if book.name != book.short_name else ''
    body = f"""<header><a href="{root}">{_e(t['app'])}</a><span>·</span><a href="../../">{_e(version.abbrev)}</a><span>·</span><a href="../">{_e(book.name)}</a></header>
<main lang="{text_lang}"{text_dir}>
<h1>{long_name}{_e(title)}</h1>
{chr(10).join(blocks)}
{notes_html}
</main>
<p class="open"><a href="{root}read?ref={book.code}.{chapter}">{_e(t['open'])}</a></p>
<nav class="chapters">{link(previous, 'prev', t['previous'])}{link(following, 'next', t['next'])}</nav>
<footer>{_e(version.name)} ({_e(version.abbrev)}). {_e(version.attribution)}</footer>"""
    return _page(lang=version.ui, title=f'{title} · {t["app"]} ({version.abbrev})', description=description,
                 root=root, canonical=canonical, body=body, site_name=t['app'])


def _chapter_list(chapters: list[int]) -> str:
    return '<ul>' + ''.join(f'<li><a href="{c}/">{c}</a></li>' for c in chapters) + '</ul>'


def build_site(db_path: Path, out: Path, versions: list[str] | None = None, site_url: str | None = None,
               allow_unverified: bool = False) -> dict[str, int]:
    """Writes the pages under out/bible/ (and a sitemap when [site_url] is
    given); returns how many chapter pages each version got."""
    site_url = site_url.rstrip('/') if site_url else None
    db = sqlite3.connect(db_path)
    try:
        rows = db.execute(
            'SELECT id, abbrev, name, language, attribution, license_status FROM version ORDER BY id'
        ).fetchall()
        chosen = []
        for r in rows:
            v = Version(*r)
            if versions and v.id not in versions:
                continue
            if v.license_status != 'confirmed' and not allow_unverified:
                print(f'skipping {v.id}: license is "{v.license_status}" (use --allow-unverified)', file=sys.stderr)
                continue
            chosen.append(v)

        counts: dict[str, int] = {}
        urls: list[str] = []
        for v in chosen:
            books = [
                Book(*r)
                for r in db.execute(
                    'SELECT code, num, name, short_name, testament FROM book WHERE version_id = ? ORDER BY ordinal, num',
                    (v.id,),
                )
            ]
            by_num = {b.num: b for b in books}
            present: list[tuple[Book, int]] = []
            for (key,) in db.execute(
                'SELECT DISTINCT vkey / 1000 FROM verse WHERE version_id = ? ORDER BY vkey / 1000', (v.id,)
            ):
                book = by_num.get(key // 1000)
                if book is not None:
                    present.append((book, key % 1000))
            # Canonical order: book order first, then chapter.
            order = {b.code: i for i, b in enumerate(books)}
            present.sort(key=lambda bc: (order[bc[0].code], bc[1]))

            headings: dict[int, list[tuple[int, str]]] = {}
            for vkey, level, text in db.execute(
                'SELECT vkey, level, text FROM heading WHERE version_id = ? ORDER BY vkey, rowid', (v.id,)
            ):
                headings.setdefault(vkey, []).append((level, text))

            base = out / 'bible' / v.slug
            for i, (book, chapter) in enumerate(present):
                lo, hi = book.num * 1_000_000 + chapter * 1000, book.num * 1_000_000 + chapter * 1000 + 999
                verses = db.execute(
                    'SELECT vkey, label, text, markup FROM verse WHERE version_id = ? AND vkey BETWEEN ? AND ? '
                    'ORDER BY vkey',
                    (v.id, lo, hi),
                ).fetchall()
                page = render_chapter(
                    v, book, chapter, verses, headings,
                    present[i - 1] if i > 0 else None,
                    present[i + 1] if i + 1 < len(present) else None,
                    site_url,
                )
                target = base / book.slug / str(chapter) / 'index.html'
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(page, encoding='utf-8')
                if site_url:
                    urls.append(f'{site_url}/bible/{v.slug}/{book.slug}/{chapter}/')
            counts[v.id] = len(present)

            # A page per book (its chapters) and one for the version (its books).
            t = LABELS[v.ui]
            chapters_of: dict[str, list[int]] = {}
            for book, chapter in present:
                chapters_of.setdefault(book.code, []).append(chapter)
            for book in books:
                if book.code not in chapters_of:
                    continue
                body = (f'<header><a href="../../../">{_e(t["app"])}</a><span>·</span><a href="../">{_e(v.abbrev)}</a>'
                        f'</header><main class="index"><h1>{_e(book.name)}</h1><h2>{_e(t["chapters"])}</h2>'
                        f'{_chapter_list(chapters_of[book.code])}</main>')
                (base / book.slug).mkdir(parents=True, exist_ok=True)
                (base / book.slug / 'index.html').write_text(
                    _page(lang=v.ui, title=f'{book.name} · {t["app"]} ({v.abbrev})', description=book.name,
                          root='../../../', canonical=f'{site_url}/bible/{v.slug}/{book.slug}/' if site_url else None,
                          body=body, site_name=t['app']),
                    encoding='utf-8',
                )
            sections = []
            for testament, label in (('OT', t['ot']), ('NT', t['nt'])):
                items = ''.join(
                    f'<li><a href="{b.slug}/">{_e(b.short_name)}</a></li>'
                    for b in books
                    if b.testament == testament and b.code in chapters_of
                )
                if items:
                    sections.append(f'<h2>{_e(label)}</h2><ul>{items}</ul>')
            body = (f'<header><a href="../../">{_e(t["app"])}</a></header><main class="index"><h1>{_e(v.name)}</h1>'
                    f'{"".join(sections)}</main><footer>{_e(v.attribution)}</footer>')
            base.mkdir(parents=True, exist_ok=True)
            (base / 'index.html').write_text(
                _page(lang=v.ui, title=f'{v.name} · {t["app"]}', description=v.name, root='../../',
                      canonical=f'{site_url}/bible/{v.slug}/' if site_url else None, body=body, site_name=t['app']),
                encoding='utf-8',
            )

        # All versions.
        items = ''.join(f'<li><a href="{v.slug}/">{_e(v.abbrev)}</a> {_e(v.name)}</li>' for v in chosen)
        index = (out / 'bible' / 'index.html')
        index.parent.mkdir(parents=True, exist_ok=True)
        t = LABELS['am']
        index.write_text(
            _page(lang='am', title=f'{t["app"]} · {LABELS["en"]["app"]}', description=t['versions'], root='../',
                  canonical=f'{site_url}/bible/' if site_url else None,
                  body=f'<header><a href="../">{_e(t["app"])}</a></header><main class="index"><h1>'
                       f'{_e(t["versions"])}</h1><ul>{items}</ul></main>',
                  site_name=t['app']),
            encoding='utf-8',
        )

        if site_url:
            entries = ''.join(f'<url><loc>{_e(u)}</loc></url>' for u in urls)
            (out / 'sitemap.xml').write_text(
                f'<?xml version="1.0" encoding="UTF-8"?>\n'
                f'<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">{entries}</urlset>\n',
                encoding='utf-8',
            )
            (out / 'robots.txt').write_text(f'User-agent: *\nAllow: /\nSitemap: {site_url}/sitemap.xml\n', encoding='utf-8')
        return counts
    finally:
        db.close()


# The line in web/sw.js that the release's file list replaces.
RELEASE_PLACEHOLDER = 'const RELEASE = null;'

# Not part of the release the worker keeps: these pages, the local copies of
# CanvasKit (the app loads it from Google's servers), the licenses page's text
# (fetched when opened), Flutter's own loader and retired worker, and this
# worker itself.
_NOT_IN_RELEASE_DIRS = ('bible/', 'canvaskit/')
_NOT_IN_RELEASE = {
    'sw.js', 'flutter_service_worker.js', 'flutter.js', 'sitemap.xml', 'robots.txt', '.last_build_id',
    'assets/NOTICES',
}


def release_files(out: Path) -> dict[str, str]:
    """The web build's files the app needs, each with a short content hash.
    Paths are written as in a URL (percent-encoded), as the worker sees them."""
    files = {}
    for path in sorted(out.rglob('*')):
        if not path.is_file():
            continue
        rel = path.relative_to(out).as_posix()
        if rel in _NOT_IN_RELEASE or rel.startswith(_NOT_IN_RELEASE_DIRS) or rel.endswith(('.map', '.symbols')):
            continue
        files[_url_path(rel)] = hashlib.sha256(path.read_bytes()).hexdigest()[:12]
    return files


def _url_path(rel: str) -> str:
    """A build path as it appears in the address the browser asks for."""
    return quote(rel, safe="/!$&'()*+,;=:@")


def build_config(out: Path) -> dict:
    """Flutter's build configuration (`_flutter.buildConfig` in the built
    flutter_bootstrap.js): the engine and the builds made; empty without it."""
    bootstrap = out / 'flutter_bootstrap.js'
    if not bootstrap.exists():
        return {}
    text = bootstrap.read_text(encoding='utf-8')
    match = re.search(r'_flutter\.buildConfig\s*=\s*', text)
    if not match:
        return {}
    try:
        config, _ = json.JSONDecoder().raw_decode(text, match.end())
    except ValueError:
        return {}
    return config if isinstance(config, dict) else {}


def engine_revision(out: Path) -> str | None:
    """The Flutter engine the build uses, which names its CanvasKit files."""
    engine = build_config(out).get('engineRevision')
    return engine if isinstance(engine, str) and re.fullmatch(r'[0-9a-f]+', engine) else None


def build_files(out: Path) -> dict[str, list[str]]:
    """Each build's own code, by compile target: with --wasm, Flutter builds
    the app as WebAssembly (main.dart.wasm, main.dart.mjs) and as JavaScript
    (main.dart.js), and each browser loads one of them."""
    builds = {}
    for build in build_config(out).get('builds', []):
        target = build.get('compileTarget') if isinstance(build, dict) else None
        if not target:
            continue
        paths = [build.get(k) for k in ('mainWasmPath', 'jsSupportRuntimePath', 'mainJsPath')]
        builds[target] = [_url_path(p) for p in paths if isinstance(p, str) and p]
    return builds


def stamp_release(out: Path) -> str | None:
    """Writes the release's file list into the built sw.js; returns the
    release's id, or None when sw.js is missing or already stamped."""
    sw = out / 'sw.js'
    if not sw.exists():
        return None
    text = sw.read_bytes().decode('utf-8')  # bytes, so the line endings stay as they are
    if RELEASE_PLACEHOLDER not in text:
        return None
    files = release_files(out)
    release_id = hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()[:12]
    stamp = {'id': release_id, 'files': files}
    engine = engine_revision(out)
    if engine:
        stamp['engine'] = engine  # the worker drops other engines' CanvasKit copies
    builds = build_files(out)
    if len(builds) > 1:
        stamp['builds'] = builds  # the worker keeps only the build this browser loads
    release = json.dumps(stamp, separators=(',', ':'), sort_keys=True)
    sw.write_bytes(text.replace(RELEASE_PLACEHOLDER, f'const RELEASE = {release};').encode('utf-8'))
    return release_id


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--db', type=Path, help='the content database (content.db); needed for the pages')
    ap.add_argument('--out', type=Path, required=True, help='the web build (app/build/web)')
    ap.add_argument('--versions', nargs='*', help='only these version IDs')
    ap.add_argument('--site-url', help="the site's address, for canonical links and the sitemap")
    ap.add_argument('--allow-unverified', action='store_true', help='include versions whose license says "verify"')
    ap.add_argument('--skip-pages', action='store_true', help="only stamp the service worker's file list")
    args = ap.parse_args(argv)
    if not args.skip_pages and args.db is None:
        ap.error('--db is needed for the pages (or use --skip-pages)')
    if not args.skip_pages:
        counts = build_site(args.db, args.out, args.versions, args.site_url, args.allow_unverified)
        for version, n in counts.items():
            print(f'{version}: {n} chapter pages')
    release = stamp_release(args.out)
    print(f'service worker: release {release}' if release else 'service worker: no list stamped (missing, or done before)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
