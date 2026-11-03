import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../state/account.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';

/// The Me tab: who is reading (and whether their notes are backed up), the
/// library at a glance, then study tools and app settings.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    Widget tile(IconData icon, String label, String route) =>
        AppListTile(leadingIcon: icon, title: label, chevron: true, onTap: () => context.push(route));
    String count(AsyncValue<List<Object?>> v) => v.value != null ? '${v.value!.length}' : '–';
    Widget stat(AsyncValue<List<Object?>> v, IconData icon, String label, int tab) => Expanded(
      child: StatTile(value: count(v), label: label, icon: icon, onTap: () => context.push('/me/library?tab=$tab')),
    );

    return AppScaffold(
      title: s.me,
      body: AppListView(
        children: [
          const _AccountHeader(),
          Gutter(
            vertical: AppSpacing.sm,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stat(ref.watch(highlightsListProvider), Icons.format_paint_outlined, s.highlights, 0),
                const SizedBox(width: AppSpacing.sm),
                stat(ref.watch(bookmarksListProvider), Icons.bookmark_border, s.bookmarks, 1),
                const SizedBox(width: AppSpacing.sm),
                stat(ref.watch(notesListProvider), Icons.sticky_note_2_outlined, s.notes, 2),
              ],
            ),
          ),
          SectionHeader(s.appSection),
          // The web streams everything: no offline downloads.
          if (!kIsWeb) tile(Icons.download_outlined, s.downloads, '/me/downloads'),
          tile(Icons.settings_outlined, s.settings, '/me/settings'),
          tile(Icons.info_outline, '${s.about} · ${s.sources}', '/me/about'),
          Gutter(
            vertical: AppSpacing.lg,
            child: Text(s.privacyNote, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

/// The reader's account at the top of Me: signed in (notes sync), or a guest
/// whose notes stay on this device, with a nudge to sign in when accounts
/// exist. Opens the account screen.
class _AccountHeader extends ConsumerWidget {
  const _AccountHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final configured = ref.watch(accountServiceProvider) != null;
    final email = ref.watch(accountEmailProvider).value;
    final scheme = context.colors;
    return AppListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: email != null && email.isNotEmpty
            ? Text(email.substring(0, 1).toUpperCase(), style: context.text.titleMedium)
            : const Icon(Icons.person_outline),
      ),
      title: email ?? s.guest,
      subtitle: email != null
          ? s.syncOn
          : configured
          ? s.signInToSync
          : s.notesOnDevice,
      chevron: true,
      onTap: () => context.push('/me/account'),
    );
  }
}
