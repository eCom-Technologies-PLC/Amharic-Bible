import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../common.dart';

/// App info and the attribution for every bundled text (from
/// content/versions.json via the content DB).
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    return AppScaffold(
      title: s.about,
      body: AsyncView(
        value: ref.watch(versionsProvider),
        onRetry: () => ref.invalidate(versionsProvider),
        data: (versions) => AppListView(
          children: [
            const SampleBanner(),
            Gutter(
              vertical: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.appName, style: context.text.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(s.privacyNote, style: context.text.bodyMedium),
                ],
              ),
            ),
            SectionHeader(s.sources),
            for (final v in versions)
              AppListTile(
                title: '${v.localName} (${v.abbrev})',
                subtitleWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.attribution),
                    if (v.licenseStatus != 'confirmed') ...[
                      const SizedBox(height: AppSpacing.xs),
                      StatusBadge(s.licenseUnverified, tone: BadgeTone.warning, icon: Icons.gavel_outlined),
                    ],
                  ],
                ),
              ),
            SectionHeader(s.font),
            const AppListTile(title: 'Noto Serif Ethiopic, Noto Sans Ethiopic', subtitle: 'SIL Open Font License 1.1'),
            AppListTile(
              leadingIcon: Icons.description_outlined,
              title: s.openSourceLicenses,
              chevron: true,
              onTap: () => showLicensePage(context: context, applicationName: s.appName),
            ),
          ],
        ),
      ),
    );
  }
}
