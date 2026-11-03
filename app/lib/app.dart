import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import 'features/plans/plans_screen.dart';
import 'features/reader/book_picker_screen.dart';
import 'features/reader/reader_screen.dart';
import 'features/search/search_screen.dart';
import 'features/share/share_image_screen.dart';
import 'features/study/ask_screen.dart';
import 'features/study/entity_screen.dart';
import 'features/study/timeline_screen.dart';
import 'features/study/verse_study_screen.dart';
import 'features/study/word_study_screen.dart';
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

GoRouter buildRouter({String initialLocation = '/home'}) => GoRouter(
  navigatorKey: _rootKey,
  initialLocation: initialLocation,
  redirect: (_, state) => _movedRoute(state),
  // A mistyped or outdated link gets a friendly page, not the router's own.
  errorBuilder: (_, _) => const NotFoundScreen(),
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      // Tab order: Today · Read · Plans · Search & Study · Me (AppShell.tabs).
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/read',
              builder: (_, state) => ReaderScreen(target: BibleRef.decode(state.uri.queryParameters['ref'])),
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
          routes: [GoRoute(path: '/search', builder: (_, _) => const SearchScreen())],
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
    GoRoute(path: '/welcome', parentNavigatorKey: _rootKey, builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: '/books', parentNavigatorKey: _rootKey, builder: (_, _) => const BookPickerScreen()),
    GoRoute(path: '/player', parentNavigatorKey: _rootKey, builder: (_, _) => const PlayerScreen()),
    GoRoute(
      path: '/share-image',
      parentNavigatorKey: _rootKey,
      builder: (_, state) => ShareImageScreen(
        vkeys: (state.uri.queryParameters['keys'] ?? '').split(',').map(int.tryParse).whereType<int>().toList(),
      ),
    ),
    GoRoute(
      path: '/study',
      parentNavigatorKey: _rootKey,
      builder: (_, state) => VerseStudyScreen(vkey: int.tryParse(state.uri.queryParameters['v'] ?? '') ?? 0),
    ),
    GoRoute(
      path: '/ask',
      parentNavigatorKey: _rootKey,
      builder: (_, state) {
        final q = state.uri.queryParameters;
        return AskScreen(vkeys: askVerses(int.tryParse(q['v'] ?? '') ?? 0, int.tryParse(q['end'] ?? '')));
      },
    ),
    GoRoute(
      path: '/groups/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, state) => GroupScreen(groupId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/timeline', parentNavigatorKey: _rootKey, builder: (_, _) => const TimelineScreen()),
    GoRoute(
      path: '/word/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, state) => WordStudyScreen(strongs: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/entity/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, state) => EntityScreen(id: state.pathParameters['id']!),
    ),
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

/// A fresh install opens on the welcome steps; links (a shared verse on the
/// web, a deep link on a phone) still open where they point.
final routerProvider = Provider<GoRouter>(
  (ref) => buildRouter(initialLocation: ref.read(settingsProvider).onboarded ? '/home' : '/welcome'),
);

class AmharicBibleApp extends ConsumerWidget {
  const AmharicBibleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the sync controller alive so it reacts to sign-in and edits.
    ref.listen(syncControllerProvider, (_, _) {});
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
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// The app's navigation: Today · Read · Plans · Search & Study · Me.
///
/// A bottom bar on phones (with the mini player above it), a rail from
/// [AppDimens.navigationRailMinWidth] (tablets, phones in landscape) and a
/// sidebar with the app's name from [AppDimens.navigationSidebarMinWidth]
/// (desktop browsers); beside a rail the mini player sits under the content.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Same order as the router's branches.
    final tabs = [
      (icon: Icons.wb_sunny_outlined, selected: Icons.wb_sunny, label: s.today),
      (icon: Icons.menu_book_outlined, selected: Icons.menu_book, label: s.read),
      (icon: Icons.event_note_outlined, selected: Icons.event_note, label: s.plans),
      (icon: Icons.search, selected: Icons.manage_search, label: s.search),
      (icon: Icons.person_outline, selected: Icons.person, label: s.me),
    ];
    final width = MediaQuery.sizeOf(context).width;

    if (width >= AppDimens.navigationRailMinWidth) {
      final sidebar = width >= AppDimens.navigationSidebarMinWidth;
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              right: false,
              child: NavigationRail(
                extended: sidebar,
                labelType: sidebar ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                leading: sidebar ? const _Wordmark() : null,
                selectedIndex: shell.currentIndex,
                onDestinationSelected: _go,
                destinations: [
                  for (final t in tabs)
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
                  Expanded(child: shell),
                  const MiniPlayer(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _go,
            destinations: [
              for (final t in tabs)
                NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selected), label: t.label),
            ],
          ),
        ],
      ),
    );
  }
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
