import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/localizations.dart';
import 'core/strings.dart';
import 'core/web/web_storage.dart';
import 'features/common.dart';
import 'ui/ui.dart';
import 'domain/models.dart';
import 'features/audio/player_widgets.dart';
import 'features/groups/group_screen.dart';
import 'features/groups/groups_screen.dart';
import 'features/home/home_screen.dart';
import 'features/library/library_screen.dart';
import 'features/library/note_editor_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/plans/plan_detail_screen.dart';
import 'features/plans/plan_reminders.dart';
import 'features/plans/plans_screen.dart';
import 'features/reader/book_picker_screen.dart';
import 'features/reader/reader_screen.dart';
import 'features/search/search_screen.dart';
import 'features/share/share_image_screen.dart';
import 'features/study/ask_screen.dart';
import 'features/study/entity_screen.dart';
import 'features/study/people_screen.dart';
import 'features/study/timeline_screen.dart';
import 'features/study/verse_study_screen.dart';
import 'features/study/word_study_screen.dart';
import 'features/study/words_screen.dart';
import 'features/settings/about_screen.dart';
import 'features/settings/account_screen.dart';
import 'features/settings/downloads_screen.dart';
import 'features/settings/me_screen.dart';
import 'features/settings/settings_screen.dart';
import 'state/account.dart';
import 'state/providers.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Addresses that moved when Plans and Groups got their own tab; old links
/// and bookmarks keep working.
String? _movedRoute(GoRouterState state) {
  final path = state.uri.path;
  final String? moved = switch (path) {
    '/me/groups' => '/plans/groups',
    _ when path == '/me/plans' || path.startsWith('/me/plans/') => path.replaceFirst('/me/plans', '/plans'),
    _ => null,
  };
  return moved == null ? null : Uri(path: moved, query: state.uri.hasQuery ? state.uri.query : null).toString();
}

