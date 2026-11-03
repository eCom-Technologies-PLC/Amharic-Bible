import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../data/network.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../reader/reader_screen.dart' show audioErrorText;
import '../settings/downloads_screen.dart';
import 'audio_controller.dart';

String _fmt(Duration d) {
  final m = d.inMinutes;
  final sec = d.inSeconds % 60;
  return '$m:${sec.toString().padLeft(2, '0')}';
}

/// The player's artwork: the book and chapter on the parchment gradient of
/// the hero card, with an ornament rule (until illustrated covers exist).
class _Cover extends StatelessWidget {
  const _Cover({required this.book, required this.chapter});

  final String book;
  final String chapter;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppDimens.playerCoverMaxWidth),
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.hero),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.secondaryContainer, scheme.primaryContainer],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(book, style: context.text.headlineSmall?.copyWith(color: scheme.onSecondaryContainer)),
                  Text(
                    chapter,
                    style: context.text.displayLarge?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontFamily: AppFonts.serif,
                    ),
                  ),
                  const OrnamentRule(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final _verseProvider = FutureProvider.family<Verse?, (String, int)>(
  (ref, k) async => (await ref.watch(contentRepositoryProvider).verses(k.$1, [k.$2])).firstOrNull,
);

/// The verse being read aloud, following the recording.
class _NowReading extends ConsumerWidget {
  const _NowReading({required this.versionId, required this.vkey});

  final String versionId;
  final int vkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verse = ref.watch(_verseProvider((versionId, vkey))).value;
    if (verse == null) return const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: AppMotion.medium,
      child: Padding(
        key: ValueKey(vkey),
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Text(
          verse.text,
          textAlign: TextAlign.center,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: context.scriptureSnippet,
        ),
      ),
    );
  }
}

