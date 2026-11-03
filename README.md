# Amharic Bible · መጽሐፍ ቅዱስ

An offline-first Amharic Bible app with text, synchronized audio and Ge'ez-aware search.

- Design: [docs/DESIGN.md](docs/DESIGN.md)
- Status: MVP features implemented. The app bundles **sample text only** until the content licenses are confirmed (see below).

## Repository layout

| Path | What |
|---|---|
| `app/` | Flutter app (Android, iOS and web) |
| `pipeline/` | Python content pipeline: USFM → SQLite content DB |
| `content/` | `books.json` (66-book catalog, Amharic + English names; other languages take book names from their USFM), `versions.json` (Bible texts) and `resources.json` (study resources), both with sources and license status |
| `server/audio-proxy/` | Small proxy that keeps the Bible Brain API key off devices |
| `server/study-assistant/` | AI study assistant (Claude) that answers only from sources the app sends |
| `.github/workflows/` | CI (tests, analysis, debug APK) and the full-content build |

## Content pipeline

```sh
# Run the tests
python -m unittest discover -s pipeline/tests

# Rebuild the bundled sample DB (after changing fixtures or the pipeline)
python pipeline/build_db.py --sources pipeline/tests/fixtures/usfm \
  --out app/assets/content/content.db --sample --allow-unverified

# Full text: download sources listed in content/versions.json and content/resources.json, then build
python pipeline/fetch_sources.py
python pipeline/build_db.py --sources content/sources --out build/content.db
```

`build_db.py` refuses to package a version or resource whose `license.status` is not `confirmed`. With
`--report build/report.json` it also writes a content quality report (books, chapters, verses, words, variants,
warnings and license status per version; rows per resource) as JSON and Markdown; the **Build full content**
workflow shows it on the run's summary page.
**AMH1962 is still `verify`.** Confirm its terms (and the eBible.org source ID) before a release. Then run the
**Build full content** workflow, which builds `content.db` and a release APK that bundles it.

The Ge'ez search normalization exists in Python (`pipeline/abible/geez.py`) and Dart (`app/lib/core/geez.dart`).
Both are tested against `pipeline/tests/normalize_vectors.json`, so the app's queries always match the index.
Search also ignores Hebrew vowel points, Greek accents and Latin diacritics, so "λογος" finds "λόγος".

### Study material

| ID | What | License |
|---|---|---|
| `WLC` | Hebrew Old Testament (Westminster Leningrad Codex) with Open Scriptures lemmas and morphology, Hebrew and Aramaic, mapped to KJV verse numbers; qere readings kept as variants | Text public domain; morphology CC BY 4.0 |
| `RP2018` | Greek New Testament (Robinson-Pierpont 2018) with Strong's numbers, parsing, and where NA27/28, ECM and Byzantine manuscripts differ | Public domain |
| `STRONGS` | Strong's Hebrew and Greek dictionaries, plus short English glosses for interlinear lines (STEPBible brief lexicons TBESG/TBESH, by Hebrew word sense where the text marks one) | CC BY-SA (Open Scriptures); glosses CC BY 4.0 (STEPBible.org) |
| `OBXREF` | Cross-references | CC BY (OpenBible.info) |
| `THEOGRAPHIC` | People, places and events linked to verses; Easton's Bible Dictionary | CC BY-SA 4.0; Easton's public domain |
| `HCF` | Church-father and historical commentary (authors up to 1700) | **`verify`**: mixes public-domain excerpts with fair-use excerpts of modern translations; review before release |

A full build writes these as separate packs (`build/packs/<ID>.db`, `"bundle": false`), so the app download stays
small; readers download the ones they want under Me → Downloads. Books outside the 66-book canon are skipped.

| Pack | Download | Installed |
|---|---|---|
| WLC (Hebrew OT) | 10.5 MB | 39 MB |
| RP2018 (Greek NT) | 4.3 MB | 17 MB |
| STRONGS | 1.0 MB | 2.7 MB |
| OBXREF | 4.0 MB | 12 MB |
| THEOGRAPHIC | 2.1 MB | 6.8 MB |
| HCF (commentary) | 36 MB | 138 MB |

Publishing packs:

1. `python pipeline/package_packs.py --packs build/packs` writes `<ID>.db.gz` and `manifest.json` (sizes,
   SHA-256, license). The **Build full content** workflow runs it and uploads them as the `study-packs` artifact.
