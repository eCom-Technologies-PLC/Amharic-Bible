import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../reader/text_settings_sheet.dart';

/// First launch (docs/DESIGN.md §8.1): choose a language, make reading
/// comfortable, then pick where to begin. Every step can be skipped; there is
/// no account and nothing to allow. Shown once, on a fresh install.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  static const _steps = 3;
  int _step = 0;

  void _goToStep(int step) => setState(() => _step = step);

  /// Marks the welcome done and opens [location].
  Future<void> _finish(String location) async {
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(onboarded: true));
    if (mounted) context.go(location);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AppScaffold(
      leading: _step > 0
          ? IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const BackButtonIcon(),
              onPressed: () => _goToStep(_step - 1),
            )
          : null,
      titleWidget: _StepDots(step: _step, count: _steps),
      pageTitle: s.appName,
      actions: [AppButton.ghost(label: s.skip, size: AppButtonSize.sm, onPressed: () => _finish('/home'))],
      bottomBar: _step == 1
          ? BottomActionBar(
              children: [AppButton(label: s.next, expand: true, onPressed: () => _goToStep(2))],
            )
          : null,
      body: AnimatedSwitcher(
        duration: AppMotion.medium,
        switchInCurve: AppMotion.curve,
        child: KeyedSubtree(
          key: ValueKey(_step),
          child: switch (_step) {
            0 => _LanguageStep(onChosen: () => _goToStep(1)),
            1 => const _ComfortStep(),
            _ => _BeginStep(onBegin: _finish),
          },
        ),
      ),
    );
  }
}

/// Where the reader is in the three steps.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Semantics(
      label: S.of(context).stepOf(step + 1, count),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: AppMotion.fast,
                margin: const EdgeInsets.only(right: AppSpacing.xs),
                width: i == step ? AppSpacing.xl : AppSpacing.sm,
                height: AppSpacing.sm,
                decoration: BoxDecoration(
                  color: i == step ? scheme.primary : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Step 1: the app's name and a choice of language, asked in both languages.
class _LanguageStep extends ConsumerWidget {
  const _LanguageStep({required this.onChosen});

  final VoidCallback onChosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> choose(String code) async {
      await ref.read(settingsProvider.notifier).update((s) => s.copyWith(languageCode: code));
      onChosen();
    }

    return AppListView(
      children: [
        const SizedBox(height: AppSpacing.xxxl),
        Text(
          S.am.appName,
          textAlign: TextAlign.center,
          style: context.text.displaySmall?.copyWith(color: context.colors.primary, fontFamily: AppFonts.serif),
        ),
        const SizedBox(height: AppSpacing.md),
        const Center(child: OrnamentRule()),
        const SizedBox(height: AppSpacing.md),
        Text(S.en.appName, textAlign: TextAlign.center, style: context.text.titleMedium),
        const SizedBox(height: AppSpacing.xxxl),
        Gutter(
          child: Text(
            '${S.am.chooseLanguage} · ${S.en.chooseLanguage}',
            textAlign: TextAlign.center,
            style: context.text.titleSmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Gutter(
          child: AppButton.secondary(
            label: 'አማርኛ',
            size: AppButtonSize.lg,
            expand: true,
            onPressed: () => choose('am'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Gutter(
          child: AppButton.secondary(
            label: 'English',
            size: AppButtonSize.lg,
            expand: true,
            onPressed: () => choose('en'),
          ),
        ),
      ],
    );
  }
}

/// Step 2: text size, spacing, font and theme, applied live to this screen.
class _ComfortStep extends StatelessWidget {
  const _ComfortStep();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AppListView(
      children: [
        Gutter(
          vertical: AppSpacing.sm,
          child: Text(s.readingComfort, style: context.text.headlineSmall),
        ),
        Gutter(
          child: Text(
            s.readingComfortHint,
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
        const Gutter(vertical: AppSpacing.sm, child: TextSettingsSheet(showInterlinear: false)),
      ],
    );
  }
}

/// Step 3: three ways to start, each finishing the welcome.
class _BeginStep extends StatelessWidget {
  const _BeginStep({required this.onBegin});

  final ValueChanged<String> onBegin;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    Widget option(IconData icon, String title, String hint, String location) => AppCard(
      onTap: () => onBegin(location),
      child: Row(
        children: [
          Icon(icon, color: context.colors.primary),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleMedium),
                Text(hint, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward),
        ],
      ),
    );
    return AppListView(
      children: [
        Gutter(
          vertical: AppSpacing.sm,
          child: Text(s.whereToBegin, style: context.text.headlineSmall),
        ),
        option(Icons.menu_book_outlined, s.beginJohn, s.beginJohnHint, '/read?ref=JHN.1'),
        option(Icons.event_note_outlined, s.beginPlan, s.beginPlanHint, '/plans'),
        option(Icons.wb_sunny_outlined, s.beginToday, s.beginTodayHint, '/home'),
      ],
    );
  }
}
