# CLAUDE.md

Amharic Bible: an offline-first Flutter app for Android, iOS and the web (`app/`), a Python content pipeline (`pipeline/`), an audio proxy
(`server/audio-proxy/`), an AI study assistant (`server/study-assistant/`) and a Supabase sync schema
(`server/supabase/`). See `README.md` and `docs/DESIGN.md`.

## Commands

- App: `cd app && flutter analyze && flutter test` (format: `dart format lib test`, page width 120)
- Web app: `cd app && flutter build web --release` (or `flutter run -d chrome`). Platform-only features are gated
  with `kIsWeb` (no file system, notifications or background-audio plugin on the web). Offline support is
  `web/sw.js` (registered in `web/index.html`; `web/flutter_bootstrap.js` keeps Flutter's deprecated service worker
  out): check changes to it in a release build, offline, with the server stopped
- Pipeline: `python -m unittest discover -s pipeline/tests`
- Audio proxy: `node --test server/audio-proxy/proxy.test.mjs`
- Study assistant: `cd server/study-assistant && npm ci && npm test`
- Sync SQL: `cd server/supabase/test && npm ci && npm test`

## UI & Layout Standards (Flutter)

* Tokens: All colors, text styles, spacing, radii, and component heights come from ThemeData/ThemeExtension and the AppSpacing/AppDimens constants. Never use inline `Color(0xFF...)`, inline `TextStyle(...)`, or raw numbers in `EdgeInsets`/`SizedBox` in screens.
* Grid & Spacing: 8pt grid (multiples of 4/8). One standard horizontal screen padding app-wide. Spacing between elements uses AppSpacing constants only.
* Alignment: Screen titles, sections, and content share the same left edge. All inputs share consistent height; icons are vertically centered with text. Left-align content by default.
* Buttons: Never style raw ElevatedButton/TextButton/OutlinedButton in screens. Always use the shared `AppButton` variants (primary/secondary/outline/ghost/destructive). Standard heights sm 36 / md 48 / lg 56; minimum 48x48dp touch targets.
* Screen Structure: Every screen uses `AppScaffold` → app bar → body with standard padding → optional bottom action area. SafeArea and keyboard insets handled by the shared scaffold, not per-screen.
* Forms: Use shared `AppTextField`/`AppFormField` etc. One validation-error style. Keyboard-aware scrolling on every form.
* Lists & Cards: Use shared `AppCard`, `AppListTile`, `StatusBadge`. Shared `EmptyState`/`LoadingState`/`ErrorState` on every screen — never ad-hoc.
* Dialogs & Sheets: Use shared `AppDialog`/`AppBottomSheet` with standard padding and action placement.
* Components First: Before writing new UI, check for an existing shared widget and extend it. Never duplicate with slight variations.
* Layout: Prefer Column/Row/Flex → Stack only when genuinely necessary. No fixed heights that break with the keyboard or large fonts; layouts must survive textScaleFactor 1.3.
* Functionality: Styling changes must never alter business logic, state management, routes, validation, or permissions.
* Quality gate: `flutter analyze` clean before finishing any UI task.

All future UI work in this repository must follow this CLAUDE.md section.

### Project conventions (Amharic Bible)

**Where things live** — screens import one barrel: `import '../../ui/ui.dart';`

| Path | Contents |
|---|---|
| `app/lib/ui/tokens/tokens.dart` | `AppSpacing`, `AppRadius`, `AppElevation`, `AppOpacity`, `AppIconSize`, `AppDimens`, `AppMotion`, `AppFonts`, `context.isCompact` |
| `app/lib/ui/tokens/share_card_tokens.dart` | Share-image card palette and sizes (documented exception, below) |
| `app/lib/ui/theme/app_theme.dart` | `buildAppTheme(...)`: TextTheme + every component theme, for the light / sepia / dark / black reading themes |
| `app/lib/ui/theme/app_colors.dart` | ThemeExtensions `AppColors`, one set per reading theme (success/warning/info + containers, the reader's `paper`, the `playing` and `selection` verse tints, highlight colors, red letters) and `ReadingStyles` (scripture styles that follow the user's text-size/font/line-spacing settings); `context.colors`, `context.text`, `context.appColors`, `context.reading`, `context.scriptureSnippet`, `context.scriptureFeature` |
| `app/lib/ui/widgets/` | Shared widgets (inventory below) |
| `app/lib/core/strings.dart` | All UI text, Amharic + English. No literal user-facing strings in widgets |

