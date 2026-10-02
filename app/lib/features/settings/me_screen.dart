import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../ui/ui.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    Widget tile(IconData icon, String label, String route) =>
        AppListTile(leadingIcon: icon, title: label, chevron: true, onTap: () => context.push(route));
    return AppScaffold(
      title: s.me,
      body: AppListView(
        children: [
          tile(Icons.format_paint_outlined, s.highlights, '/me/library?tab=0'),
          tile(Icons.bookmark_border, s.bookmarks, '/me/library?tab=1'),
          tile(Icons.sticky_note_2_outlined, s.notes, '/me/library?tab=2'),
          tile(Icons.event_note_outlined, s.readingPlans, '/me/plans'),
          const Divider(),
          tile(Icons.account_circle_outlined, s.account, '/me/account'),
          tile(Icons.download_outlined, s.downloads, '/me/downloads'),
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
