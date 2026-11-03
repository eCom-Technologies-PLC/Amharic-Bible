# Amharic Bible: UI/UX audit and redesign plan (mobile + web)

**Date:** 2026-11-02 · **Scope:** the Flutter app (Android, iOS) and the Flutter web app · **Type:** plan only, no code

---

## 0. How this audit was done

- **Code review** of all 22 routed screens, about 10 sheets and dialogs, the theme, the tokens and every shared widget
  (`app/lib/**`), checked against `docs/DESIGN.md` (intended UX) and `CLAUDE.md` (UI rules).
- **Live walkthrough** of the current web build (`app/build/web`) at phone width (412 px) and desktop width (1440 px),
  in light and dark.
- **Competitive research:** YouVersion, Bible.is, Dwell, Hallow, Glorify, the ESV app, Apple Books and Kindle (reading),
  Olive Tree, Logos and Sefaria (study), Quran.com and Tarteel (non-Latin scripture with audio), and Amharic apps
  (Kedus Bible, Biblica's Amharic Bible, EOTC Bible and other template apps).
- **Caveat:** only sample content is bundled (John 3, Genesis 1:1), so re-check the reader's density once the full text
  ships.

---

## 1. Executive summary

The app has a lot of features and is unusually well engineered. Every screen uses the shared tokens and widgets, there
are no inline colours, and a layout audit renders every route at 320 dp with 1.3× text in four themes. **It still looks
like a generic Material 3 template:**

- One seeded green and flat cards that barely stand out from the page.
- Screens that are mostly stacks of list rows.
- No imagery, one animation in the whole codebase and no haptics.
- The stock Flutter app icon and splash screen.

The strongest features (audio follow-along, side-by-side reading, interlinear, word and verse study, AI assistant,
plans, groups, timeline) are 3–5 taps deep and mostly invisible. There is no onboarding. On the web, the phone layout is
stretched across the window.

**The plan:**

1. **Identity.** Give the app a recognisable, culturally rooted look, "an illuminated manuscript, made modern". Do it
   through tokens, the theme and a dozen new shared components, not by styling each screen.
2. **Navigation.** Rebuild it around daily use: **Today · Read · Plans · Search & Study · Me**.
3. **Key surfaces.** Redesign the six highest-traffic ones: Today, Reader, verse actions, book picker, audio, and
   Me/Library.
4. **Desktop web.** Give the web a real desktop layout: sidebar navigation, a reader with a study panel, keyboard
   shortcuts, clean URLs, a branded loading screen.
5. **Trust.** Fix what undermines it: wrong interlinear glosses, deletes with no undo, edits lost silently, copy bugs.

Ship in five phases. Each phase must pass the layout audit plus new golden (screenshot) tests.

### Quick wins (each about a day or less once the brand assets exist)

1. Replace the stock Flutter icon, favicon and splash with a real mark.
2. Fix reading contrast:
   - Red letters on highlights in dark/black themes fail WCAG AA (3.5–4.4:1).
   - The yellow highlight is invisible on sepia (≈1.01:1).
   - A selected verse is shown only by a dotted underline.
3. Separate surfaces: cards and app bars need a clear tone step from the page. Today cards are only 2–3 lightness units
   apart.
4. Home: put **Continue reading** first, add a greeting, make the verse of the day a hero card.
5. Me: group the 10 flat rows under section headers with counts. Fix the Library screen being titled "Me".
6. Add undo or confirmation to every delete. Guard the note editor against losing unsaved changes.
7. Never show raw exception text (Account screen). Fix the copy bugs listed in §3.5.
8. Interlinear glosses: switch to a real short-gloss source and fix truncated parentheses (§3.5, Study).
9. Web: cap content width on non-reader screens, add a branded loading screen to `index.html`, set page titles per
   route.
10. Text settings ("Aa") sheet: add a title and visual theme swatches. Move verse numbers, red letters and Ge'ez
    numerals into it.
11. Haptics on verse select, highlight and bookmark.
12. Selection bar: four main actions plus **More**, and never cover the selected verse.
13. Web: make the reader's URL follow chapter changes, so Back, refresh, bookmarks and shared links work.
14. Web: request persistent browser storage, so notes kept in IndexedDB aren't evicted. Nudge readers to sign in to
    back them up.
15. Mobile: back clears a verse selection and never discards a note. Use a proper monochrome notification icon (the
    launcher icon shows as a white blob in the status bar).

---

## 2. What to keep

- **The token and shared-widget architecture, and the `CLAUDE.md` rules.** Because screens inherit everything, the
  redesign is mostly theme, token and widget work.
- **Reading foundations:**
  - Four reading themes.
  - Ethiopic-aware type: 19 sp default, line heights 1.5–2.0, bundled Noto Serif/Sans Ethiopic.
  - Ge'ez numerals, the Ethiopian calendar and an Amharic-first UI.
- **Reader layout:**
  - The reading column is capped at 680 px and centred on wide screens.
  - Side-by-side reading uses columns at 600 dp and wider, and interleaves verses on phones.
- **The share-image screen**, the best-designed screen in the app. Its gradients (manuscript green, sunrise, night,
  burgundy, parchment) become the brand palette.
- **The privacy stance:** no sign-up wall, no ads, no tracking. Make it a visible value on Today and in Me.

---

## 3. Audit findings

Severity: **H** high · **M** medium · **L** low. Platform: [M] mobile · [W] web · [B] both.

### 3.1 Look and feel [B]

- **H · No brand.** The app icon is the Flutter logo on Android, iOS, web and the favicon. The splash screens are
  untouched templates (`android/.../launch_background.xml`, `ios/Runner/Base.lproj/LaunchScreen.storyboard`). There is
  no logo, and the About screen is text only.
- **H · A single-hue Material default.**
  - The colour scheme is `ColorScheme.fromSeed(#1E6B4E)` (`ui/theme/app_theme.dart`).
  - The secondary and tertiary colours are almost unused.
  - The navigation bar, tabs, switches and sliders keep Material's default styling.
- **H · Flat hierarchy.**
  - Effectively two font weights.
  - The display and headline text styles are unused, and every title is 20 px.
  - Home is a date label followed by identical cards.
- **M · Surfaces barely separate.** Cards differ from the page by about 2–3 L* (lightness) units at elevation 0, and
  app bars don't separate when content scrolls under them. Dark and black are worst. The black theme mixes green-grey
  and neutral grey.
- **M · No imagery or illustration.**
  - Empty states are a 48 px grey icon.
  - The player's "artwork" is a generic book icon.
  - Groups have no avatars.
- **M · Almost no motion.**
  - The codebase has one `AnimatedContainer`.
  - Changing chapter shows a spinner, then the text.
  - The selection bar pops in and out.
  - There is no haptic feedback anywhere.
- **M · The themes are incoherent.**
  - Sepia keeps cool green accents, and its yellow highlight is invisible.
  - Sepia reuses light's highlight colours and black reuses dark's.
  - The semantic colours (success, warning, info) are Material 2 defaults that don't match the brand.
- **M · Inconsistent icons.** There are three different share icons, and filled and outlined icons are mixed. The
  search tab shows the same icon whether or not it is selected.
- **L · Type details.**
  - Psalm titles use a synthesised italic; Ethiopic has no italic.
  - The variable fonts have no `fontVariations`, so verify that w500/600/700 render as true weights.

### 3.2 Navigation and information architecture [B]

- **H · Me is a 10-row catch-all.** Plans, Timeline, Groups, Downloads and the Library are all buried there, and three
  of the rows open the same Library screen.
- **H · Features are hard to discover.** None of these is signposted:
  - Swiping to change chapter.
  - Tapping a verse to select it.
  - Compare.
  - Side-by-side, hidden in the version menu.
  - Interlinear, hidden in the Aa sheet and only after a download.
  - Downloading audio, possible only from the Player.
  - Audio speed and the sleep timer.
  - The text-to-speech fallback.
  - The grammar search syntax.
  - Ask AI, reachable only from Verse study.
  - The timeline, and note tags and export.
- **M · Deep paths:**
  - Word study: 5 taps.
  - An AI answer: 5 taps.
  - Sharing a group invite: 5 taps.
  - Starting a plan: 4 taps.
- **M · Settings are split between the Aa sheet and Settings.**
  - Verse numbers, red letters and Ge'ez numerals are only in Settings.
  - The Settings "Theme" row opens the Aa sheet.
  - The text-size control is duplicated.
- **L · Duplicate entry.** The Home gear duplicates Me → Settings.

### 3.3 Home [B]

- **H · Sparse and static for new users.** They see a date, a plain-text verse-of-the-day card, "Start reading" and a
  hint line. There is no greeting, no plan suggestion, no audio entry and no search.
- **M · Continue reading sits below the verse of the day and every plan card.** There is no "Continue listening",
  although `DESIGN.md` §4.1 lists one.
- **M · The verse of the day is a generic card,** and it silently disappears if it fails to load.
- **L · Date.** The Ethiopian date always uses Amharic month names, even in the English UI, and shows no weekday.

### 3.4 Reader [B]

- **H · No immersive mode.** The app bar, tab bar and mini player are always visible, so roughly a quarter of a phone
  screen is chrome.
- **H · Selection is weak and cramped.**
  - A single tap selects a verse (`DESIGN.md` specifies long-press).
  - The selected verse gets only a dotted underline (`reader/paragraph_view.dart`).
  - The selection bar is about 200 dp tall. Its 8 actions wrap to two rows, leaving "Listen" alone on the second row.
    The bar covers the text and stacks on top of the tab bar.
  - Study and Ask use only the first selected verse.
- **M · Orientation:**
  - No chapter heading or book title in the text.
  - No progress indicator.
  - Nothing shows that swiping changes chapter.
  - Previous/next buttons appear only at the end of the chapter.
- **M · Audio.** Tapping a verse during playback selects it instead of seeking to it (`DESIGN.md` §3.3 says seek). The
  playing verse is marked red-on-green when red letters are on.
- **M · Red letters.** Whole paragraphs use a saturated `#B3261E`. In dark and black themes, red letters on highlights
  reach only 3.5–4.4:1 (below AA).
- **M · Footnotes.** The markers are tiny "*" tap targets.
- **L · Aa sheet.** It has no title, and the theme options are text chips with no preview.

### 3.5 Other screens [B]

- **Book picker:**
  - A text-only list of long book names.
  - Missing: the abbreviation grid (`DESIGN.md` §4.2), chapter counts, groups by genre and recent books.
  - It doesn't scroll to the current book, and filtering expands every matching book.
- **Search:**
  - Filter chips show before anything is typed, and there are no suggestions.
  - Recent searches can't be cleared.
  - Study matches push the verse results down.
  - The 200-result cap is shown as "200 results", and plurals are wrong ("1 ውጤቶች").
  - The repository supports a single-book filter, but the UI doesn't offer it.
  - Inflected Amharic forms are missed: ዓለም does not find ዓለሙን.
- **Plans:**
  - No cover art.
  - The one-year plan shows 365 checkbox rows.
  - Reading a day's passages never marks the day done; readers must come back and tick it.
- **Library:**
  - Titled "Me" (`library/library_screen.dart`).
  - No search, sort or book filter.
  - Bookmarks are deleted with no confirmation or undo.
- **Note editor:**
  - Back silently discards edits.
  - Delete has no confirmation.
  - The verse being annotated isn't shown.
  - Saving an empty note deletes it silently.
- **Study:**
  - **Interlinear glosses are wrong.** They take the first, alphabetical, KJV rendering from Strong's: θεός shows as
    "exceeding", κόσμος as "adorning", δίδωμι as "adventure", ἵνα as "albeit".
  - Parentheses get cut off, as in "only (begotten" (`domain/study.dart:44`, `shortGloss`).
  - People and place pages show raw latitude/longitude.
  - The timeline is a plain list with the wrong empty-state text and no way forward.
  - Ask AI shows its answer below all the controls without scrolling to it, and accepts only one verse.
- **Groups:**
  - A dead end when accounts aren't configured.
  - "Leave" is the only app-bar action.
  - The invite code is buried in the fourth tab.
  - No avatars.
  - Posts are deleted with no confirmation.
- **Account:** shows raw exception text. **Downloads:** audio is deleted with no confirmation, and nothing explains what
  each pack unlocks.
- **Player:** no verse text, no "open in reader", generic icon artwork.
- **Onboarding:** none of `DESIGN.md` §8.1 exists (language choice, theme preview, long-press tip). The app opens on
  Home, not John 1.

### 3.6 Web [W]

- **H · Phone layout stretched to the window.** Only the reader has a maximum width.
  - Home, Search, Me, Settings, Library, Plans, Study and Groups span the full window. At 1440 px the
    verse-of-the-day card is about 1,330 px wide. At 1920 px, Settings switches sit about 1,700 px from their labels.
  - Buttons (`BottomActionBar`, `expand: true`) and the share-image preview also go full width.
  - Ten routes (books, player, share image, study, ask, group, timeline, word, entity, note) cover the whole window
    and hide the rail and mini player.
  - Pickers are bottom sheets with drag handles, even with a mouse.
- **H · Blank page while about 4.8 MB (gzipped) downloads.**
  - `web/index.html` is the stock template, with no loading screen.
  - The fonts aren't subset, nothing is deferred, and every locale's date data is compiled in.
  - All setup runs before the first frame, and the content database is fetched on every start.
  - This is slow on Ethiopian mobile networks.
- **H · The reader URL doesn't follow chapter changes.** Back skips chapters, refresh returns to the first reference,
  and bookmarked or shared links are wrong.
- **H · Desktop reading habits break.**
  - Scripture can't be selected or copied with the mouse; the only path is click a verse → Copy.
  - The whole chapter shows a hand cursor, and a quick click-drag flips the chapter.
  - Verses can't take keyboard focus, so keyboard users can't highlight, note or copy (WCAG 2.1.1).
  - There are no shortcuts, and Ctrl+F can't see text drawn on the canvas.
- **M · Weak browser integration.**
  - Every tab and history entry is titled "መጽሐፍ ቅዱስ".
  - URLs use `#/`. Bad URLs show go_router's English "Page Not Found", and `/note` without parameters throws.
  - No Open Graph or theme-color tags, and nothing can be indexed by search engines.
  - The local `app/build/web` is stale: title "amharic_bible", "A new Flutter project.", the old blue manifest colour.
- **M · Not offline-first on the web.**
  - The service worker unregisters itself, so nothing loads offline.
  - No persistent-storage request, so notes in IndexedDB can be evicted.
  - The fonts lack Hebrew, Greek and the thin space used after verse numbers. Those glyphs are fetched from
    fonts.gstatic.com, so offline they show as boxes.
- **M · Web features degrade silently.**
  - Study packs, downloads and reminders vanish without explanation; an almost-empty "Reminders" header remains.
  - Share falls back to `mailto:` on browsers without the Web Share API, and files download although the button says
    "Share".
  - The copy says "phone" and "tap".
- **M · The navigation rail is unbranded:** no logo, no extended labels. The 600–839 range still gets the phone bar.
  On desktop the reader's actions sit about 1,300 px from its title, while the text is centred.

### 3.7 Accessibility [B]

- **Contrast:**
  - Red letters on highlights in dark/black: 3.5–4.4:1.
  - Red letters on the "now playing" green: about 4.1:1, which is also a red–green pair.
  - The yellow highlight on sepia is invisible.
- **Screen readers (thin support):**
  - There are only 6 `Semantics` widgets in the app.
  - Verse numbers are read as "ቁጥር N", in Amharic even in the English UI, and with no book or chapter. The
    `DESIGN.md` §4.5 goal is "ዮሐንስ ምዕራፍ 3 ቁጥር 16".
  - Footnote markers, bookmark and note marks are unlabeled.
  - Selecting a verse is never announced.
  - On the web, semantics stay off until the user finds Flutter's hidden "Enable accessibility" button.
- **Keyboard:** verses can't take focus, and there's no custom focus style.
- **Labels:**
  - Play and pause are both labeled "Listen", and stop is labeled "Clear".
  - The icon-only segments (line spacing, card shape) have no label.
  - Highlight swatches are read with English colour names inside Amharic: "አድምቅ yellow".
- **Colour-only cues:** a selected verse is a dotted underline; Library highlight filters show only colour and a count.
- **Text scale and motion:** text size is tested only at 1.3× (`DESIGN.md` §4.5 promises 200%), and reduced motion
  isn't handled.
- **Audio-first users:** the audio-first mode for low-literacy readers (`DESIGN.md` §4.5) isn't built.

### 3.8 Platform polish [M]

- **Icons:**
  - Stock Flutter icons everywhere, with no adaptive or themed (monochrome) icon on Android.
  - Notifications use the full-colour launcher icon, which shows as a white blob in the status bar.
- **Launch:**
  - Template splash screens: Android uses the old holo window theme and has no Android 12+ splash setup; the iOS
    launch screen is white, with no dark variant.
  - iOS `CFBundleName` is still "amharic_bible".
- **Back navigation:**
  - The fade transition on Android removes the predictive-back preview; also verify iOS swipe-back.
  - No back handling: back doesn't clear a verse selection, and the note editor loses text.
- **No haptics.**
- **Links:** only the `amharicbible://` scheme, with no Android App Links or iOS Universal Links, so shared web links
  never open the app.
- **Missing features:** no home-screen widget and no plan reminders (`DESIGN.md` lists both; YouVersion ships
  verse-of-the-day widgets).

### 3.9 Language and locale [B]

- **Language default:** Amharic is forced on first launch, with no language choice (`DESIGN.md` §8.1) and no detection
  of the browser or phone language.
- **Ethiopian dates** are shown in Amharic with "ዓ.ም." even in the English UI. Times use the 24-hour clock.
- **Ge'ez numerals** are skipped in references, interlinear verse numbers and player titles.
- **Strings:**
  - `S` silently falls back to English when an Amharic string is missing; its comment promises a compile error.
  - "MB" is hardcoded.
  - Notification channel names mix languages.
  - "Tap a verse" and "your phone" wording appears on the web.

---

## 4. Competitive research: what to borrow

| App | What it does well | What we take |
|---|---|---|
| **YouVersion (Bible App)** | A "Today" feed (verse image, guided Scripture, prayer); streaks explained after reading; verse-of-the-day home-screen widgets; simplified sign-in; plans with cover art; plans with friends | A Today screen with a verse-of-the-day hero card and later a widget; plan cover art; group plans inside Plans |
| **Bible.is (Faith Comes By Hearing)** | Text plus audio in many languages, including Amharic, with follow-along | Treat audio as a first-class entry point, not a hidden icon |
| **Dwell** | A prominent Listen/Read switch inside a plan; a choice of voices and music, with separate volumes; artwork for each playlist | A Listen/Read toggle in the reader and in plans; artwork on the player |
| **Hallow, Glorify** | Illustrated onboarding cards that personalise the home screen; gentle routines; the reminder offered at the right moment | A 3-step onboarding with "What brings you here?"; offer a reminder after the first completed plan day |
| **ESV app, Apple Books, Kindle** | Typographic reading: chapter headings; themes as visual swatches; chrome that hides while reading; "time left in chapter" | A chapter header; an Aa sheet with swatches; immersive mode; a progress indicator |
| **Olive Tree, Logos** | A Resource Guide or Passage Guide in a split pane that follows the reading position | A desktop study panel, and a study sheet on phones |
| **Sefaria** | A connections panel (at the bottom on phones, beside the text on desktop); bilingual layout options; compare texts side by side with independent scrolling | The study panel; side-by-side layout options |
| **Quran.com, Tarteel** | Non-Latin scripture at scale: word-by-word under or over each word; one audio player bar; a book-like reading mode separate from a study mode; chapter index cards with the native-script name, translation and verse count; continue reading | Interlinear tooltips; book index cards; separate Reading and Study modes |
| **Kedus Bible** (Amharic, Tigrinya, Oromo, English; ~4.7★, 100k+ downloads, also Flutter) | Several Ethiopian languages; devotions; a prayer tracker. Reported complaints: crashes, audio that stops, inaccurate daily readings | The baseline Ethiopian users expect. We stand out on design, synced audio, Ge'ez-aware search, study tools and the Ethiopian calendar |
| **Biblica Amharic, EOTC Bible, other template apps** | Functional template interfaces | No Amharic Bible app combines polished design, audio follow-along, study tools and a real desktop web app. That gap is our position: *"the most beautiful and trustworthy Amharic Bible"* |

Patterns that show up across the leaders, and that this app should adopt:

1. A **daily home screen** that answers "what should I do now?"
2. **Immersive, typographic reading** with chrome that gets out of the way.
3. **One-tap verse actions** in a compact sheet.
4. **Study tools in a side panel or sheet** that follow the passage.
5. **Gentle habit loops** (reminders, streaks) offered after a success, not before.
6. **Artwork** on plans, audio and shareables.
7. **Personalised onboarding** in three steps or fewer, with no sign-up wall.

> Material 3 Expressive has no official Flutter support yet; only third-party packages exist. Build the "lively" layer
> from our own tokens, motion and components rather than depending on those packages.

---

## 5. Design direction: "Illuminated, calm, alive"

### 5.1 Concept

Take inspiration from Ethiopian manuscript art:

- **ሐረግ (haräg):** interlaced, vine-like headpieces that frame and divide the text.
- **Rubrication:** red ink for headings, names and punctuation, with black for the body text.
- **The manuscript palette:** blue, black, ochre and red on parchment.

**Use only geometric, non-figurative ornament** (no saints or icons), so the look suits Orthodox, Protestant and
Catholic readers equally.

**Rule: the reading surface stays calm.** Colour, ornament and motion live in the frame around it: Today, plans, audio,
sharing, onboarding and empty states.

### 5.2 Colour system

- **Primary:** keep manuscript green `#1E6B4E`. It is already used in the manifest and share cards.
- **Secondary:** ochre/gold, for highlights of progress, streaks and plan accents. Use a deeper ochre for text on light
  backgrounds and a brighter gold for fills.
- **Tertiary:** manuscript red/burgundy (the share card's `#8E2C48` family), for rubricated headings, chapter numbers
  and ornaments.
- **Accent:** indigo (the share card's "night" `#243B55`), for audio, night mode and the playing verse.
- **Neutrals:**
  - Warm parchment for the light and sepia themes.
  - Charcoal for dark, with a clear tone step between page, card and navigation (aim for ≥4–6 L*).
  - True black, kept neutral (no green-grey mix).
- **How to build it:**
  - Hand-tune the colour scheme for each reading theme, rather than taking a single seed's defaults.
  - Extend `AppColors` with:
    - Gradient roles for hero cards.
    - An ornament role.
    - A **"now playing"** role (an indigo tint plus a side bar, never red-on-green).
    - **Four highlight sets**, one per theme (light, sepia, dark, black).
    - A red-letter colour per theme.
- **Rules to verify with a test:**
  - Body text is at least 4.5:1 on every highlight in every theme, including red letters.
  - Each highlight differs from the page by at least about 1.3:1, so it is visible.
  - Semantic colours are re-tuned to the palette.

### 5.3 Typography

- **Keep the faces.** Noto Serif Ethiopic for reading and Noto Sans Ethiopic for the UI.
- **Set weights explicitly.** Both fonts are variable, so set the weight axis (`fontVariations`) and get real
  500/600/700 weights.
- **Use the whole type scale:**
  - Display: the Today hero and chapter numbers.
  - Headline: large titles on top-level tabs.
  - Title: card headings.
  - Label: metadata.
  - Tabular figures in chapter and verse grids.
- **Replace the fake italic.** Psalm superscriptions become smaller, letter-spaced text in the secondary colour.
- **Optional reading faces.** Abyssinica SIL as an alternative Ethiopic face (`DESIGN.md` §4.3). A Latin serif for
  English reading only if diaspora use justifies the size (keep the APK within ≤40 MB).

### 5.4 Shape, depth, layout

- **Radius:** add `AppRadius.xxl` (24) for hero cards, and use pill-shaped buttons for the main calls to action on Today
  and onboarding.
- **Cards:** replace hairline-only cards with tonal containers that sit a clear step above the page. Add a soft shadow
  in light themes; use tone steps only in dark.
- **App bars:** separate from content when it scrolls under. Use large or collapsing titles on top-level tabs.
- **Width tokens:**
  - Page content: ~840 max.
  - Dashboards: ~1200 max.
  - Reading: 680 (kept).
  - Breakpoints: 600 / 840 / 1200 / 1600, following Material's window-size classes.

### 5.5 Imagery and ornament

Vector-first, to protect the install size.

- **Logo:** an open book framed by haräg interlace (decided; see §15). The illustrator draws it, and the current icons
  stay until then.
- **Ornament:** 3–4 haräg ornament bands, drawn as SVG or `CustomPainter`, for the Today hero, chapter headers, plan
  covers, share cards and the splash screen.
- **Plan covers:** 6–8 illustrated covers, one per plan or category.
- **Empty states:** 6 spot illustrations (line art with an ochre accent) for Library, Notes, Search, Groups, Downloads
  and offline.
- **Verse-of-the-day backgrounds:** reuse the share-card gradients plus ornament. Optionally add a photo set of
  Ethiopian landscapes as compressed WebP, downloaded on demand rather than bundled.
- **Rules:**
  - Never put imagery behind Scripture while reading.
  - Exclude decorative images from screen readers.
  - Keep the bundle small.

### 5.6 Motion and haptics

The motion tokens already exist (150 / 250 / 400 ms, `easeOutCubic`). Use them deliberately:

- **Chapter change:** a horizontal slide that follows the swipe. Preload the neighbouring chapters, so there is no
  spinner.
- **Verse actions:** the selection sheet slides up, and highlight colour fills in.
- **Cards:** a slight shrink on press (0.98).
- **Progress:** progress rings and bars animate.
- **Verse of the day:** the Today card expands into the share-image screen (a hero transition).
- **Lists:** skeleton placeholders that cross-fade into content. This needs a `CLAUDE.md` rule change; see §12.
- **Haptics:**
  - A selection tick when a verse is selected.
  - A light tap when highlighting or bookmarking.
  - A success pulse when a plan day is completed.
- **Respect reduced-motion settings** and stay light on low-end Android phones.
- **Celebrations stay subtle** (a check animation, a small flame), never confetti over Scripture.

### 5.7 Iconography

- **One family:** Material Symbols Rounded, outlined by default and filled when selected.
- **One icon per action:** a single share icon and a single copy icon.
- **Text labels next to icons** wherever space allows (`DESIGN.md` §4.3), especially in Amharic.

### 5.8 Voice and microcopy

- **Tone:** warm and short, in polite, gender-neutral Amharic (the respectful እርስዎ forms).
  - Greet by time of day: እንደምን አደሩ (morning), እንደምን ዋሉ (afternoon), እንደምን አመሹ (evening).
- **No raw errors.** Errors are always friendly, following the `ErrorState` rule.
- **Correct plurals.** Use the Ethiopian month names in Amharic and the transliterated names in English.
- **Ge'ez numerals everywhere** when the setting is on: references, interlinear, the player and plans.
- **A missing Amharic string fails a test,** instead of falling back to English silently.
- **Native-speaker review.** A native speaker reviews every new label, especially the tab names.

---

## 6. Navigation and information architecture

**Proposal: five destinations** (labels to be validated with native speakers).

| Tab | Label (draft) | What it holds |
|---|---|---|
| **Today** | ዛሬ | Greeting and date; verse-of-the-day hero; continue reading or listening; today's plan reading; weekly rhythm; discovery cards |
| **Read** | ንባብ | The reader (immersive), with a study sheet or panel |
| **Plans** | ዕቅዶች | My plans; **Groups** (shared plans, assignments, invites); discover plans |
| **Search & Study** | ፍለጋ | Search, recent and suggested searches, plus study tools: Timeline, People & places, Word study, Ask AI |
| **Me** | የእኔ | Profile and sync status, stats, **Library** (highlights, notes, bookmarks), Downloads, Settings, Help, About |

- **Mobile:** a 5-item navigation bar fits at 320 dp (about 64 dp per item; the Amharic labels are short). The mini
  player sits above it. Both hide while reading immersively.
- **Tablet and desktop** (Material's window-size classes):
  - 600–839: a compact rail.
  - 840–1199: a rail with labels and the logo.
  - 1200 and up: a permanent sidebar with the logo, the destinations, a "Continue reading" chip and the sync status.
  - On wide windows, the screens that today cover the whole window (study, word, entity, timeline, ask, note, player,
    books, group, share image) open **inside the shell**, as panes or side sheets, so navigation and the mini player
    stay visible.
- **This is an information-architecture change, not a styling change.** It changes routes, so per `CLAUDE.md` it needs
  explicit approval. Keep the old paths as redirects (for example, `/me/plans` → `/plans`), and add the new routes to
  `app/test/layout_audit_test.dart`. That list is also missing `/groups/:id` today.

---

## 7. Screen-by-screen plan

Priority: **P0** first release of the redesign · **P1** next · **P2** later.

### 7.1 Onboarding (new) · P0

- **Three skippable steps:**
  1. **Language** (አማርኛ / English), over the logo and ornament.
  2. **Reading comfort:** theme swatches and a text-size slider with a live Ethiopic preview.
  3. **"What brings you here?"** (optional chips): read daily · listen · study deeply · with my church or group. The
     answer personalises Today: a suggested plan, an audio card, study tips, or the groups entry.
- Then open the reader at John 1 (per `DESIGN.md` §8.1), or Today. **No sign-up wall.** Offer sync later, in context.
- **Contextual tips:** one at a time, at most three, each dismissible and remembered:
  - "Tap a verse to highlight, note or share" (first reader visit).
  - "Swipe for the next chapter."
  - "Tap a verse to play from there" (first audio use).
- **Web:** the same flow as a centred card, at most 560 px wide.

### 7.2 Today (Home) · P0

- **Header:**
  - The time-of-day greeting.
  - Weekday and Ethiopian date, with month names in the UI language, and the Gregorian date on request.
  - A search icon, replacing the gear.
- **Continue card, first:**
  - "Continue reading John 3", with a progress bar.
  - "Continue listening" when audio was paused.
  - One tap resumes either.
- **Verse-of-the-day hero:**
  - Gradient or ornament background.
  - The verse in large display Ethiopic, with the reference.
  - Actions: share as image (expands into the share screen), share, listen, open in the reader.
  - A friendly fallback if it fails to load.
- **Today's plan reading:**
  - The plan's cover art, "Day 12 of 90" and a progress ring.
  - A button that opens the reader with a plan context bar.
- **Weekly rhythm:** seven dots for the days read this week, using Ethiopian weekday initials. Days are never "lost";
  the streak stays opt-in and gentle.
- **Discover** (for new users, or anyone without a plan):
  - Plan covers in a horizontal carousel.
  - "Try listening."
  - "Meet the people and places of the Bible."
  - "Ask a question" (when AI is configured).
- **Recently read:** horizontal chips.
- **Web, 840 px and wider:**
  - A two-column dashboard, at most 1200 px wide.
  - Left: the hero and continue cards. Right: plan, rhythm and discover.

### 7.3 Reader · P0

- **Chapter header:**
  - The book name, small and rubricated.
  - A large chapter number (Ge'ez numerals when enabled).
  - A thin haräg rule.
  - The Psalm superscription styled as in §5.3.
- **Immersive mode:**
  - Scrolling down hides the app bar, tab bar and mini player. Scrolling up, or tapping the middle of the text, brings
    them back.
  - A slim reading-progress line stays visible.
  - With the bars hidden, a small floating pill offers ‹ John 3 › and ▶.
- **Changing chapter:**
  - A slide that follows the swipe, with neighbouring chapters preloaded.
  - Large ‹ › arrows in the margins on desktop (as on bible.com).
  - Previous/next cards at the end of the chapter, showing the next chapter's first heading.
- **Selection:**
  - A selected verse gets a clear tinted background and a side bar (not only an underline), with a haptic tick.
  - A **compact action sheet**:
    - Row 1: the 5 highlight colours, plus remove.
    - Row 2: Bookmark · Note · Share · Copy · **More**.
    - **More** opens Study, Compare, Image, Play from here and Ask AI.
  - The sheet never covers the selected verse: it auto-scrolls the verse above itself. The tab bar hides while
    selecting.
  - Study and Ask accept the whole selected range.
  - **Long-press selects a verse** (decided). A plain tap shows or hides the reader's bars.
- **Audio follow-along:**
  - The playing verse gets an indigo tint and a side bar.
  - **Tapping a verse while audio plays seeks to it** (decided); long-press still selects.
  - Auto-scroll pauses after the reader scrolls manually (`DESIGN.md` §8.2).
- **Footnotes:**
  - Superscript letters with a hit area of at least 24 dp.
  - The footnote text opens in a sheet on phones and a popover on desktop.
- **Words of Jesus in red** (confirmed): a softer crimson tuned for each theme to pass AA on every highlight, on by
  default. It only shows where the source marks Jesus' words (`\wj`), so check the full Amharic source for those
  markers.
- **Versions:**
  - The chip shows the abbreviation.
  - The version sheet lists versions with language badges, plus an explicit **Side by side** switch with a
    second-version picker and a layout choice: columns or interleaved.
  - A Listen/Read toggle appears when audio exists for the version.
- **Aa sheet** (one shared component, also used from Settings):
  - A title.
  - **Theme swatches** showing a sample word in each theme.
  - Size slider with a live sample, line spacing, font (with an Ethiopic preview).
  - Display switches: verse numbers, red letters, Ge'ez numerals, headings, interlinear. Interlinear explains how to
    get the pack when it isn't installed.
- **From a plan:** a context bar reads "Day 12 · reading 2 of 3", with **Done / Next reading**.
- **Desktop (1200 px and wider), three regions:**
  - Left: a collapsible book and chapter navigator.
  - Centre: the 680 px column.
  - Right: a **study panel** that follows the selected verse, with tabs for cross-references, notes, original words,
    commentary and Ask AI (like Olive Tree's Resource Guide and Sefaria's connections).
  - Side-by-side uses synchronised columns.
  - At 840–1199 px the study panel becomes a side sheet.

### 7.4 Book picker · P1

- An Old/New Testament segmented control, and books **grouped by genre** (Law, History, Poetry, Prophets, Gospels &
  Acts, Letters, Revelation), each genre with a quiet colour tag.
- **Grid of book cards:** a large abbreviation (ዘፍ), the short name and the chapter count. A grid/list toggle.
- A **recent books** row at the top. The picker scrolls to the current book.
- **Search:**
  - Matches aliases: ዮሐ, John, Jn.
  - Typing a full reference (ዮሐ 3፥16) jumps straight to it.
- **Chapter grid:** read-progress dots, and an optional verse grid.
- **Web:** a popover (mega-menu) attached to the reader's title, with books in columns and chapters inline. The full
  screen stays on phones.

### 7.5 Search & Study · P1

- **Before anyone types,** show an explore page instead of an empty state:
  - The search field.
  - Recent searches, which can be cleared.
  - Suggested searches (ፍቅር, ሰላም, ዮሐ 3፥16).
  - Study tool tiles: Timeline · People & places · Word study (Strong's) · Ask AI.
  - "Search tips" (including the `morph:` / `@` syntax) in a help sheet.
- **Filters:**
  - Collapse into a single **Filter** button that opens a sheet: testament, **book** (already supported by the
    repository), version.
  - Show active filters as removable chips.
- **Results:**
  - Order:
    1. A "Go to passage" card when the query is a reference.
    2. **Verses first.**
    3. Collapsed sections for words, people & places and dictionary entries, each with a count.
  - An honest label: "Showing the first 200".
  - A version badge on each row.
  - Tapping a result opens the reader with the verse briefly highlighted.
- **Search quality:** extend Amharic stemming so ዓለም finds ዓለሙን (`DESIGN.md` §6.4 risk list). This is pipeline and
  search work.
- **Web:** two panes, with the results list on the left and a passage preview on the right.

### 7.6 Study screens · P1

- **Verse study:** a tabbed layout: Original · Cross-references · People & places · Commentary · My notes. Keep the
  "Not Scripture" label on commentary.
- **Interlinear:** proper short glosses; see §11. Tapping a word shows a tooltip with the lemma, gloss and parsing, and
  "Word study" opens the full entry.
- **People & places:** a map card instead of latitude/longitude (an offline vector map of Bible lands with a pin), plus
  related people and places later.
- **Timeline:**
  - A vertical timeline with era bands (Patriarchs, Exodus, Judges, Kingdom, Exile, Return, Jesus, Early Church).
  - Event cards link to their passages.
  - Fix the empty state and give it an action.
- **Ask AI:**
  - A chat-style composer at the bottom, with options (task, level, tradition) as collapsible chips.
  - Auto-scroll to the answer, with a typing or skeleton state while it loads.
  - An "AI-written" badge, and source chips that open their source.
  - Accepts verse ranges. Conversation history later.

### 7.7 Plans (new tab) · P1

- **My plans:**
  - Cards with cover art, a progress ring and "Day x of y".
  - Today's readings as tappable chips.
  - "Behind? Adjust the schedule" with catch-up options.
- **Groups section** (moved from Me):
  - Shared plans, assignments due, and an invite button.
  - Hidden entirely when accounts aren't configured, instead of showing a dead end.
- **Discover:** a grid of covers with duration and category.
- **Plan detail:**
  - A cover hero and the description.
  - A **this-week calendar strip** instead of 365 checkbox rows, with a month view on demand.
  - A clear "Today" button.
  - A completion celebration and a shareable card.
- **Auto-complete a day** once its readings are opened and read to the end (approved).
- **Plan reminders** (P2, not built yet): offer one after the first completed day.

### 7.8 Me and Library · P1

- **Header:**
  - A monogram avatar and display name, or "Guest".
  - A **sync status chip:** "Synced 2 min ago", or "Sign in to back up your notes". This is critical on the web, where
    clearing site data erases unsynced notes.
- **Stats tiles:** days read this month · highlights · notes · plans completed.
- **Library, inline:**
  - A segmented control: Highlights | Notes | Bookmarks.
  - Search, sort, and filters by book, colour and tag.
  - Highlights show both colour and an icon, never colour alone.
  - Swipe to delete, with an **undo snackbar**.
- **Rows, grouped under headers:**
  - **Content:** Downloads (mobile only).
  - **App:** Settings · Help & feedback (new: "Report a text error", `DESIGN.md` §12) · About.
- **Fix:** the Library title bug.

### 7.9 Note editor · P1

- Show the verse(s) at the top, collapsible.
- Autosave the draft, and confirm before discarding unsaved changes.
- Tags as chips with suggestions.
- A small formatting toolbar (bold, italic, list).
- Delete asks for confirmation.

### 7.10 Audio · P1

- **Mini player:**
  - Book-coloured ornament art.
  - The title, respecting the Ge'ez numerals setting.
  - Progress, play/pause, and expand.
- **Full player:**
  - Large generative ornament art for each book.
  - **The current verse text, following along.**
  - A chapter list.
  - Speed and sleep timer as chips.
  - Version and voice.
  - **Download this book**, so it's no longer hidden.
  - "Open in reader".
- **Listening mode** (`DESIGN.md` §4.5, for the listener persona): a simplified Today with one large play button and
  "continue listening". It's offered in onboarding when the reader picks "listen".
- **Web:** a persistent bottom player bar.

### 7.11 Settings · P2

- **Grouped sections:**
  - Language & region: UI language, calendar, Ge'ez numerals.
  - Reading: opens the shared Aa component.
  - Audio & downloads.
  - Reminders & habits: the reminder time at any minute, not just whole hours.
  - Account & privacy.
  - About.
- **No duplicate controls.**

### 7.12 Share image · P2

- Keep the current design and add:
  - An ornament frame option.
  - A text-size control.
  - **Save to gallery.**
  - A choice of reference style.
  - The verse-of-the-day background set.

### 7.13 Groups · P2

- **Header:** the group name, member avatars and a prominent **Invite** button (copy the code or share a link).
- **Discussion:** chat-style, with avatars and the composer at the bottom.
- **Safety:** confirm before deleting. Move "Leave" into the overflow menu.
- **Guidance:** helpful empty states.

### 7.14 System states everywhere · P0 (components)

- **Empty:** a spot illustration, a title, one sentence and a main action.
- **Loading:** skeletons for lists and cards. Keep the centred spinner for full-screen loads.
- **Error:** a friendly message, Retry, and an offline indicator.
- **Destructive actions:** undo by default. A confirmation dialog only for irreversible or blocking actions, which
  matches the existing `CLAUDE.md` rule.
- **The sample-content banner:** a slim, dismissible chip instead of a full-width blue bar on every screen.

---

## 8. Web-specific plan [W]

1. **Layout system:**
   - Wrap every page in a shared width-limited body (page ~840, dashboard ~1200, reader 680).
   - Give buttons and previews maximum widths.
   - Build adaptive **two- and three-pane** layouts: the reader with its study panel, search with a passage preview,
     and the library with a note.
   - Use the 600 / 840 / 1200 / 1600 breakpoints.
2. **Navigation shell:**
   - Below 600: the bar.
   - 600–839: a compact rail.
   - 840–1199: a rail with labels and the logo.
   - 1200 and up: a permanent sidebar with the logo, the destinations, continue reading and the sync status.
   - The full-window screens open inside the shell on wide windows (see §6).
3. **Sheets adapt to the screen** (needs a `CLAUDE.md` rule update):
   - Bottom sheets on phones.
   - Popovers anchored to their button on desktop (Aa, version, footnotes, book picker).
   - Side sheets for study and notes.
   - Dialogs for confirmations.
4. **The URL reflects state:**
   - Each chapter change updates the reader URL, and Back returns to the previous chapter.
   - The search query and the Library tab are kept in the URL.
   - A friendly not-found page in both languages ("Go to Today", search).
   - Malformed links (for example `/note` without parameters) redirect safely.
   - **Path URLs** such as `/read/JHN.3.16` instead of `#/`. The host then needs a rewrite to `index.html`.
5. **Keyboard:**
   - Verses take keyboard focus (arrow keys or J/K), and Enter opens the verse actions.
   - ← / → for chapters.
   - `/` or Ctrl+K for a "Go to" palette that accepts references (ዮሐ 3፥16, Jn 3:16).
   - Space to play or pause.
   - Esc clears the selection or closes a panel.
   - `?` for a shortcuts help sheet.
   - **Ctrl+F opens in-chapter find,** because the browser can't search canvas-rendered text.
   - A visible focus ring in the theme.
6. **Mouse:**
   - Dragging selects text with the mouse instead of flipping the chapter; swipe stays for touch only.
   - Copied text includes the reference and version.
   - Hover states on cards, rows and verses. The hand cursor appears only on real controls.
   - Tooltips on every icon button.
   - Right-click on a verse opens the verse actions.
   - Visible scrollbars.
7. **Browser integration:**
   - Per-route titles in the UI language ("ዮሐንስ 3 · መጽሐፍ ቅዱስ").
   - Open Graph and Twitter preview tags with a branded preview image.
   - `theme-color`.
   - A manifest with `id`, `scope`, `lang` and shortcuts.
   - An install prompt (PWA) from Me.
   - Detect the browser language on the first visit, then confirm it in onboarding.
8. **Offline and durability:**
   - A service worker that caches the app shell, so the web app opens offline.
   - Request persistent storage.
   - Open the cached content database before going to the network.
   - Bundle subset Hebrew and Greek fonts (OFL Noto) and a thin-space fallback, so original-language text works
     offline.
   - An offline indicator.
9. **Honest web messaging:**
   - Explain mobile-only features ("Study packs and offline audio are in the Android and iOS app"), with "Get the app"
     links.
   - The Share fallback becomes "Copy link" or "Download image" with honest labels, not `mailto:`.
   - Device-neutral wording ("select a verse", not "tap").
10. **First load:**
    - A **branded splash inside `index.html`**: logo, ornament, an Ethiopic tagline and a progress bar, removed once
      Flutter paints.
    - Start the UI before all setup finishes (Today with skeletons while the databases open).
    - Subset the fonts and drop unused locale data.
    - Defer study, AI, share and groups code (deferred imports).
    - Evaluate `flutter build web --wasm`: skwasm, falling back to CanvasKit. Check compatibility with the
      sqflite web worker first.
    - Measure with Lighthouse on a throttled 3G profile.
11. **Static chapter pages (approved, Phase 6):** indexable HTML chapter pages generated by the pipeline. They load instantly
   on slow networks, show up in Google results for "ዮሐንስ 3:16" and link into the app. Flutter web alone can't be
   indexed.

---

## 9. Mobile-specific plan [M]

- **App icon:** an adaptive icon with a monochrome layer for Android 13+ themed icons, and a matching iOS icon.
- **Splash:** the Android 12+ splash API and an iOS LaunchScreen, both showing the logo on brand green (or parchment in
  light mode).
- **System chrome:**
  - Edge-to-edge, with transparent system bars styled per reading theme.
  - A modern Android launch theme instead of the old holo theme.
  - Predictive back on Android 14+: use a page transition that supports the back preview instead of forcing a fade.
  - Verify iOS swipe-back with the fade transition; if it breaks, use the Cupertino transition on iOS.
  - Back clears a verse selection first, and the note editor asks before discarding.
- **Identity details:** a monochrome notification icon, iOS `CFBundleName` "መጽሐፍ ቅዱስ", and a dark launch-screen
  variant.
- **Links:** Android App Links and iOS Universal Links for the web domain, so a shared `/read/JHN.3.16` link opens the
  app when it's installed.
- **Feel:**
  - Haptics as described in §5.6.
  - The immersive reader.
  - Pull to refresh where data can be synced (Groups, sync status).
- **Later (P2):**
  - A verse-of-the-day home-screen widget, as YouVersion has.
  - Plan reminder notifications.
  - A "continue listening" media notification that deep-links into the reader.
- **Low-end budget:**
  - Keep illustrations as vectors and photos optional.
  - Keep animations to opacity and transform.
  - Test on a 2 GB Android device (`DESIGN.md` §9).

---

## 10. Accessibility and inclusion [B]

- **Contrast:**
  - Fix all of §3.7.
  - Add a **contrast unit test**: every text style × every highlight × every theme, at 4.5:1 or better.
- **Selection and highlights:** convey them with a shape (side bar or background), not colour alone. Highlight filters
  show both colour and name.
- **Screen readers:**
  - Each verse is announced with its reference, in the UI language: "ዮሐንስ ምዕራፍ 3 ቁጥር 16, …" or "John chapter 3
    verse 16, …".
  - Footnotes, bookmarks, notes and highlights are labeled ("Highlighted yellow", with Amharic colour names in
    Amharic).
  - Selection, loading and the playing verse are announced (live regions).
  - Fix the labels: Play, Pause and Stop each say what they do, and "Back 10 seconds" replaces "−10s".
  - Label the icon-only segments.
  - Decorative art is excluded.
  - On the web, semantics come on for screen-reader users without the hidden button. Weigh the performance cost of
    turning them on for everyone.
- **Keyboard:** every action can be reached without a mouse or touch, including the verse actions (see §8).
- **Text scale:** extend the layout audit to **2.0×** for key routes (Today, Reader, Selection, Aa, Plans, Me),
  following `DESIGN.md` §4.5.
- **Motion:** honour reduced-motion settings and provide no-motion alternatives for every transition.
- **Focus (web):** visible focus rings, a logical tab order, and a skip link to the content.
- **Listening mode** for low-literacy and older users (§7.10).

---

## 11. Trust and content credibility [B]

- **Interlinear glosses.**
  - Replace the "first KJV rendering" approach (`app/lib/domain/study.dart:44`) with a dataset built for glosses, such
    as STEPBible's TBESG/TBESH brief lexicons (CC BY 4.0). Do this in the pipeline, and add the attribution in About.
  - Fix the parenthesis truncation.
  - Until then, show the lemma's main definition, not the alphabetical first KJV rendering.
- **Labels:** keep "Not Scripture" on commentary and "AI-written" on answers, and make both visually consistent
  (`StatusBadge` tones).
- **No raw errors or exception text** anywhere. Data-loss paths always offer undo or a confirmation.
- **Web data safety:** request persistent storage, show the sync status in Me, and nudge web readers to sign in so
  their notes are backed up (see §8).
- **Show the source attribution** at the end of each chapter in a quiet footer: version, copyright or licence. This is
  standard in serious Bible apps and builds trust.

---

## 12. Where the work lands (design-system changes)

- **`ui/tokens/tokens.dart`:**
  - `AppRadius.xxl`.
  - Content max widths (page, dashboard).
  - Breakpoints 600/840/1200/1600.
  - Use the existing unused tokens (`AppMotion.medium`, `AppElevation.card`, `AppDimens.selectedBorder`).
- **`ui/theme/app_theme.dart`:**
  - A hand-tuned colour scheme for each reading theme.
  - Component themes for Switch, Slider, Checkbox, Radio, TabBar indicator, NavigationBar (height, labels), SearchBar,
    Badge, Scrollbar (web), text selection, Tooltip and ExpansionTile.
  - App bar separation on scroll.
  - Explicit font weights for the variable fonts.
- **`ui/theme/app_colors.dart`:**
  - Four highlight sets.
  - A red-letter colour per theme.
  - New roles: now-playing, ornament, gradients, genre tags.
  - Retuned semantic colours.
- **New shared widgets** (`ui/widgets/`, following the naming rules):
  - Cards and tiles: `HeroCard`, `FeatureTile`, `StatTile`, `PlanCover`.
  - Ornament: `Ornament` (haräg band and roundel).
  - States: `EmptyState` gains an illustration slot; new `SkeletonList`.
  - Control wrappers: `AppSwitchTile`, `AppSlider`, `AppSegmented` (today screens use these controls raw).
  - Small pieces: `AppTabs`, `Avatar`, `CountBadge`, `SyncStatusChip`, `CoachMark`.
  - Layout: `PageBody` (width-limited), `AdaptivePanes`, `AdaptiveSheet` (bottom sheet, popover or side sheet).
  - Web: `ShortcutScope`.
- **`CLAUDE.md` updates** (needs your approval, because they change rules):
  - The new token values and widget inventory.
  - "Skeletons for content lists; spinner for full-screen loads."
  - "Adaptive sheets: bottom sheet on phones, popover or side sheet on desktop."
  - The desktop breakpoints.
- **Tests:**
  - Extend `test/layout_audit_test.dart`: the new routes, `/groups/:id`, 2.0× text, a 1440 px desktop size, and the
    "system" theme.
  - Add **golden tests** for about 12 key screens × 4 themes × 2 languages, at phone and desktop sizes.
  - Add the **contrast test**.

---

## 13. Roadmap

Rough effort assumes 1–2 developers plus part-time design. Every phase ends with `flutter analyze` clean, the layout
audit and goldens green, and a manual check on Android, iOS and Chrome.

| Phase | Scope | Effort | Exit criteria |
|---|---|---|---|
| **1. Foundations & trust** | Brand decisions (made, §15); tokens and theme; contrast fixes; icon, splash, favicon and notification icon (once the illustrator's logo arrives); copy and trust fixes (glosses, undo/confirm, note-editor and back-button guards, raw errors, plurals, titles); web `index.html` splash, per-route titles, reader URL follows chapters, persistent storage; golden and contrast test harness | 2 weeks | No stock assets left; contrast test passes; goldens recorded |
| **2. Today, onboarding, navigation** | 5-tab structure with redirects; Today screen; onboarding with tips; Me/Library hub; width-limited pages and new navigation shell on web | 2–3 weeks | Usability test: new users find a plan, audio and a highlight unaided |
| **3. Reader & audio** | Chapter header, immersive mode, chapter transitions, selection sheet, Aa sheet, footnotes, plan context bar; mini and full player with follow-along text; listening mode | 3 weeks | Selection never covers the verse; 2.0× text audit passes on the reader |
| **4. Desktop web** | Three-pane reader with study panel; full-window screens moved inside the shell; popovers; keyboard-focusable verses, shortcuts and Go-to palette; mouse text selection, hover and right-click; path URLs and a not-found page; Open Graph tags; offline app shell and Hebrew/Greek fonts; honest web messaging; PWA prompt; wasm evaluation; deferred loading | 3 weeks | Every verse action works by keyboard alone; Lighthouse accessibility and best practices ≥90; first paint (splash) <1 s on throttled 3G |
| **5. Explore, Plans, Groups polish** | Search & Study explore page and filters; study tabs, map, timeline, Ask AI composer; Plans tab with covers, week strip and auto-complete; Groups polish; Settings regrouping; share-image additions | 3 weeks | Word study ≤3 taps; plan start ≤2 taps from Today |
| **6. Delight & growth** (ongoing) | Illustrations and plan covers; verse-of-the-day widget; plan reminders; photo backgrounds; static SEO chapter pages; Amharic stemming improvements | ongoing | Retention and engagement metrics trend up (§14) |

---

## 14. How we'll know it worked

- **Usability tests** with 5 people per persona (daily reader, listener or older reader, church leader or student,
  diaspora user), in Amharic, before and after. Tasks:
  1. Find John 3:16.
  2. Highlight it and add a note.
  3. Start a plan.
  4. Play audio from a verse.
  5. Look up a word's meaning.
  6. Share a verse image.
  7. Find something on desktop.

  Measure the success rate, time on task and a SUS score.
- **Native-speaker review** of every Amharic string and label, and a proofreading pass on headings and book names
  (`DESIGN.md` §11).
- **Opt-in, privacy-preserving metrics** (`DESIGN.md` §5.1, §10):
  - Onboarding completion.
  - D1/D7/D30 retention.
  - Plans started and days completed.
  - Audio plays.
  - Search followed by opening a result.
  - Shares.
  - Reminder opt-ins.
- **Quality gates per phase:**
  - `flutter analyze`.
  - `flutter test` (layout audit, goldens, contrast).
  - Lighthouse on the web build.
  - A manual pass with TalkBack, VoiceOver and NVDA.
  - A low-end Android device check.

---

## 15. Decisions (made 2026-11-03)

1. **Brand direction:** "Illuminated manuscript, modern".
2. **Logo:** an open book framed by haräg interlace.
3. **Navigation:** five tabs: Today · Read · Plans · Search & Study · Me.
4. **Artwork:** commission an Ethiopian illustrator for the logo, ornaments, plan covers and empty-state
   illustrations. Work that needs the logo (app icon, splash screens, favicon, notification icon) waits for it.
5. **Behaviour changes (all approved):**
   - Auto-complete plan days.
   - Long-press selects a verse; a tap shows or hides the reader's bars.
   - Tapping a verse while audio plays seeks to it.
   - Groups move into the Plans tab.
   - Words of Jesus in red stay on by default, with the colour tuned for every theme.
6. **Web scope (all approved):** clean path URLs (the host needs a rewrite rule), static chapter pages from the
   pipeline, a WebAssembly build (after a compatibility check) and an offline web app.
7. **Next:** Phase 1 has started.

---

## 16. Progress

### Phase 1 (started 2026-11-03)

**Done:**

- **Palette and themes:**
  - Manuscript green, ochre, rubric red and indigo, defined for each of the four reading themes.
  - A warm page with white (or cream) cards that clearly stand apart; app bars tint when content scrolls under them.
  - The reader sits on its own "paper" color.
  - Sepia and black have their own highlight sets.
  - `test/contrast_test.dart` checks scripture, red letters and verse numbers on every highlight in every theme.
- **Reading cues:**
  - Selected verses get a tint as well as the underline.
  - The playing verse uses an indigo tint (no more red on green).
  - Psalm titles no longer use a fake italic.
- **Trust and copy:**
  - Undo after removing a bookmark.
  - Confirmations before deleting notes, group messages and downloaded audio.
  - The note editor guards unsaved changes.
  - Back clears a verse selection.
  - Friendly errors on the account screen.
  - The Library title, the timeline's empty state and plurals are fixed.
  - "First 200 results" when search stops at its cap.
  - Ethiopian dates in English use transliterated months ("Tikimt 24, 2019 EC").
  - `test/strings_test.dart` fails on any untranslated string.
- **Accessibility:**
  - Verse numbers are announced with the full reference in the UI language.
  - Highlight swatches use localized color names.
  - Play, Pause, Stop and ±10 s have proper labels.
  - Icon-only segments are labeled.
- **Interlinear glosses:** taken from the STEPBible brief lexicons (CC BY 4.0), by Hebrew word sense where the text marks one. θεός is now "God", not "exceeding"; Genesis 1:2 reads "to hover".
- **Web:**
  - A branded loading screen.
  - `theme-color` and link-preview tags.
  - A browser tab title per page.
  - The reader's address follows chapter changes.
  - A friendly not-found page, and a safe redirect for incomplete note links.
  - Persistent storage is requested after the first local change.
- **iOS:** `CFBundleName` set to "መጽሐፍ ቅዱስ".

**Open:**

- **Waiting for the illustrator's logo:** app icon, splash screens, favicon and notification icon.
- **Content source (found during Phase 1):** eBible's `amh` text is the **New Testament only**. It is © 1962/2003 United
  Bible Societies, free for non-commercial use with the full copyright notice, and commercial use needs permission
  from the Bible Society of Ethiopia. Find a full text and settle its terms before release (recorded in
  `content/versions.json`).
- **Words of Jesus in red (decided: verse-level now, exact later):** that text has no `\wj` markup, so the pipeline now
  marks a whole verse red wherever WEB marks words of Jesus (`red_letters_from`): 1,986 New Testament verses on the
  real eBible text. A source with its own markup replaces this automatically.
- **Full WEB text fails validation:** five verses that WEB moves to footnotes (Luke 17:36, Acts 8:37, Acts 15:34,
  Acts 24:7, Romans 16:25) count as "empty verse" errors, so a full build with the real WEB source stops. Decide how
  the validator should treat verses a translation deliberately omits.
- **Golden screenshot tests:** they need a decision on where to generate them, because fonts render differently on
  Windows and Linux (CI).

### Phase 2 (started 2026-11-03)

**Done:**

- **Navigation:** five tabs (Today · Read · Plans · Search & Study · Me). Plans and Groups have their own tab, and the
  old `/me/plans…` and `/me/groups` addresses redirect.
- **Shell:** a bottom bar on phones, a rail from 600 px, and a sidebar with the app's name from 1200 px. Page content
  is centered at 840 px on wide windows (`AppListView`, `ContentWidth`).
- **Today:**
  - A greeting and the weekday with the date.
  - Continue reading first.
  - The verse of the day as a parchment hero card with an ornament rule.
  - A start-a-plan card while there is no plan.
  - This week's reading days.
- **Welcome steps on a fresh install:**
  - Language.
  - Reading comfort: the reader's own text settings, applied live.
  - Where to begin.

  Every step can be skipped, and installs from before the welcome skip it.
- **Me:** an account header (guest or signed in, with a sync nudge), library counts, and grouped Study and App
  sections.
- **New shared widgets:** `HeroCard`, `OrnamentRule`, `StatTile`, `ContentWidth`.

### Phase 3 (started 2026-11-03)

**Done:**

- **Chapter header:** the book's name in rubric red, a large chapter number and an ornament rule.
- **Gestures on phones:**
  - Press and hold selects a verse, with a haptic tick.
  - While a selection is open, a tap adds to it.
  - While audio or read-aloud plays, a tap jumps to the verse.
  - Otherwise a tap shows or hides the bars.

  On the web and with a screen reader, a tap still selects.
- **Immersive reading:** scrolling down slides the app bar and the tab bar away, and scrolling up brings them back.
- **Verse actions:** one short row (Bookmark · Note · Share · Copy · More). More holds Study, Compare, Image and
  Listen. A newly selected verse is scrolled clear of the bar.
- **A one-time gesture tip** inside the chapter. Everyone sees it once, since selecting moved to a long press.
- **Aa sheet:** a title, theme swatches that show each theme's page, and the verse-number, red-letter and Ge'ez-numeral
  switches.
- **Layout audit:** the reader now passes at 2× text in both languages, including with a verse selected.

- **Audio player:**
  - A cover with the book and chapter on the parchment gradient.
  - The verse being read, shown as it plays (when the recording has verse timings).
  - "Open in reader".
- **Today:** a play button on Continue reading starts the chapter (the recording, or the phone's voice). This is the
  lightweight take on "listening mode".
- **Footnotes:** markers are real buttons, with a larger target and a "Footnote" label for screen readers.
- **Plan bar:** a plan's reading links carry the plan and day. The reader then shows "plan · Day n of N" with a
  mark-as-read button, and keeps it while moving between chapters.

**Left for later:**

- Illustrated covers for the player and the plans (illustrator).
- Automatically completing a plan day (Phase 5, approved).

### Phase 4 (started 2026-11-03)

**Done:**

- **Keyboard in the reader:** ← and → change chapter, Esc clears a selection, and `/` opens search.
- **Mouse on the web:** dragging selects and copies Scripture; chapter swiping is touch-only, so a drag no longer
  flips the page; a click still selects a verse.
- **Clean addresses:** `/read?ref=JHN.3` instead of `/#/read…`. Old `#/` links are moved over on load, and README
  lists what each host needs.
- **Honest web behavior:**
  - Share copies the text where the browser has no share sheet, instead of opening an email.
  - Read-aloud explains a missing *browser* voice.
  - Verse study says the study packs are in the Android and iOS app.
- **Three panes on wide desktops:** from 1360 px the reader has a study panel beside the text (navigation · text ·
  study). It follows the first selected verse (original text, cross-references, people and places, commentary, with
  Ask); with nothing selected it says how to choose a verse.
- **Go to (Ctrl+K or ⌘K)** from anywhere: a reference ("ዮሐ 3፥16", "Jn 3:16") opens the reader there; anything else
  opens search. Search addresses carry the query (`/search?q=…`), so a search can be linked and bookmarked.
- **Offline web app:** after one visit the web app opens without a connection.
  - `web/sw.js` keeps the page, the app's files, CanvasKit and the fallback fonts. The app's own files come from the
    network first, so an online visit always runs one consistent release.
  - On the first visit the page tells the worker what it has already loaded, so one visit is enough.
  - `web/flutter_bootstrap.js` starts the app without Flutter's own service worker, which is deprecated, unregisters
    itself and would replace `sw.js`.
  - Checked in a fresh browser: one visit, then the server stopped; a link to John 3 opened from the kept copy in under
    a second. On a host without rewrites, app addresses work once the worker is installed.
- **Screens opened over the tabs keep the navigation** on wide windows: verse study, words, people and places, the
  timeline, Ask, group pages and the player. The sidebar stays still while the content fades in, and it shows the tab
  the screen came from; choosing a tab closes these screens and returns to where the reader was in that tab. Focused
  tasks (writing a note, making an image, choosing a book, the welcome steps) still cover the window, and phones are
  unchanged. A screen keeps its state when a phone turns sideways.

**Done (web polish, after Phase 5):**

- **Greek and Hebrew fonts bundled:** Noto Serif cut down to Greek (95 KB instead of 712 KB, polytonic accents
  included) and Noto Serif Hebrew (30 KB, with every point and accent), as fallbacks in every text style. On a cold
  first visit the original-language text shows at once, where it showed boxes for over two seconds while the
  browser fetched a font, and it works offline. Checked against every Greek and Hebrew character in the content.
- **Hover and right-click on verses:** the verse under the mouse is lightly tinted; a right-click selects it and opens
  the verse actions as a menu at the pointer (bookmark, note, share, copy, study, compare, image, listen), the same
  list as the selection bar's (`verseActions`). The browser's own menu is held back only over verses.
- **Install prompt:** when the browser offers to install the app (Chrome, Edge, Android), Me shows "Install the app";
  it goes away once installed. The manifest gained an `id`, `scope`, `lang`, shortcuts (Read, Search, Plans), the
  page's color for the splash, and no longer locks the installed app to portrait.

**Left for Phase 4:**

- Popovers instead of bottom sheets on desktop.
- WebAssembly evaluation and deferred loading.
- A two-column Today, and app bars aligned with the centered content on desktop.

**Left for later phases:**

- The other two contextual tips from §7.1: swipe for the next chapter, and tap a verse to play from there.

### Phase 5 (started 2026-11-03)

**Done (part 1: Search & Study, Plans):**

- **Explore page:** before anything is typed, Search & Study shows:
  - The study tools: Word study, People & places, the Bible timeline (moved from Me), and Ask AI, which asks which
    passage first.
  - Recent searches, which can be cleared.
  - Searches to try, in the language of the version being searched.
  - Search tips (references, words, phrases in quotes, Strong's numbers, grammar codes).
- **Word study page** (`/words`): key Greek and Hebrew words (love, faith, grace, peace, word, life, spirit…) and a
  lookup by word, meaning or Strong's number. Word study is two taps from the Search tab (exit criterion: ≤3).
- **People & places page** (`/people`): the most-mentioned people, places and events, by kind, with a name search.
- **Filters:** one Filter button opens a sheet (testament, book, all versions); filters in use show as removable
  chips.
- **Results, one kind at a time:** chips with counts (Verses · 87, Words · 6, People & places · 1, Dictionary · 1)
  replace stacked sections, because a 200-verse list would push collapsed sections out of reach. The "Go to"
  card stays first; all-versions results carry the version as a badge.
- **Arrival tint:** a verse opened from search or a link is tinted for two seconds.
- **Plans:**
  - A plan day marks itself read once the end of each of its chapters has been on screen for five seconds, with
    Undo (approved in §15).
  - The plan page shows a strip of its days (read ones checked, the next one outlined) and the chosen day's readings
    with Mark as read, instead of 365 checkbox rows.
  - Today offers *The Gospels in 30 days* with a one-tap Start (exit criterion: plan start ≤2 taps).
- **Fixed along the way:** word lists showed the first KJV rendering as the meaning (θεός "exceeding", λόγος
  "account"); they now use the STEPBible glosses, also shown on the word study page.

**Done (part 2: study screens):**

- **Verse study in tabs:** Original text (words, then variants) · Cross-references · People & places · Commentary ·
  My notes, with counts. The verse stays above the tabs, which stay pinned while scrolling. Tabs with nothing in them
  are left out, and each tab credits its own sources. The chosen tab is kept for the next verse, so the desktop panel
  stays on Cross-references while the selection moves. My notes lists the notes covering the verse and offers
  "Write a note".
- **Timeline in eras:** tinted bands (Beginnings, the patriarchs, Exodus, the judges, the kingdom, exile, return,
  between the Testaments, the life of Jesus, the early church) over the dated events. Eras with no events are left
  out. The boundaries follow the data's traditional dating and are approximate.
- **Ask as a conversation:** the four tasks (Explain, Summarize, Study questions, Sermon help) are one-tap chips
  above a question field at the bottom. Level and tradition are in an options sheet, and their chip shows the
  current choice. Each exchange shows the request, then a placeholder while the answer is written, then an
  "AI-written" badge and the answer, scrolled into view. Cited sources are chips that open the source, with
  "Open in reader" for verses. The conversation lasts while the screen is open.
- **Places:** a "Show on a map" button (OpenStreetMap, with a pin) under the coordinates.

**Done (part 3: Groups, Settings, share image):**

- **Groups:**
  - A header under the title: members' initials and their count, and an Invite button that opens the code with
    Share, Copy and (for teachers) a new code.
  - The discussion reads as a conversation: your messages on one side, others' on the other with their initial, the
    newest by the composer at the bottom (above the keyboard).
  - "Leave group" moved from beside the title into the menu, still confirmed.
  - The empty discussion invites a first message.
- **Settings in sections:** Language and region (language, Ethiopian calendar, Ge'ez numerals) · Reading (version,
  side by side, and "Reading appearance", which opens the Aa sheet instead of repeating its controls) · Reminders and
  habits · Audio and downloads · Privacy. The daily reminder is set to the minute on a time wheel in a sheet, not only
  on the hour.
- **Share image:**
  - Text size (smaller, default, larger).
  - An ornament frame (a placeholder for the illustrator's haräg border).
  - With or without the version in the reference.
  - An illuminated background matching the verse-of-the-day card.
  - Backgrounds wrap instead of scrolling sideways, so all nine stay in reach (a mouse can't drag a row sideways).
- **Shared:** `MonogramAvatar` (the reader on Me, group members).

**Done (part 4: plans):**

- **Behind? Adjust the schedule:** when days before today were not read, the plan page offers two ways back:
  pick up where you left off (the schedule moves so the next unread day is today), or mark the missed days read
  (read elsewhere). Both keep what was read and sync like any other change. The "behind" count is now exactly the
  missed days (it was one short when today's reading was already done).
- **All days:** every week of the plan with its dates, a progress ring and how many days were read; choosing a week
  shows its first unread day in the strip. A list of weeks rather than a month grid: seven columns would make the
  days smaller than a 48dp target on phones, and the Ethiopian calendar setting keeps working through the dates.
- **Finishing a plan:** reading the last day opens a celebration with a square card to share (the plan's name and
  length on the illuminated background, in the ornament frame) and "Choose another plan". The plan page keeps a
  "Plan complete" card with Share.

**Left for Phase 5:**

- Save the verse image to the gallery: needs a native plugin and photo-library permissions on Android and iOS,
  tested on devices. Until then the share sheet offers saving on phones, and the web downloads the image.
- An offline map card for places (a simplified coastline of Bible lands from Natural Earth, built by the content
  pipeline); for now the map opens online.
- Plans: covers (illustrator).
- Search: a passage preview beside the results on wide windows; Amharic stemming (pipeline).

**Content gaps found:** people and places have English names only, so typing an Amharic name finds nothing; the
explore page lists them to browse instead. Amharic names belong in the content pipeline.

### Phase 6 (started 2026-11-03)

**Done:**

- **Static chapter pages:** `pipeline/build_site.py` runs after `flutter build web` and writes a plain HTML page for
  every chapter (`bible/<version>/<book>/<chapter>/`), with indexes of versions, books and chapters.
  - Each page has the chapter with its headings, poetry indents, words of Jesus in red and footnotes, an anchor per
    verse (`…/jhn/3/#v16`), the previous and next chapters, the version's credit, and "Open in the app", which opens
    the reader at that chapter.
  - The page's own words are in Amharic for Amharic versions and in English otherwise; Hebrew reads right to left.
  - With the site's address it adds canonical links, a sitemap and `robots.txt`; every page has link-preview tags.
  - The pages use the app's reading colors, light and dark, and need no script.
  - Only versions whose license is confirmed get pages, as in the database build.
  - Offline, a chapter page's address opens the app's reader at that chapter.
- **Repeat visits start from the kept copy:** the same script stamps the release's file list, with content hashes,
  into the built `sw.js`.
  - When the worker installs, it keeps the whole release and its page, and the app starts from that copy: a repeat
    visit asks the network for none of the app's files and doesn't wait for the page, however slow the connection.
  - A new release downloads in the background and waits, so an open app never mixes two releases. It takes over the
    next time the app starts in a tab of its own (the page asks before loading the app), or once the app's tabs have
    closed.
  - CanvasKit copies for older engines are dropped.
  - A plain `flutter build web` (no stamp) behaves as in Phase 4.
- CI adds the pages and the stamp to the `web-sample-content` artifact.
- **Checked in Chrome** against a local server's request log:
  - A repeat visit to `/read` made one request, the browser's routine check of `sw.js`, and the app started in
    about 0.7 s.
  - A new release downloaded in the background, costing a "not modified" answer for each unchanged file, and took
    over at the next start in about 1.8 s. The extra second is Chrome's own pause before it activates a new worker.
  - With a second tab open, the old release kept running and the new one waited.
  - Offline, a link to John 3:16 and a chapter page's address both opened the reader.
  - Online, the chapter page came from the server, and "Open in the app" opened the reader from the kept copy.

  Found while checking: a takeover that starts while the app is loading can leave the app stuck on its loading
  screen, so the page says "go" only while it is still holding the app back.

**Waiting:**

- The Amharic pages, which matter most for search ("ዮሐንስ 3:16"), are left out until the Amharic text's license is
  settled (it still says "verify"; see Phase 1).
- A link-preview image for the pages and the app, once the logo exists.

---

## Sources

- [Bible app design patterns (screensdesign.com)](https://screensdesign.com/articles/bible-app-design/): YouVersion
  Today feed and streaks, Hallow onboarding cards, Dwell Listen/Read switch.
- [YouVersion Bible App 8.18.2 release notes (APKMirror)](https://apkmirror.com/apk/life-church/bible/bible-8-18-2-release):
  verse-of-the-day widgets, simplified sign-in.
- [Introducing the new Quran.com (Tarteel)](https://tarteel.ai/blog/quran-com-and-tarteel-partnership-an-all-new-quran-com/)
  and [Quran.com translation reading mode](https://quran.com/product-updates/new-translation-reading-mode-read-like-a-book).
- [Quran.com: simplifying word-by-word and audio settings](https://quran.com/product-updates/simplifying-word-by-word-and-audio-settings).
- [Sefaria: connections in the Library app](https://help.sefaria.org/hc/en-us/articles/19815191391388-How-to-Access-Connections-on-the-Sefaria-Library-App).
- [Dwell review (Knowable Word)](https://knowableword.com/2018/08/31/dwell-a-deeply-satisfying-audio-bible-app) and
  [Dwell on AppleVis](https://applevis.com/apps/ios/reference/dwell-audio-bible).
- [Arganonä Maryam prayer book, haräg ornament (The Met)](https://metmuseum.org/toah/works-of-art/2006.99) and
  [prayer book with case, haräg colours (The Met)](https://www.metmuseum.org/art/collection/search/307602).
- [Kedus Bible (App Store)](https://apps.apple.com/us/app/kedus-bible/id1501044432) and
  [Kedus Bible (AppBrain)](https://www.appbrain.com/app/kedus-bible/com.aevue.kedus_bible_flutter).
- [Biblica Amharic Bible (AppGoblin)](https://appgoblin.info/apps/com.biblica.amharic).
- [Flutter web renderers (docs.flutter.dev)](https://docs.flutter.dev/platform-integration/web/renderers.html).
- [material_3_expressive (pub.dev, third-party)](https://pub.dev/packages/material_3_expressive).
