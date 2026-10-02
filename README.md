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

Features:

- **Reading:** paragraphs, poetry, headings, footnotes, words of Jesus in red, light/sepia/dark/black themes,
  serif or sans Ethiopic fonts, Ge'ez numerals.
- **Side by side:** any two versions (e.g. Amharic + English), in columns on tablets and interleaved on phones.
- **Study:** highlights, bookmarks and notes; offline search with reference jumps ("ዮሐ 3፥16", "Jn 3:16").
- **Audio:** follow-along verse highlighting, background playback, speed, sleep timer and book downloads.
- **Reading plans:** 19 plans grouped by length (1 week, 1 month, 3 months, 6 months, 1 year), from Mark in
  7 days to the Bible in a year (straight through, Old and New Testament together, or in time order).
  Hand-picked plans include the Sermon on the Mount and the parables, Psalms of comfort and the life of
  Jesus in time order (lists in `pipeline/curated_plans.py`, drafts for pastoral review). Each shows its
  estimated minutes a day and pace; days are balanced by verse count. Daily progress and a "today's
  reading" card on Home.
- **Planning assistant** (offline): four quick questions (how long, time a day, what to read, which days)
  recommend the ready-made plans that fit best, flag goals that would not fit your time (with a period
  that does), and offer "Build my own" pre-filled with your answers. Fallen more than three days behind
  on a ready-made plan? "Catch up" makes it your own and re-plans it, keeping your progress.
- **Make your own plan:** pick what to read (whole Bible, a testament, the Gospels, Psalms and Proverbs, or any
  books), how long (a period, an end date or chapters a day), which weekdays, and when to start; a live
  preview shows chapters and minutes a day and the finish date. Fallen behind? Re-plan spreads what is left
  from today to a new end date, keeping what you have read.
- **Reading streak:** on by default (can be turned off). A day counts after 30 seconds on a chapter, reaching
  its end, listening to most of a chapter, or marking a plan day done. One missed day a week is forgiven
  (a rest day). Home shows the streak and the last seven days; Me → Reading activity has a month calendar.
  Reading from before the streak existed is carried over, so updating the app does not reset it.
- **Daily reminder** (off by default; Settings → Reminders): a notification at a time you pick, e.g. "Today:
  Mark 3–4" from your active plan, or a nudge to keep your streak. Skipped once you've read that day; tapping it
  opens the passage. Local notifications only, nothing leaves the phone.
- **Share:** verses as text, or as an image card (8 backgrounds, square or story size, 1080 px PNG).
- **Accounts (optional):** sign in with an emailed code to sync highlights, bookmarks, notes, plans (including your
  own) and reading days across devices. Export your data as JSON, or delete your account, from inside the app.
- Verse of the day, an Amharic or English UI, and the Ethiopian calendar.

The app uses the 66-book canon only.

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

1. Create a Supabase project and apply `server/supabase/migrations/*.sql` (`supabase db push`, or paste the
   file into the SQL editor). The migration creates the `user_records` table with row-level security, the
   `push_records()` function (last writer wins) and `delete_my_account()`.
2. Under Authentication → Email templates, make the **Magic Link** template show the code: `{{ .Token }}`.
   The app signs in with a 6-digit code, so no deep links are needed.
3. Build the app with `--dart-define=SUPABASE_URL=https://<project>.supabase.co` and
   `--dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key>`.

How sync works: every local change is queued (`sync_outbox`). Sync runs at sign-in, every 15 minutes, and a few
seconds after each change. It pulls first, then pushes. The newest edit wins per item, and a note edited on two
devices keeps the losing text as a separate note, so no writing is lost. The SQL is tested against real
Postgres (PGlite): `cd server/supabase/test && npm ci && npm test`.

## Licenses

Fonts: Noto Serif/Sans Ethiopic, SIL Open Font License (`app/assets/fonts/OFL.txt`). Bible texts: see
`content/versions.json`. Each version's attribution is shown in the app under About → Sources.