**Token values**

| Token | Values |
|---|---|
| Spacing | xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · xxxl 48 · `screen` 16 (all screens, including the reader) · `section` 24 · `iconGap` 8 |
| Radius | sm 8 (chips, swatches) · md 12 (cards, inputs, buttons, menus) · lg 16 (dialogs) · hero 24 (hero cards) · xl 28 (bottom sheets) |
| Elevation | flat 0 · card 1 · bar 3 · dialog 6 |
| Icons | sm 18 · md 24 · lg 32 · xl 48 · hero 96 |
| Heights | buttons 36 / 48 / 56 · input 56 · list tile 56 / 72 · app bar 56 · touch target 48 |
| Layout | reading column max 680 (×2 side by side) · page content max 840 (`AppListView` / `ContentWidth` center it) · two columns from 600 · navigation rail from 600, sidebar from 1200 · reader study panel 360 wide from 1360 · compact app bars below 320 effective width (width ÷ text scale) |
| Type (TextTheme) | display 40/36/32 · headline 30/26/24 · title 20/17/15 (w600) · body 17/15/13 · label 15/13/12. Line heights 1.25–1.4 for display/title, 1.5–1.55 for body (Ge'ez needs taller lines) |
| Reading sizes | 15 · 17 · 19 (default) · 21 · 24 · 28; line heights 1.5 · 1.7 · 2.0 |
| Motion | fast 150 ms · medium 250 ms · slow 400 ms · curve `easeOutCubic` · one page transition (`FadeForwardsPageTransitionsBuilder`) |

**Shared widgets** (`app/lib/ui/widgets/`)

- Structure: `AppScaffold` (`reading: true` puts the reader on the theme's paper color; `pageTitle` names the browser
  tab on the web, default `title`), `AppListView` (centers content at 840 on wide windows), `ContentWidth` (the same
  for bodies that aren't an `AppListView`), `Gutter` (screen padding), `SectionHeader`, `LabeledGroup`,
  `BottomActionBar`.
- Actions: `AppButton` (`.secondary/.outline/.ghost/.destructive`; `size`, `icon`, `iconAtEnd`, `loading`, `expand`, `tight`), `LabeledIconButton`, `SwatchButton`. Icon-only actions use `IconButton` (themed to 48dp) with a `tooltip`.
- Forms & filters: `AppTextField`, `AppSearchField` (optional `focusNode`), `FilterBar` / `FilterOption`
  (`padding: EdgeInsets.zero` inside a sheet, which has its own).
- Data: `AppCard` (eyebrow → content → actions), `HeroCard` (the one featured card of a screen, e.g. the verse of the
  day) with `OrnamentRule` (placeholder for the illustrated haräg ornament), `StatTile` (a count and label),
  `MonogramAvatar` (a person's initial; `small` for stacks and chat lines),
  `ToolTile` (a tool to open: icon, title and a line of description; a row of them shares its height),
  `AppListTile`, `StatusBadge` (`BadgeTone`), `ProgressRing`.
- States: `AsyncView` (loading/error/data for any `AsyncValue`), `EmptyState`, `LoadingState`, `ErrorState` (friendly text + retry; never show exception text to readers), `InlineSpinner`.
- Overlays: `showAppDialog`, `showConfirmDialog`, `showAppBottomSheet`, `showOptionPicker` / `PickerOption`,
  `showAppSnack` (optional `actionLabel` / `onAction`, e.g. Undo).
  (These functions are this project's `AppDialog` / `AppBottomSheet`.)

**Rules specific to this app**

- Dialogs only confirm destructive or blocking actions (delete account, stop/restart a plan, download progress). Choices, pickers and details (versions, language, speed, sleep timer, footnotes, text settings) use bottom sheets via `showOptionPicker` / `showAppBottomSheet`.
- Reader gestures: on phones, press and hold selects a verse, and a tap adds to a selection, jumps the audio to the
  verse, or shows and hides the bars (`immersiveProvider`; the shell hides its navigation bar with it). On the web and
  with a screen reader, a tap selects. `ParagraphView.onLongPressVerse` carries the hold; keep both paths working.
- Reading-plan links open the reader with `plan` and `day` query parameters, which show the plan bar; the reader keeps
  them when it moves between chapters. The day marks itself read once the end of each of its chapters has been on
  screen for `AppMotion.readEndDwell`, with Undo in the snack bar. A verse opened from a link or search
  (`ref=JHN.3.16`) is tinted for `AppMotion.verseFlash` (`VerseDecor.flash`).
- Share text through `shareText` (`features/common.dart`): on browsers without a share sheet it copies the text and
  says so, instead of opening an email. Web addresses are clean paths (`usePathUrlStrategy`), so links built in code
  never contain `#`.
- Removing something the reader made: offer Undo (`showAppSnack` with an action) when it can be restored, otherwise
  confirm with `showConfirmDialog(destructive: true)`. Back never silently discards typing (`PopScope`).
- Colors are defined only in `app_theme.dart` (a `ColorScheme` per reading theme) and `AppColors`.
  `test/contrast_test.dart` checks scripture, red letters and verse numbers against every highlight, the playing and
  selection tints in all four themes; keep it passing when changing colors.
- A text field at the bottom of a screen (the Ask composer) goes at the end of the body's `Column`, not in
  `AppScaffold.bottomBar`: the keyboard covers the bottom bar, while the body resizes above it.
- A row of choices that may not fit (color swatches, backgrounds) wraps (`Wrap`) rather than scrolling sideways:
  on the web a mouse can't drag a row, and on phones options past the edge go unnoticed. Chip rows that are clearly
  scrollable (`FilterBar`) are the exception.
- Never put dropdowns or segmented buttons in a `ListTile` trailing slot — use an `AppListTile` with the current value as subtitle that opens `showOptionPicker` (this crashed on narrow screens).
- Scripture text always uses `context.reading` styles (or `context.scriptureSnippet` / `scriptureFeature` outside the reader), never `TextStyle(fontSize: ...)`.
- One loading pattern: centered spinner (`LoadingState`); `InlineSpinner` inside buttons and rows.
- Long Amharic labels: every `Text` in a `Row` is wrapped in `Flexible`/`Expanded` with `maxLines` + `overflow`, or the row is a `Wrap`.
- `AsyncView` runs its `data` builder during its own build; when the builder calls `ref.listen` (the reader), match the `AsyncValue` with a `switch` inline instead.
- Naming: shared widgets are `App*` (or a plain descriptive noun for single-purpose pieces such as `SwatchButton`, `StatusBadge`); feature-private widgets start with `_`.

**Documented exceptions**

- The share-image cards (`VerseCard`, `PlanCompleteCard`) are fixed 1080 px pictures that must look the same in every theme, so they use `ShareCardTokens` and their own palette rather than the app theme. Share them with `sharePng`.
- `AppShell` (in `app.dart`) uses a plain `Scaffold`: it is the navigation shell (five tabs: Today · Read · Plans ·
  Search & Study · Me) that hosts the bottom bar, rail or sidebar, not a screen. Old `/me/plans…` and `/me/groups`
  addresses redirect to `/plans…`. Screens opened over the tabs (study, word, entity, timeline, Ask, group, player)
  are `inShell` routes: on wide windows they keep the same rail beside them (`_NavigationFrame`) and fade in place
  instead of using the page transition, so the rail doesn't move. Focused tasks (note editor, share image, book picker,
  welcome) and anything with a `PopScope` stay ordinary routes that cover the window, since choosing a tab would close
  them without asking.
- Fractions of the reading font size inside `ReadingStyles` (verse numbers 0.6×, footnote markers 0.7×, secondary version 0.92×) and scroll-alignment fractions in the reader are proportional by design.

**Layout gate**

`app/test/layout_audit_test.dart` renders every route at 320 dp with 1.3× text in all four reading themes and both languages, plus phone and tablet sizes and key interactive states (verse selected, text settings sheet, option picker), and fails on any overflow or layout error. It also renders the reader at 2× text (DESIGN.md §4.5). Add new routes to
its `routes` list. `app/test/strings_test.dart` fails when a string is missing in either language.
