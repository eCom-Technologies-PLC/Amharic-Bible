import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../common.dart';

/// Backgrounds bundled with the app (gradients, so no image assets needed).
class CardBackground {
  const CardBackground(this.colors, this.text);
  final List<Color> colors;
  final Color text;

  Decoration get decoration => colors.length == 1
      ? BoxDecoration(color: colors.first)
      : BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        );
}

const cardBackgrounds = [
  CardBackground([Color(0xFF0F3D2E), Color(0xFF1E6B4E)], Colors.white), // manuscript green
  CardBackground([Color(0xFFF7C873), Color(0xFFE07A5F)], Color(0xFF2B1A0E)), // sunrise
  CardBackground([Color(0xFF141E30), Color(0xFF243B55)], Colors.white), // night
  CardBackground([Color(0xFFF6EEDC)], Color(0xFF3B2F20)), // parchment
  CardBackground([Color(0xFF5B1A2E), Color(0xFF8E2C48)], Colors.white), // burgundy
  CardBackground([Color(0xFF2E86AB), Color(0xFF6CC3D5)], Colors.white), // sky
  CardBackground([Colors.white], Color(0xFF1B1B1B)),
  CardBackground([Colors.black], Colors.white),
];

enum CardShape {
  square(1),
  story(9 / 16);

  const CardShape(this.aspect);
  final double aspect;
}

/// The verses and their reference, in the current version.
final shareContentProvider = FutureProvider.family<({String text, String reference, String version})?, String>((
  ref,
  joinedKeys,
) async {
  final version = await ref.watch(currentVersionProvider.future);
  final keys = joinedKeys.split(',').map(int.parse).toList();
  final verses = await ref.watch(contentRepositoryProvider).verses(version.id, keys);
  if (verses.isEmpty) return null;
  final books = await ref.watch(booksProvider(version.id).future);
  return (
    text: verses.map((v) => v.text).join(' '),
    reference: formatKeys(books, [for (final v in verses) v.vkey], amharic: version.language == 'amh'),
    version: version.abbrev,
  );
});

class ShareImageScreen extends ConsumerStatefulWidget {
  const ShareImageScreen({super.key, required this.vkeys});

  final List<int> vkeys;

  @override
  ConsumerState<ShareImageScreen> createState() => _ShareImageScreenState();
}

class _ShareImageScreenState extends ConsumerState<ShareImageScreen> {
  final _cardKey = GlobalKey();
  int _bg = 0;
  CardShape _shape = CardShape.square;
  bool _serif = true;
  bool _busy = false;

  Future<void> _share(String reference) async {
    setState(() => _busy = true);
    try {
      final png = await renderCardPng(_cardKey);
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'verse_${DateTime.now().millisecondsSinceEpoch}.png'));
      await file.writeAsBytes(png);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: reference,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final content = ref.watch(shareContentProvider(widget.vkeys.join(',')));
    return Scaffold(
      appBar: AppBar(title: Text(s.shareImage)),
      body: AsyncBody(
        value: content,
        data: (c) {
          if (c == null) return Center(child: Text(s.notInVersion));
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AspectRatio(
                      aspectRatio: _shape.aspect,
                      child: FittedBox(
                        child: RepaintBoundary(
                          key: _cardKey,
                          child: VerseCard(
                            text: c.text,
                            reference: '${c.reference} (${c.version})',
                            footer: s.appName,
                            background: cardBackgrounds[_bg],
                            shape: _shape,
                            fontFamily: _serif ? serifFont : sansFont,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (var i = 0; i < cardBackgrounds.length; i++)
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Semantics(
                          button: true,
                          selected: i == _bg,
                          label: '${s.background} ${i + 1}',
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => setState(() => _bg = i),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: cardBackgrounds[i].colors.length > 1
                                    ? LinearGradient(colors: cardBackgrounds[i].colors)
                                    : null,
                                color: cardBackgrounds[i].colors.length == 1 ? cardBackgrounds[i].colors.first : null,
                                border: Border.all(
                                  width: i == _bg ? 3 : 1,
                                  color: i == _bg
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    SegmentedButton<CardShape>(
                      segments: const [
                        ButtonSegment(value: CardShape.square, icon: Icon(Icons.crop_square)),
                        ButtonSegment(value: CardShape.story, icon: Icon(Icons.crop_portrait)),
                      ],
                      selected: {_shape},
                      onSelectionChanged: (v) => setState(() => _shape = v.first),
                    ),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: true,
                          label: Text(s.serif, style: const TextStyle(fontFamily: serifFont)),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text(s.sans, style: const TextStyle(fontFamily: sansFont)),
                        ),
                      ],
                      selected: {_serif},
                      onSelectionChanged: (v) => setState(() => _serif = v.first),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _share('${c.reference} (${c.version})'),
                      icon: _busy
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.share),
                      label: Text(s.share),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The shareable card, laid out at a fixed logical size (360 wide) and
/// rendered at 3x, giving a 1080 px wide image.
class VerseCard extends StatelessWidget {
  const VerseCard({
    super.key,
    required this.text,
    required this.reference,
    required this.footer,
    required this.background,
    required this.shape,
    required this.fontFamily,
  });

  static const width = 360.0;

  final String text;
  final String reference;
  final String footer;
  final CardBackground background;
  final CardShape shape;
  final String fontFamily;

  /// Longer passages get a smaller starting size; FittedBox shrinks further
  /// only if still needed.
  double get fontSize => (30 - text.length / 14).clamp(15, 28).toDouble();

  @override
  Widget build(BuildContext context) {
    final height = width / shape.aspect;
    final color = background.text;
    return Container(
      width: width,
      height: height,
      decoration: background.decoration,
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 20),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: width - 56,
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: fontFamily, fontSize: fontSize, height: 1.6, color: color),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            reference,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            footer,
            style: TextStyle(fontFamily: sansFont, fontSize: 11, color: color.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

/// Renders the widget under [key] (a RepaintBoundary) to PNG bytes at a
/// size of 1080 px wide.
Future<Uint8List> renderCardPng(GlobalKey key) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ratio = 1080 / boundary.size.width;
  final image = await boundary.toImage(pixelRatio: ratio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