2. Upload those files to one folder on a static host that supports HTTP range requests (for example a GitHub
   release or a Cloudflare R2 bucket), so interrupted downloads resume.
3. Build the app with `--dart-define=STUDY_PACKS_URL=<that folder's URL>`. Without it the Study packs section
   is hidden and the study screens show only the sample excerpts.

How the app uses them: a download resumes from where it stopped, is checked against the manifest's SHA-256 and
size, and is then attached to the content database with `ATTACH DATABASE`. Each query reads the database that
holds its version or resource, and a pack replaces the bundled sample excerpt of the same content. A pack built
for another schema version is ignored. When the server publishes a pack with a new checksum, the Downloads screen
offers an update.

## App

Requires Flutter (stable, Dart ≥ 3.13).

```sh
cd app
flutter pub get
flutter analyze && flutter test
flutter run --dart-define=AUDIO_PROXY_URL=https://your-proxy.example   # audio is optional
# Study packs (optional): --dart-define=STUDY_PACKS_URL=https://your-host.example/packs/v2
# AI study assistant (optional): --dart-define=STUDY_ASSISTANT_URL=... --dart-define=STUDY_ASSISTANT_TOKEN=...
```

Features:

- **Reading:** paragraphs, poetry, headings, footnotes, words of Jesus in red, light/sepia/dark/black themes,
  serif or sans Ethiopic fonts, Ge'ez numerals. A text whose source doesn't mark the words of Jesus can borrow them
  by verse from another version (`red_letters_from` in `content/versions.json`; AMH1962 uses WEB, so verses that mix
  narration and speech turn red as a whole until a source with its own `\wj` markup is used).
- **Side by side:** any two versions (e.g. Amharic + English), in columns on tablets and interleaved on phones.
- **Personal study:** highlights, bookmarks and notes; offline search with reference jumps ("ዮሐ 3፥16", "Jn 3:16"),
  exact phrases in quotes ("so loved", «ዓለምን ወደደ»), and a Filter sheet to narrow by testament or book, or to
  search every version at once. Results come one kind at a time: verses, words, people and places, dictionary.
- **Compare:** the selected verses in every installed version, from the selection bar.
- **Notes:** tags work as notebooks (filter the notes list by tag); export notes as Markdown with each passage
  quoted and the version cited.
- **Grammar search:** `morph:V-AAI` (Greek aorist active indicative), `@HVqw` (Hebrew Qal wayyiqtol), optionally
  with a Strong's number (`G25 morph:V-AAI`).
- **Timeline:** dated biblical events in order, grouped into eras (Search & Study → Bible timeline). Places
  open on a map (online).
- **Study groups (needs accounts):** create a group or join with an 8-character code (Invite, at the top of the
  group, shares or copies it); discuss as a conversation, follow a shared reading plan with everyone's progress,
  and teachers give assignments (passage, task, due date) that members mark done. Members see each other's chosen
  display names, never emails.
- **Habits:** an optional daily reading reminder at any time of day, and an opt-in reading streak (Settings →
  Reminders and habits).
- **Read aloud:** versions without recorded audio are read with the phone's text-to-speech voice.
- **Downloads:** Wi-Fi only by default; interrupted audio and study-pack downloads resume.
- **Recently read:** the last chapters you opened, on Home.
- **Deep links:** `amharicbible://open/read?ref=JHN.3.16` opens the reader at John 3:16 (Android and iOS).
- **Original languages:** Hebrew and Greek texts (Hebrew right to left), an interlinear mode with each word's
  gloss and code under the verse, and a word sheet that explains the grammar in plain Amharic or English.
- **Word and verse study:** Strong's entries with every occurrence (a concordance); per verse, in tabs, the original
  words and textual variants, cross-references, people/places/events, attributed commentary marked "Not Scripture",
  and your notes on the verse.
  Search also finds words by Strong's number, lemma or meaning, and people, places and dictionary entries.
  Search & Study opens on the study tools: key Greek and Hebrew words, the most-mentioned people, places and
  events, the timeline, and Ask about a passage.
- **AI study assistant (optional):** a conversation about a passage: explain, summarize, study questions, sermon
  help or your own questions, at a simple or scholar level, in Amharic or English, with an optional tradition; cited
  sources open on a tap. See below.