GoRouter buildRouter({String initialLocation = '/home'}) {
  // The tabs' shell, so screens opened over it can show which tab they came
  // from and switch tabs ([_InShell]).
  final shellKey = GlobalKey<StatefulNavigationShellState>();

  // A screen opened over the tabs that keeps the navigation beside it on wide
  // windows.
  GoRoute inShell(String path, Widget Function(GoRouterState state) screen, {bool miniPlayer = true}) => GoRoute(
    path: path,
    parentNavigatorKey: _rootKey,
    pageBuilder: (_, state) => _InShellPage(
      key: state.pageKey,
      child: _InShell(shellKey: shellKey, miniPlayer: miniPlayer, child: screen(state)),
    ),
  );

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: initialLocation,
    redirect: (_, state) => _movedRoute(state),
    // A mistyped or outdated link gets a friendly page, not the router's own.
    errorBuilder: (_, _) => const NotFoundScreen(),
    routes: [
      StatefulShellRoute.indexedStack(
        key: shellKey,
        builder: (context, state, shell) => AppShell(shell: shell),
        // Tab order: Today · Read · Plans · Search & Study · Me (_tabs, AppShell.tabRoots).
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/read',
                builder: (_, state) {
                  final q = state.uri.queryParameters;
                  return ReaderScreen(
                    target: BibleRef.decode(q['ref']),
                    planId: q['plan'],
                    planDay: int.tryParse(q['day'] ?? ''),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plans',
                builder: (_, _) => const PlansScreen(),
                routes: [
                  GoRoute(path: 'groups', builder: (_, _) => const GroupsScreen()),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => PlanDetailScreen(planId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (_, state) => SearchScreen(query: state.uri.queryParameters['q']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/me',
                builder: (_, _) => const MeScreen(),
                routes: [
                  GoRoute(
                    path: 'library',
                    builder: (_, state) =>
                        LibraryScreen(initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0),
                  ),
                  GoRoute(path: 'settings', builder: (_, _) => const SettingsScreen()),
                  GoRoute(path: 'account', builder: (_, _) => const AccountScreen()),
                  GoRoute(path: 'about', builder: (_, _) => const AboutScreen()),
                  GoRoute(path: 'downloads', builder: (_, _) => const DownloadsScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
      // The static chapter pages (pipeline/build_site.py) live at
      // /bible/<version>/<book>/<chapter>/. When the app is asked for one
      // (offline, or on a host without the pages), it opens the reader there.
      GoRoute(path: '/bible', redirect: (_, _) => '/read'),
      GoRoute(path: '/bible/:version', redirect: (_, _) => '/read'),
      GoRoute(
        path: '/bible/:version/:book',
        redirect: (_, state) => '/read?ref=${state.pathParameters['book']!.toUpperCase()}.1',
      ),
      GoRoute(
        path: '/bible/:version/:book/:chapter',
        redirect: (_, state) {
          final p = state.pathParameters;
          final chapter = int.tryParse(p['chapter']!) ?? 1;
          return '/read?ref=${p['book']!.toUpperCase()}.$chapter';
        },
      ),
      // Focused tasks (welcome, choosing a book, an image, a note) cover the
      // whole window; the rest keep the navigation beside them on wide windows.
      GoRoute(path: '/welcome', parentNavigatorKey: _rootKey, builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/books', parentNavigatorKey: _rootKey, builder: (_, _) => const BookPickerScreen()),
      inShell('/player', (_) => const PlayerScreen(), miniPlayer: false),
      GoRoute(
        path: '/share-image',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => ShareImageScreen(
          vkeys: (state.uri.queryParameters['keys'] ?? '').split(',').map(int.tryParse).whereType<int>().toList(),
        ),
      ),
      inShell('/study', (state) => VerseStudyScreen(vkey: int.tryParse(state.uri.queryParameters['v'] ?? '') ?? 0)),
      inShell('/ask', (state) {
        final q = state.uri.queryParameters;
        return AskScreen(vkeys: askVerses(int.tryParse(q['v'] ?? '') ?? 0, int.tryParse(q['end'] ?? '')));
      }),
      inShell('/groups/:id', (state) => GroupScreen(groupId: state.pathParameters['id']!)),
      inShell('/timeline', (_) => const TimelineScreen()),
      inShell('/people', (_) => const PeopleScreen()),
      inShell('/words', (_) => const WordsScreen()),
      inShell('/word/:id', (state) => WordStudyScreen(strongs: state.pathParameters['id']!)),
      inShell('/entity/:id', (state) => EntityScreen(id: state.pathParameters['id']!)),
      GoRoute(
        path: '/note',
        parentNavigatorKey: _rootKey,
        // A note needs the verse it belongs to; without one, open the notes list.
        redirect: (_, state) =>
            int.tryParse(state.uri.queryParameters['start'] ?? '') == null ? '/me/library?tab=2' : null,
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return NoteEditorScreen(
            vkeyStart: int.parse(q['start']!),
            vkeyEnd: int.parse(q['end'] ?? q['start']!),
            noteId: q['id'],
          );
        },
      ),
    ],
  );
}

/// A fresh install opens on the welcome steps; links (a shared verse on the
/// web, a deep link on a phone) and a tapped reminder still open where they
/// point.
final routerProvider = Provider<GoRouter>(
  (ref) => buildRouter(
    initialLocation: ref.read(launchRouteProvider) ?? (ref.read(settingsProvider).onboarded ? '/home' : '/welcome'),
  ),
);

/// Keeps the daily reminder scheduled as the settings and plans change, and
/// opens a reminder's reading when it is tapped while the app runs.
final _remindersProvider = Provider<void>((ref) {
  final scheduler = ref.watch(reminderSchedulerProvider);
  ref.listen(reminderScheduleProvider, (_, next) {
    if (next case AsyncData(:final value)) scheduler.schedule(value);
  }, fireImmediately: true);
  final taps = scheduler.opened.listen((route) {
    final router = ref.read(routerProvider);
    // Going elsewhere would close a note without asking and lose its typing:
    // the app comes back to the note instead.
    if (router.state.fullPath == '/note') return;
    router.go(route);
  });
  ref.onDispose(taps.cancel);
});

class AmharicBibleApp extends ConsumerWidget {
  const AmharicBibleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the sync controller alive so it reacts to sign-in and edits.
    ref.listen(syncControllerProvider, (_, _) {});
    ref.listen(_remindersProvider, (_, _) {});
    // Browsers may clear site data under storage pressure; once the reader has
    // saved something, ask to keep it.
    if (kIsWeb) ref.listen(userDataWrittenProvider, (_, _) => requestPersistentStorage());
    final settings = ref.watch(settingsProvider);
    final brightness = MediaQuery.platformBrightnessOf(context);
    return MaterialApp.router(
      onGenerateTitle: (context) => S.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(
        mode: settings.readerTheme,
        platformBrightness: brightness,
        readingFontSize: settings.fontSize,
        readingLineHeight: settings.lineHeight,
        serif: settings.serif,
      ),
      locale: settings.locale,
      supportedLocales: S.supported,
      localizationsDelegates: appLocalizationsDelegates,
      routerConfig: ref.watch(routerProvider),
      // Sheets open beside the press that opened them on wide windows.
      builder: (context, child) => LastPress(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// The tabs, in the router's branch order.
List<({IconData icon, IconData selected, String label})> _tabs(S s) => [
  (icon: Icons.wb_sunny_outlined, selected: Icons.wb_sunny, label: s.today),
  (icon: Icons.menu_book_outlined, selected: Icons.menu_book, label: s.read),
  (icon: Icons.event_note_outlined, selected: Icons.event_note, label: s.plans),
  (icon: Icons.search, selected: Icons.manage_search, label: s.search),
  (icon: Icons.person_outline, selected: Icons.person, label: s.me),
];

/// The app's navigation: Today · Read · Plans · Search & Study · Me.
///
/// A bottom bar on phones (with the mini player above it), a rail from
/// [AppDimens.navigationRailMinWidth] (tablets, phones in landscape) and a
/// sidebar with the app's name from [AppDimens.navigationSidebarMinWidth]
/// (desktop browsers); beside a rail the mini player sits under the content.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// Index of the Read tab, whose immersive mode hides the navigation bar.
  static const readTab = 1;

  /// Each tab's first address, in the same order.
  static const tabRoots = ['/home', '/read', '/plans', '/search', '/me'];

  void _go(WidgetRef ref, int i) {
    ref.read(immersiveProvider.notifier).set(false);
    shell.goBranch(i, initialLocation: i == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideBar = ref.watch(immersiveProvider) && shell.currentIndex == readTab;
    return _GoToShortcut(
      child: MediaQuery.sizeOf(context).width >= AppDimens.navigationRailMinWidth
          ? _NavigationFrame(selectedIndex: shell.currentIndex, onSelected: (i) => _go(ref, i), child: shell)
          : Scaffold(
              body: shell,
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MiniPlayer(),
                  _CollapsibleBar(
                    hidden: hideBar,
                    child: NavigationBar(
                      selectedIndex: shell.currentIndex,
                      onDestinationSelected: (i) => _go(ref, i),
                      destinations: [
                        for (final t in _tabs(S.of(context)))
                          NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selected), label: t.label),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// The rail, or the sidebar from [AppDimens.navigationSidebarMinWidth], beside
/// [child], with the mini player under it. Shared by the tabs and the screens
/// opened over them, so moving between the two changes only the content.
class _NavigationFrame extends StatelessWidget {
  const _NavigationFrame({
    required this.selectedIndex,
    required this.onSelected,
    required this.child,
    this.miniPlayer = true,
  });

  /// The highlighted tab; null for a screen opened straight from a link.
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget child;
  final bool miniPlayer;

  @override
  Widget build(BuildContext context) {
    final sidebar = MediaQuery.sizeOf(context).width >= AppDimens.navigationSidebarMinWidth;
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: NavigationRail(
              extended: sidebar,
              labelType: sidebar ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              leading: sidebar ? const _Wordmark() : null,
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
              destinations: [
                for (final t in _tabs(S.of(context)))
                  NavigationRailDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selected),
                    label: Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
          const VerticalDivider(),
          Expanded(
            child: Column(
              children: [
                Expanded(child: child),
                if (miniPlayer) const MiniPlayer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A screen opened over the tabs: verse study, a word, a person or place, the
/// timeline, Ask, a group, the player. On wide windows the navigation stays
/// beside it, so the reader can move on without going back first; choosing a
/// tab closes these screens and returns to where the reader was in that tab.
/// On phones the screen covers the tabs as before.
class _InShell extends ConsumerStatefulWidget {
  const _InShell({required this.shellKey, required this.child, this.miniPlayer = true});

  /// The tabs' shell; mounted underneath unless the screen was opened straight
  /// from a link.
  final GlobalKey<StatefulNavigationShellState> shellKey;
  final Widget child;
  final bool miniPlayer;

  @override
  ConsumerState<_InShell> createState() => _InShellState();
}

class _InShellState extends ConsumerState<_InShell> {
  /// Keeps the screen's state (a conversation, a scroll position) when the
  /// window crosses the rail's width, such as a phone turning sideways.
  final _content = GlobalKey();

  void _go(int i) {
    ref.read(immersiveProvider.notifier).set(false);
    final shell = widget.shellKey.currentState;
    if (shell != null && shell.mounted) {
      shell.goBranch(i);
    } else {
      context.go(AppShell.tabRoots[i]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = KeyedSubtree(key: _content, child: widget.child);
    final wide = MediaQuery.sizeOf(context).width >= AppDimens.navigationRailMinWidth;
    return _GoToShortcut(
      child: wide
          ? _NavigationFrame(
              selectedIndex: widget.shellKey.currentState?.currentIndex,
              onSelected: _go,
              miniPlayer: widget.miniPlayer,
              child: content,
            )
          : content,
    );
  }
}

/// The page for [_InShell] screens. Beside the navigation (wide windows) the
/// screen fades in over the one underneath, which stays still, so only the
/// content changes; on phones it uses the app's page transition.
class _InShellPage extends Page<void> {
  const _InShellPage({required this.child, super.key});

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => _InShellRoute(this);
}

class _InShellRoute extends PageRoute<void> with MaterialRouteTransitionMixin<void> {
  _InShellRoute(_InShellPage page) : super(settings: page);

  bool get _wide => MediaQuery.sizeOf(navigator!.context).width >= AppDimens.navigationRailMinWidth;

  @override
  Widget buildContent(BuildContext context) => (settings as _InShellPage).child;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => _wide ? AppMotion.medium : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _wide ? AppMotion.medium : super.reverseTransitionDuration;

  // The screen underneath animates out only when both routes agree to it.
  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => !_wide;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.sizeOf(context).width < AppDimens.navigationRailMinWidth) {
      return super.buildTransitions(context, animation, secondaryAnimation, child);
    }
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: AppMotion.curve)),
      child: child,
    );
  }
}

/// Ctrl+K (⌘K on a Mac) opens the Go-to box from anywhere in the app. It
/// listens to the keyboard directly, so it works whatever has focus, and stays
/// quiet while a sheet or dialog is open over the app.
class _GoToShortcut extends ConsumerStatefulWidget {
  const _GoToShortcut({required this.child});

  final Widget child;

  @override
  ConsumerState<_GoToShortcut> createState() => _GoToShortcutState();
}

class _GoToShortcutState extends ConsumerState<_GoToShortcut> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.keyK) return false;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) return false;
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return false;
    showGoTo(context, ref);
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The bottom navigation bar, sliding down out of view during immersive
/// reading and back when the reader scrolls up or taps.
class _CollapsibleBar extends StatelessWidget {
  const _CollapsibleBar({required this.hidden, required this.child});

  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: hidden ? 0 : 1),
    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.medium,
    curve: AppMotion.curve,
    builder: (context, shown, bar) => ClipRect(
      child: Align(alignment: Alignment.topCenter, heightFactor: shown, child: bar),
    ),
    child: child,
  );
}

/// The app's name at the top of the sidebar (until the illustrator's logo exists).
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
    child: Text(
      S.of(context).appName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.text.titleLarge?.copyWith(color: context.colors.primary, fontFamily: AppFonts.serif),
    ),
  );
}
