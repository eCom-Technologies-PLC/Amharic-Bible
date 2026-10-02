import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'domain/models.dart';
import 'features/audio/player_widgets.dart';
import 'features/home/home_screen.dart';
import 'features/library/library_screen.dart';
import 'features/library/note_editor_screen.dart';
import 'features/reader/book_picker_screen.dart';
import 'features/reader/reader_screen.dart';
import 'features/search/search_screen.dart';
import 'features/settings/about_screen.dart';
import 'features/settings/downloads_screen.dart';
import 'features/settings/me_screen.dart';
import 'features/settings/settings_screen.dart';
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
    final settings = ref.watch(settingsProvider);
    final brightness = MediaQuery.platformBrightnessOf(context);
    return MaterialApp.router(
      title: 'መጽሐፍ ቅዱስ',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(settings.readerTheme, brightness),
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