- **Audio:** follow-along verse highlighting, background playback, speed, sleep timer and book downloads.
- **Reading plans:** Bible in a year, New Testament in 90 days, Gospels in 30 days, Psalms and Proverbs in
  60 days, with a strip of the plan's days and a "today's reading" card on Home (where a first plan starts in one
  tap). A day marks itself read once the end of each of its chapters has been on screen a few seconds, with Undo.
  Behind? Pick up where you left off, or mark the missed days read. Finishing a plan brings a card to share.
- **Share:** verses as text, or as an image card (9 backgrounds, square or story size, three text sizes, an
  optional ornament frame, with or without the version; a 1080 px PNG).
- **Accounts (optional):** sign in with an emailed code to sync highlights, bookmarks, notes, plans and your
  reading position across devices. Export your data as JSON, or delete your account, from inside the app.
- Verse of the day, an Amharic or English UI, and the Ethiopian calendar.

The app uses the 66-book canon only. Still to come: notification reminders for plans.

### Web app

The same Flutter code also builds a web app.

```sh
cd app
flutter run -d chrome                     # development
flutter build web --release               # static site in app/build/web
# The same --dart-define options as the mobile build (audio, accounts, assistant)
cd ..
python pipeline/build_site.py --db app/assets/content/content.db --out app/build/web --site-url https://bible.example.org
```

`pipeline/build_site.py` finishes the build. Run it once after every `flutter build web` (use the full content
database for a real release):

- **Chapter pages:** a plain HTML page for every chapter at `bible/<version>/<book>/<chapter>/` (for example
  `/bible/web/jhn/3/#v16`), with indexes of versions and books. Search engines and link previews can read them,
  they open at once on a slow connection, and "Open in the app" leads into the reader. With `--site-url` it also
  writes canonical links, `sitemap.xml` and `robots.txt`. Versions whose license still says "verify" are left out
  unless `--allow-unverified` is given, as in `build_db.py`.
- **The release's file list** is stamped into the built `sw.js`, so a repeat visit starts from the kept copy (see
  Offline below). `--skip-pages` does only this.

`app/build/web` is a static site: host it on any static host (Cloudflare Pages, GitHub Pages, Netlify, Firebase
Hosting). URLs are clean paths (for example `/read?ref=JHN.3.16`), so the host must serve `index.html` for every
path:

| Host | What to do |
|---|---|
| Cloudflare Pages | Nothing: without a top-level `404.html` it already serves `index.html` |
| Netlify | Add a `_redirects` file containing `/*  /index.html  200` |
| Firebase Hosting | Add a rewrite of `**` to `/index.html` in `firebase.json` |
| GitHub Pages | No rewrites: copy `index.html` to `404.html` when deploying |

Old `/#/…` links (from earlier builds) are moved to the new addresses when the page loads. If the site is not at the
domain root, build with `--base-href /path/`. CI builds it, with the chapter pages and the stamp, on every push as
the `web-sample-content` artifact.

How it differs from the mobile app:

- **Storage:** SQLite runs in the browser as WebAssembly (`sqflite_common_ffi_web`; `web/sqlite3.wasm` and
  `web/sqflite_sw.js`) and keeps the content and user databases in IndexedDB. Clearing site data erases
  unsynced highlights and notes, so suggest that web readers sign in to sync. After the first local change the app
  asks the browser for persistent storage, so the data isn't cleared when the device runs low on space.
  After upgrading `sqflite_common_ffi_web`, run `dart run sqflite_common_ffi_web:setup` in `app/` to refresh
  those two files.
