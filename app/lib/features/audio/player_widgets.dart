import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../state/providers.dart';
import '../common.dart';
import '../reader/reader_screen.dart' show audioErrorText;
import '../settings/downloads_screen.dart';
import 'audio_controller.dart';

String _fmt(Duration d) {
  final m = d.inMinutes;
  final sec = d.inSeconds % 60;
  return '$m:${sec.toString().padLeft(2, '0')}';
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
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => context.push('/player'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: progress.clamp(0, 1), minHeight: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: s.listen,
                    icon: a.status == AudioStatus.loading
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(a.playing ? Icons.pause : Icons.play_arrow),
                    onPressed: a.status == AudioStatus.ready ? c.togglePlay : null,
                  ),
                  Expanded(
                    child: Text(
                      a.error != null ? audioErrorText(s, a.error!) : '${a.book!.shortName} ${a.chapter}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('${_fmt(a.position)} · ${a.speed}×', style: Theme.of(context).textTheme.labelSmall),
                  IconButton(tooltip: s.clear, icon: const Icon(Icons.close), onPressed: c.stop),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final a = ref.watch(audioControllerProvider);
    final c = ref.read(audioControllerProvider.notifier);
    final t = Theme.of(context).textTheme;
    if (a.book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(s.audioNotAvailable)),
      );
    }
    final dur = a.duration ?? Duration.zero;
    final pos = a.position > dur ? dur : a.position;

    return Scaffold(
      appBar: AppBar(
        title: Text(a.version?.localName ?? ''),
        actions: [
          if (a.version?.audioAllowDownload ?? false)
            IconButton(
              tooltip: s.downloadBook,
              icon: const Icon(Icons.download_outlined),
              onPressed: () => _downloadBook(context, ref, a),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Icon(Icons.menu_book, size: 96, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text('${a.book!.shortName} ${a.chapter}', style: t.headlineMedium),
            if (a.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(audioErrorText(s, a.error!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const Spacer(),
            Slider(
              value: pos.inMilliseconds.toDouble(),
              max: dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1,
              onChanged: dur.inMilliseconds > 0 ? (v) => c.seek(Duration(milliseconds: v.round())) : null,
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_fmt(pos)), Text(_fmt(dur))]),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: s.previousChapter,
                  iconSize: 32,
                  icon: const Icon(Icons.skip_previous),
                  onPressed: c.previous,
                ),
                IconButton(
                  tooltip: '−10s',
                  iconSize: 32,
                  icon: const Icon(Icons.replay_10),
                  onPressed: () => c.skip(const Duration(seconds: -10)),
                ),
                IconButton.filled(
                  tooltip: s.listen,
                  iconSize: 48,
                  icon: Icon(a.playing ? Icons.pause : Icons.play_arrow),
                  onPressed: a.status == AudioStatus.ready ? c.togglePlay : null,
                ),
                IconButton(
                  tooltip: '+10s',
                  iconSize: 32,
                  icon: const Icon(Icons.forward_10),
                  onPressed: () => c.skip(const Duration(seconds: 10)),
                ),
                IconButton(tooltip: s.nextChapter, iconSize: 32, icon: const Icon(Icons.skip_next), onPressed: c.next),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                PopupMenuButton<double>(
                  tooltip: s.speed,
                  initialValue: a.speed,
                  onSelected: c.setSpeed,
                  itemBuilder: (_) => [for (final x in speeds) PopupMenuItem(value: x, child: Text('$x×'))],
                  child: Chip(avatar: const Icon(Icons.speed, size: 18), label: Text('${a.speed}×')),
                ),
                PopupMenuButton<int>(
                  tooltip: s.sleepTimer,
                  onSelected: (m) => switch (m) {
                    0 => c.setSleepTimer(null),
                    -1 => c.setSleepTimer(null, endOfChapter: true),
                    _ => c.setSleepTimer(Duration(minutes: m)),
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 0, child: Text(s.off)),
                    for (final m in [5, 15, 30, 60]) PopupMenuItem(value: m, child: Text(s.minutes(m))),
                    PopupMenuItem(value: -1, child: Text(s.endOfChapter)),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.bedtime_outlined, size: 18),
                    label: Text(
                      a.sleepAtEndOfChapter
                          ? s.endOfChapter
                          : a.sleepAt != null
                          ? s.minutes(a.sleepAt!.difference(DateTime.now()).inMinutes + 1)
                          : s.sleepTimer,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadBook(BuildContext context, WidgetRef ref, AudioState a) async {
    final s = S.of(context);
    final repo = ref.read(audioRepositoryProvider);
    final chapters = await ref.read(contentRepositoryProvider).chapters(a.version!.id, a.book!);
    if (!context.mounted) return;
    final progress = ValueNotifier<int>(0);
    final sub = repo
        .downloadBook(a.version!.audioFilesetId!, a.book!.code, chapters)
        .listen(
          (n) => progress.value = n,
          onError: (Object e) {
            if (context.mounted) showSnack(context, s.audioNotAvailable);
          },
          onDone: () {
            ref.invalidate(downloadsProvider);
            if (context.mounted) Navigator.of(context, rootNavigator: true).maybePop();
          },
        );
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.downloading),
        content: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (_, n, _) => LinearProgressIndicator(value: chapters.isEmpty ? null : n / chapters.length),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel))],
      ),
    );
    unawaited(sub.cancel());
  }
}
