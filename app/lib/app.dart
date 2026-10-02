import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/strings.dart';
import 'ui/ui.dart';
import 'domain/models.dart';
import 'features/audio/player_widgets.dart';
import 'features/home/home_screen.dart';
import 'features/library/library_screen.dart';
import 'features/library/note_editor_screen.dart';
import 'features/plans/plan_detail_screen.dart';
import 'features/plans/plans_screen.dart';
import 'features/reader/book_picker_screen.dart';
import 'features/reader/reader_screen.dart';
import 'features/search/search_screen.dart';
import 'features/share/share_image_screen.dart';
import 'features/streak/streak_widgets.dart';
import 'features/settings/about_screen.dart';
import 'features/settings/account_screen.dart';
import 'features/settings/downloads_screen.dart';
import 'features/settings/me_screen.dart';
import 'features/settings/settings_screen.dart';
import 'state/account.dart';
import 'state/providers.dart';

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter({String initialLocation = '/home'}) => GoRouter(
  navigatorKey: _rootKey,
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
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
                GoRoute(
                  path: 'plans',
                  builder: (_, _) => const PlansScreen(),
                  routes: [
                    GoRoute(
                      path: ':id',
                      builder: (_, state) => PlanDetailScreen(planId: state.pathParameters['id']!),
                    ),
                  ],
                ),
                GoRoute(path: 'activity', builder: (_, _) => const ActivityScreen()),
                GoRoute(path: 'about', builder: (_, _) => const AboutScreen()),
                GoRoute(path: 'downloads', builder: (_, _) => const DownloadsScreen()),
              ],
            ),
          ],
        ),
      ],
    ),
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
      path: '/note',
      parentNavigatorKey: _rootKey,
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

final routerProvider = Provider<GoRouter>((ref) => buildRouter());

class AmharicBibleApp extends ConsumerWidget {
  const AmharicBibleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the sync controller alive so it reacts to sign-in and edits.
    ref.listen(syncControllerProvider, (_, _) {});
    final settings = ref.watch(settingsProvider);
    final brightness = MediaQuery.platformBrightnessOf(context);
    return MaterialApp.router(
      title: 'መጽሐፍ ቅዱስ',
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

/// Bottom navigation (Home, Read, Search, Me) with the mini player above it.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: s.home,
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book),
                label: s.read,
              ),
              NavigationDestination(icon: const Icon(Icons.search), label: s.search),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: s.me,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
