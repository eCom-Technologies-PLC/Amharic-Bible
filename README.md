# Amharic Bible · መጽሐፍ ቅዱስ

An offline-first Amharic Bible app with text, synchronized audio and Ge'ez-aware search.

- Design: [docs/DESIGN.md](docs/DESIGN.md)
- Status: MVP features implemented. The app bundles **sample text only** until the content licenses are confirmed (see below).

## Repository layout

| Path | What |
|---|---|
| `app/` | Flutter app (Android + iOS) |
| `pipeline/` | Python content pipeline: USFM → SQLite content DB |
| `content/` | `books.json` (66-book catalog, Amharic + English names) and `versions.json` (sources + license registry) |
| `server/audio-proxy/` | Small proxy that keeps the Bible Brain API key off devices |
| `.github/workflows/` | CI (tests, analysis, debug APK) and the full-content build |

## Content pipeline

```sh
# Run the tests
python -m unittest discover -s pipeline/tests

# Rebuild the bundled sample DB (after changing fixtures or the pipeline)
python pipeline/build_db.py --sources pipeline/tests/fixtures/usfm \
  --out app/assets/content/content.db --sample --allow-unverified

# Full text: download sources listed in content/versions.json, then build
python pipeline/fetch_sources.py
python pipeline/build_db.py --sources content/sources --out build/content.db
```

`build_db.py` refuses to package a version whose `license.status` in `content/versions.json` is not `confirmed`.
**AMH1962 is still `verify`.** Confirm its terms (and the eBible.org source ID) before a release. Then run the
**Build full content** workflow, which builds `content.db` and a release APK that bundles it.

The Ge'ez search normalization exists in Python (`pipeline/abible/geez.py`) and Dart (`app/lib/core/geez.dart`).
Both are tested against `pipeline/tests/normalize_vectors.json`, so the app's queries always match the index.

## App

Requires Flutter (stable, Dart ≥ 3.13).

```sh
cd app
flutter pub get
flutter analyze && flutter test
flutter run --dart-define=AUDIO_PROXY_URL=https://your-proxy.example   # audio is optional
```

The MVP covers the reader (paragraphs, poetry, headings, footnotes, words of Jesus in red), the book picker,
themes (light, sepia, dark, black) and fonts, highlights, bookmarks and notes, offline search with reference
jumps ("ዮሐ 3፥16", "Jn 3:16"), audio with follow-along highlighting, background playback, speed, sleep timer and
book downloads, verse of the day, an Amharic or English UI, the Ethiopian calendar and Ge'ez numerals.

Not yet built (phase 2, per the design): accounts and sync (the outbox is already recorded), reading plans,
share-as-image, parallel view and the 81-book canon.

## Audio

Audio comes from Bible Brain (Faith Comes By Hearing) through `server/audio-proxy`:

1. Get a Bible Brain API key and find the Amharic audio fileset ID.
2. Set `audio.fileset_id` for AMH1962 in `content/versions.json` and rebuild the content DB. Set
   `allow_download: true` only if the fileset's terms allow offline copies.
3. Deploy the proxy (`wrangler deploy` from `server/audio-proxy`, after `wrangler secret put BIBLE_BRAIN_KEY` and
   setting `ALLOWED_FILESETS`). Test it with `node --test server/audio-proxy/proxy.test.mjs`.
4. Build the app with `--dart-define=AUDIO_PROXY_URL=<proxy URL>`.

The proxy follows the Bible Brain v4 endpoint shapes. Verify them against the current Bible Brain docs before
deploying.

## Licenses

Fonts: Noto Serif/Sans Ethiopic, SIL Open Font License (`app/assets/fonts/OFL.txt`). Bible texts: see
`content/versions.json`. Each version's attribution is shown in the app under About → Sources.
