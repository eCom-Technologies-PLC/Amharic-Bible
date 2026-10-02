# CLAUDE.md

Amharic Bible: an offline-first Flutter app (`app/`), a Python content pipeline (`pipeline/`), an audio proxy
(`server/audio-proxy/`) and a Supabase sync schema (`server/supabase/`). See `README.md` and `docs/DESIGN.md`.

## Commands

- App: `cd app && flutter analyze && flutter test` (format: `dart format lib test`, page width 120)
- Pipeline: `python -m unittest discover -s pipeline/tests`
- Audio proxy: `node --test server/audio-proxy/proxy.test.mjs`
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
| `app/lib/ui/theme/app_colors.dart` | ThemeExtensions `AppColors` (success/warning/info + containers, highlight colors, red letters) and `ReadingStyles` (scripture styles that follow the user's text-size/font/line-spacing settings); `context.colors`, `context.text`, `context.appColors`, `context.reading`, `context.scriptureSnippet`, `context.scriptureFeature` |
| `app/lib/ui/widgets/` | Shared widgets (inventory below) |
| `app/lib/core/strings.dart` | All UI text, Amharic + English. No literal user-facing strings in widgets |

**Token values**

| Token | Values |
|---|---|
| Spacing | xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · xxxl 48 · `screen` 16 (all screens, including the reader) · `section` 24 · `iconGap` 8 |
| Radius | sm 8 (chips, swatches) · md 12 (cards, inputs, buttons, menus) · lg 16 (dialogs) · xl 28 (bottom sheets) |
| Elevation | flat 0 · card 1 · bar 3 · dialog 6 |
| Icons | sm 18 · md 24 · lg 32 · xl 48 · hero 96 |
| Heights | buttons 36 / 48 / 56 · input 56 · list tile 56 / 72 · app bar 56 · touch target 48 |
| Layout | reading column max 680 (×2 side by side) · two columns from 600 · compact app bars below 320 effective width (width ÷ text scale) |
| Type (TextTheme) | display 40/36/32 · headline 30/26/24 · title 20/17/15 (w600) · body 17/15/13 · label 15/13/12. Line heights 1.25–1.4 for display/title, 1.5–1.55 for body (Ge'ez needs taller lines) |
| Reading sizes | 15 · 17 · 19 (default) · 21 · 24 · 28; line heights 1.5 · 1.7 · 2.0 |
| Motion | fast 150 ms · medium 250 ms · slow 400 ms · curve `easeOutCubic` · one page transition (`FadeForwardsPageTransitionsBuilder`) |

**Shared widgets** (`app/lib/ui/widgets/`)

- Structure: `AppScaffold`, `AppListView`, `Gutter` (screen padding), `SectionHeader`, `LabeledGroup`, `BottomActionBar`.
- Actions: `AppButton` (`.secondary/.outline/.ghost/.destructive`; `size`, `icon`, `iconAtEnd`, `loading`, `expand`, `tight`), `LabeledIconButton`, `SwatchButton`. Icon-only actions use `IconButton` (themed to 48dp) with a `tooltip`.
- Forms & filters: `AppTextField`, `AppSearchField`, `FilterBar` / `FilterOption`.
- Data: `AppCard` (eyebrow → content → actions), `AppListTile`, `StatusBadge` (`BadgeTone`), `ProgressRing`.
- States: `AsyncView` (loading/error/data for any `AsyncValue`), `EmptyState`, `LoadingState`, `ErrorState` (friendly text + retry; never show exception text to readers), `InlineSpinner`.
- Overlays: `showAppDialog`, `showConfirmDialog`, `showAppBottomSheet`, `showOptionPicker` / `PickerOption`, `showAppSnack`.
  (These functions are this project's `AppDialog` / `AppBottomSheet`.)

**Rules specific to this app**

- Dialogs only confirm destructive or blocking actions (delete account, stop/restart a plan, download progress). Choices, pickers and details (versions, language, speed, sleep timer, footnotes, text settings) use bottom sheets via `showOptionPicker` / `showAppBottomSheet`.
- Never put dropdowns or segmented buttons in a `ListTile` trailing slot — use an `AppListTile` with the current value as subtitle that opens `showOptionPicker` (this crashed on narrow screens).
- Scripture text always uses `context.reading` styles (or `context.scriptureSnippet` / `scriptureFeature` outside the reader), never `TextStyle(fontSize: ...)`.
- One loading pattern: centered spinner (`LoadingState`); `InlineSpinner` inside buttons and rows.
- Long Amharic labels: every `Text` in a `Row` is wrapped in `Flexible`/`Expanded` with `maxLines` + `overflow`, or the row is a `Wrap`.
- `AsyncView` runs its `data` builder during its own build; when the builder calls `ref.listen` (the reader), match the `AsyncValue` with a `switch` inline instead.
- Naming: shared widgets are `App*` (or a plain descriptive noun for single-purpose pieces such as `SwatchButton`, `StatusBadge`); feature-private widgets start with `_`.

**Documented exceptions**

- The share-image card (`VerseCard`) is a fixed 1080 px picture that must look the same in every theme, so it uses `ShareCardTokens` and its own palette rather than the app theme.
- `AppShell` (in `app.dart`) uses a plain `Scaffold`: it is the navigation shell that hosts the bottom bar, not a screen.
- Fractions of the reading font size inside `ReadingStyles` (verse numbers 0.6×, footnote markers 0.7×, secondary version 0.92×) and scroll-alignment fractions in the reader are proportional by design.

**Layout gate**

`app/test/layout_audit_test.dart` renders every route at 320 dp with 1.3× text in all four reading themes and both languages, plus phone and tablet sizes and key interactive states (verse selected, text settings sheet, option picker), and fails on any overflow or layout error. Add new routes to its `routes` list.