- **Offline:** after one visit the app opens without a connection. `web/sw.js` (registered in `web/index.html`)
  keeps the page, the app's files, CanvasKit and the fallback fonts.
  - With the file list stamped by `build_site.py`, it keeps the whole release when it installs, and the app starts
    from that copy without waiting for the network. A new release downloads in the background during a visit and
    takes over the next time the app starts in a tab of its own (or once the app's tabs have closed), so an open
    app never mixes two releases.
  - Without the stamp (a plain `flutter build web`), it fetches the page and the app's files network-first, so a
    new release arrives on the next online visit.

  `web/flutter_bootstrap.js` starts the app without Flutter's deprecated service worker, which would replace
  `sw.js`. To check offline behavior, serve a stamped release build, visit once, then stop the server and reload.
- **Not on the web:** offline audio downloads and study-pack downloads (audio streams instead), and the daily
  reminder (browsers cannot schedule notifications while the page is closed). The menu items are hidden.
- **Sharing:** verse images and the data export use the browser's share sheet, or download the file.
- **Mouse and install:** hovering tints a verse and a right-click opens its actions; browsers that can install
  the app (Chrome, Edge, Android) get "Install the app" on Me. Greek and Hebrew fonts are bundled, so the original
  texts show at once and offline.
- **Wide windows:** a navigation rail from 600 px and a labeled sidebar from 1200 px replace the bottom bar, and
  stay beside the screens opened from the tabs (verse study, words, Ask, the player); from 1360 px the reader shows
  the verse study beside the text. Ctrl+K (⌘K) opens "Go to". From 840 px, sheets open as popovers beside the
  control that opened them (Aa, footnotes, option lists), Today becomes a two-column dashboard, and app bars line up
  with the centered content.
- **Servers:** browsers call the audio proxy and study assistant directly, so set `ALLOWED_ORIGINS` in each
  `wrangler.toml` to the web app's origin (CORS). Add the site's URL to Supabase Auth's allowed redirect URLs.
  The study assistant's app token is visible in the web app's JavaScript (as it can be extracted from an APK);
  rate-limit the assistant if that matters.

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

## Accounts and sync

Sync uses Supabase (Postgres + Auth). Without it the app works fully offline and hides sign-in.

1. Create a Supabase project and apply `server/supabase/migrations/*.sql` in order (`supabase db push`, or
   paste each file into the SQL editor). An existing project needs the newer migrations too: the reading
   position sync needs `20261101000000_position_records.sql`, study groups need
   `20261102000000_study_groups.sql`. The first migration creates the `user_records` table with row-level security, the
   `push_records()` function (last writer wins) and `delete_my_account()`.
2. Under Authentication → Email templates, make the **Magic Link** template show the code: `{{ .Token }}`.
   The app signs in with a 6-digit code, so no deep links are needed.
3. Build the app with `--dart-define=SUPABASE_URL=https://<project>.supabase.co` and
   `--dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key>`.

How sync works: every local change is queued (`sync_outbox`). Sync runs at sign-in, every 15 minutes, and a few
seconds after each change. It pulls first, then pushes. The newest edit wins per item, and a note edited on two
devices keeps the losing text as a separate note, so no writing is lost. The SQL is tested against real
Postgres (PGlite): `cd server/supabase/test && npm ci && npm test`.

## AI study assistant

`server/study-assistant` is a Cloudflare Worker that calls Claude (`claude-opus-5-5`, with server-side fallback
on safety declines). The app sends the passage in every installed version plus the lexicon, variant,
cross-reference, people/place and commentary entries for it, numbered S1, S2, …; the assistant answers only from
those, as labelled segments (explanation, quote, Scripture pointer, debated interpretation) that cite source ids.

The server enforces what the prompt asks for: source ids and verse keys the app didn't send are removed; a
quote that isn't in its cited source is shown as an unverified explanation; Scripture segments carry verse keys
only, and the app shows the verse text from its own database. Answers are always labelled as AI-written.

1. `cd server/study-assistant && npm ci && npm test`
2. `wrangler secret put ANTHROPIC_API_KEY` and `wrangler secret put APP_TOKEN`, then `wrangler deploy`.
3. Build the app with `--dart-define=STUDY_ASSISTANT_URL=<worker URL>` and
   `--dart-define=STUDY_ASSISTANT_TOKEN=<APP_TOKEN>`. Without them the Ask AI button is hidden.

The shared token only stops casual misuse (it ships inside the app); add rate limiting (for example Cloudflare
rate-limiting rules) before a public release, because every request is billed to the API key.

## Error reports (optional)

With accounts set up, Settings → Privacy offers **Send error reports** (off by default). When it is on, crashes
and errors go to the `error_reports` table (`20261103000000_error_reports.sql`): the error, where it happened,
the app version (`--dart-define=APP_VERSION=...`) and platform. No Bible text, notes or account details. Only the
service role can read the table (Supabase dashboard → Table editor).

## Licenses

Fonts: Noto Serif/Sans Ethiopic, Noto Serif (a Greek subset) and Noto Serif Hebrew, SIL Open Font License (`app/assets/fonts/OFL.txt`). Bible texts: see
`content/versions.json`. Study resources: see `content/resources.json`. Each attribution is shown in the app
under About → Sources and Study sources. The Strong's and Theographic data are ShareAlike: changes to that data
must be shared under the same license.
