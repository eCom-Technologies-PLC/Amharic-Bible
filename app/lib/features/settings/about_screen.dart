import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../state/providers.dart';
import '../common.dart';

/// App info and the attribution for every bundled text (from
/// content/versions.json via the content DB).
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.about)),
      body: AsyncBody(
        value: ref.watch(versionsProvider),
        data: (versions) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(s.appName, style: t.headlineSmall),
            const SizedBox(height: 8),
            Text(s.privacyNote),
            const SampleBanner(),
            const SizedBox(height: 24),
            Text(s.sources, style: t.titleMedium),
            for (final v in versions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${v.localName} (${v.abbrev})'),
                subtitle: Text([v.attribution, if (v.licenseStatus != 'confirmed') s.licenseUnverified].join('\n')),
              ),
            const SizedBox(height: 16),
            Text(s.font, style: t.titleMedium),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Noto Serif Ethiopic, Noto Sans Ethiopic'),
              subtitle: Text('SIL Open Font License 1.1'),
            ),
            TextButton(
              onPressed: () => showLicensePage(context: context, applicationName: s.appName),
              child: const Text('Open-source licenses'),
            ),
          ],
        ),
      ),
    );
  }
}