/// Persistent player shown above the tab bar while audio is loaded.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(audioControllerProvider);
    if (!a.active || a.book == null) return const SizedBox.shrink();
    final s = S.of(context);
    final c = ref.read(audioControllerProvider.notifier);
    final dur = a.duration ?? Duration.zero;
    final progress = dur.inMilliseconds > 0 ? a.position.inMilliseconds / dur.inMilliseconds : 0.0;

    return Material(
      color: context.colors.surfaceContainerHighest,
      child: InkWell(
        onTap: () => context.push('/player'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: progress.clamp(0, 1), minHeight: AppDimens.progressThin),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(
                children: [
                  IconButton(
                    tooltip: a.playing ? s.pause : s.play,
                    icon: a.status == AudioStatus.loading
                        ? const InlineSpinner()
                        : Icon(a.playing ? Icons.pause : Icons.play_arrow),
                    onPressed: a.status == AudioStatus.ready ? c.togglePlay : null,
                  ),
                  Expanded(
                    child: Text(
                      a.error != null ? audioErrorText(s, a.error!) : '${a.book!.shortName} ${a.chapter}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyLarge,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${_fmt(a.position)} · ${a.speed}×',
                    style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                  IconButton(tooltip: s.stopAudio, icon: const Icon(Icons.close), onPressed: c.stop),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  static const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
  static const sleepMinutes = [5, 15, 30, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final a = ref.watch(audioControllerProvider);
    final c = ref.read(audioControllerProvider.notifier);
    if (a.book == null) {
      return AppScaffold(
        body: EmptyState(message: s.audioNotAvailable, icon: Icons.headphones_outlined),
      );
    }
    final dur = a.duration ?? Duration.zero;
    final pos = a.position > dur ? dur : a.position;
    final sleepLabel = a.sleepAtEndOfChapter
        ? s.endOfChapter
        : a.sleepAt != null
        ? s.minutes(a.sleepAt!.difference(DateTime.now()).inMinutes + 1)
        : s.sleepTimer;

    return AppScaffold(
      title: a.version?.localName ?? '',
      actions: [
        if ((a.version?.audioAllowDownload ?? false) && ref.watch(audioRepositoryProvider).canDownload)
          IconButton(
            tooltip: s.downloadBook,
            icon: const Icon(Icons.download_outlined),
            onPressed: () => _downloadBook(context, ref, a),
          ),
      ],
      // Scrolls instead of overflowing on small screens / large text, while
      // still spreading out on tall screens.
      body: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight - AppSpacing.screen * 2),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Center(
                    child: _Cover(book: a.book!.shortName, chapter: '${a.chapter}'),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // The verse being read, when the recording has verse timings.
                  if (a.version != null && a.currentVerse != null)
                    _NowReading(versionId: a.version!.id, vkey: a.currentVerse!),
                  Center(
                    child: AppButton.ghost(
                      label: s.openInReader,
                      icon: Icons.menu_book_outlined,
                      onPressed: () => context.go(
                        '/read?ref=${BibleRef(a.book!.code, a.chapter!, a.currentVerse != null ? a.currentVerse! % 1000 : null).encode()}',
                      ),
                    ),
                  ),
                  if (a.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        audioErrorText(s, a.error!),
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium?.copyWith(color: context.colors.error),
                      ),
                    ),
                  const Spacer(),
                  Slider(
                    value: pos.inMilliseconds.toDouble(),
                    max: dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1,
                    onChanged: dur.inMilliseconds > 0 ? (v) => c.seek(Duration(milliseconds: v.round())) : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(pos), style: context.text.labelMedium),
                        Text(_fmt(dur), style: context.text.labelMedium),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        tooltip: s.previousChapter,
                        iconSize: AppIconSize.lg,
                        icon: const Icon(Icons.skip_previous),
                        onPressed: c.previous,
                      ),
                      IconButton(
                        tooltip: s.back10,
                        iconSize: AppIconSize.lg,
                        icon: const Icon(Icons.replay_10),
                        onPressed: () => c.skip(const Duration(seconds: -10)),
                      ),
                      IconButton.filled(
                        tooltip: a.playing ? s.pause : s.play,
                        iconSize: AppIconSize.xl,
                        icon: Icon(a.playing ? Icons.pause : Icons.play_arrow),
                        onPressed: a.status == AudioStatus.ready ? c.togglePlay : null,
                      ),
                      IconButton(
                        tooltip: s.forward10,
                        iconSize: AppIconSize.lg,
                        icon: const Icon(Icons.forward_10),
                        onPressed: () => c.skip(const Duration(seconds: 10)),
                      ),
                      IconButton(
                        tooltip: s.nextChapter,
                        iconSize: AppIconSize.lg,
                        icon: const Icon(Icons.skip_next),
                        onPressed: c.next,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      AppButton.secondary(
                        label: '${a.speed}×',
                        icon: Icons.speed,
                        size: AppButtonSize.sm,
                        onPressed: () async {
                          final v = await showOptionPicker(
                            context: context,
                            title: s.speed,
                            selected: a.speed,
                            options: [for (final x in speeds) PickerOption(x, '$x×')],
                          );
                          if (v != null) await c.setSpeed(v);
                        },
                      ),
                      AppButton.secondary(
                        label: sleepLabel,
                        icon: Icons.bedtime_outlined,
                        size: AppButtonSize.sm,
                        onPressed: () async {
                          final m = await showOptionPicker<int>(
                            context: context,
                            title: s.sleepTimer,
                            selected: a.sleepAtEndOfChapter ? -1 : null,
                            options: [
                              PickerOption(0, s.off),
                              for (final m in sleepMinutes) PickerOption(m, s.minutes(m)),
                              PickerOption(-1, s.endOfChapter),
                            ],
                          );
                          switch (m) {
                            case null:
                              break;
                            case 0:
                              c.setSleepTimer(null);
                            case -1:
                              c.setSleepTimer(null, endOfChapter: true);
                            default:
                              c.setSleepTimer(Duration(minutes: m));
                          }
                        },
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _downloadBook(BuildContext context, WidgetRef ref, AudioState a) async {
    final s = S.of(context);
    final repo = ref.read(audioRepositoryProvider);
    if (await mustWaitForWifi(ref.read(networkInfoProvider), wifiOnly: ref.read(settingsProvider).wifiOnly)) {
      if (context.mounted) showAppSnack(context, s.needWifi);
      return;
    }
    final chapters = await ref.read(contentRepositoryProvider).chapters(a.version!.id, a.book!);
    if (!context.mounted) return;
    final progress = ValueNotifier<int>(0);
    final sub = repo
        .downloadBook(a.version!.audioFilesetId!, a.book!.code, chapters)
        .listen(
          (n) => progress.value = n,
          onError: (Object e) {
            if (context.mounted) showAppSnack(context, s.audioNotAvailable);
          },
          onDone: () {
            ref.invalidate(downloadsProvider);
            if (context.mounted) Navigator.of(context, rootNavigator: true).maybePop();
          },
        );
    await showAppDialog<void>(
      context: context,
      title: s.downloading,
      content: ValueListenableBuilder<int>(
        valueListenable: progress,
        builder: (_, n, _) => LinearProgressIndicator(value: chapters.isEmpty ? null : n / chapters.length),
      ),
      actions: [AppButton.ghost(label: s.cancel, onPressed: () => Navigator.pop(context))],
    );
    unawaited(sub.cancel());
  }
}
