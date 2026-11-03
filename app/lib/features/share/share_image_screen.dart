import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../state/providers.dart';
import '../../ui/tokens/share_card_tokens.dart';
import '../../ui/ui.dart';
import '../common.dart';

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
  int _size = 1; // index into ShareCardTokens.textScales
  bool _frame = false;
  bool _withVersion = true;
  bool _busy = false;

  Future<void> _share(String reference) async {
    setState(() => _busy = true);
    try {
      await sharePng(_cardKey, reference, name: 'verse');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final content = ref.watch(shareContentProvider(widget.vkeys.join(',')));
    final ready = content.value;
    return AppScaffold(
      title: s.shareImage,
      body: AsyncView(
        value: content,
        data: (c) {
          if (c == null) return EmptyState(message: s.notInVersion, icon: Icons.image_not_supported_outlined);
          final reference = _withVersion ? '${c.reference} (${c.version})' : c.reference;
          return AppListView(
            children: [
              Gutter(
                vertical: AppSpacing.sm,
                child: AspectRatio(
                  aspectRatio: _shape.aspect,
                  child: FittedBox(
                    child: RepaintBoundary(
                      key: _cardKey,
                      child: VerseCard(
                        text: c.text,
                        reference: reference,
                        footer: s.appName,
                        background: cardBackgrounds[_bg],
                        shape: _shape,
                        fontFamily: _serif ? AppFonts.serif : AppFonts.sans,
                        textScale: ShareCardTokens.textScales[_size],
                        frame: _frame,
                      ),
                    ),
                  ),
                ),
              ),
              SectionHeader(s.background),
              // Wraps rather than scrolls: every background stays in view, and
              // a mouse can't drag a row sideways.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen - AppSpacing.xs),
                child: Wrap(
                  children: [
                    for (var i = 0; i < cardBackgrounds.length; i++)
                      SwatchButton(
                        semanticLabel: '${s.background} ${i + 1}',
                        selected: i == _bg,
                        color: cardBackgrounds[i].colors.first,
                        gradient: cardBackgrounds[i].gradient,
                        onTap: () => setState(() => _bg = i),
                      ),
                  ],
                ),
              ),
              SectionHeader(s.cardStyle),
              Gutter(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    SegmentedButton<CardShape>(
                      segments: [
                        ButtonSegment(
                          value: CardShape.square,
                          icon: const Icon(Icons.crop_square),
                          tooltip: s.shapeSquare,
                        ),
                        ButtonSegment(
                          value: CardShape.story,
                          icon: const Icon(Icons.crop_portrait),
                          tooltip: s.shapeStory,
                        ),
                      ],
                      selected: {_shape},
                      onSelectionChanged: (v) => setState(() => _shape = v.first),
                    ),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: true,
                          label: Text(s.serif, style: context.text.labelLarge?.copyWith(fontFamily: AppFonts.serif)),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text(s.sans, style: context.text.labelLarge?.copyWith(fontFamily: AppFonts.sans)),
                        ),
                      ],
                      selected: {_serif},
                      onSelectionChanged: (v) => setState(() => _serif = v.first),
                    ),
                    SegmentedButton<int>(
                      segments: [
                        ButtonSegment(value: 0, icon: const Icon(Icons.text_decrease), tooltip: s.textSmaller),
                        ButtonSegment(value: 1, icon: const Icon(Icons.text_fields), tooltip: s.textDefault),
                        ButtonSegment(value: 2, icon: const Icon(Icons.text_increase), tooltip: s.textLarger),
                      ],
                      selected: {_size},
                      onSelectionChanged: (v) => setState(() => _size = v.first),
                    ),
                    FilterChip(
                      label: Text(s.ornamentFrame),
                      selected: _frame,
                      onSelected: (v) => setState(() => _frame = v),
                    ),
                    FilterChip(
                      label: Text(s.showVersion),
                      selected: _withVersion,
                      onSelected: (v) => setState(() => _withVersion = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
      bottomBar: ready == null
          ? null
          : BottomActionBar(
              children: [
                AppButton(
                  label: s.share,
                  icon: Icons.share,
                  size: AppButtonSize.lg,
                  expand: true,
                  loading: _busy,
                  onPressed: () => _share(_withVersion ? '${ready.reference} (${ready.version})' : ready.reference),
                ),
              ],
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
    this.textScale = 1,
    this.frame = false,
  });

  final String text;
  final String reference;
  final String footer;
  final CardBackground background;
  final CardShape shape;
  final String fontFamily;

  /// Factor on the verse's starting size (ShareCardTokens.textScales).
  final double textScale;

  /// Draws the ornament frame inside the edge.
  final bool frame;

  @override
  Widget build(BuildContext context) {
    const width = ShareCardTokens.canvasWidth;
    final color = background.text;
    final card = Container(
      width: width,
      height: width / shape.aspect,
      decoration: background.decoration,
      padding: frame ? ShareCardTokens.framedPadding : ShareCardTokens.padding,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: width - ShareCardTokens.padding.horizontal,
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: ShareCardTokens.verseSize(text.length) * textScale,
                      height: ShareCardTokens.lineHeight,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: ShareCardTokens.referenceGap),
          Text(
            reference,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: ShareCardTokens.referenceSize,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: ShareCardTokens.footerGap),
          Text(
            footer,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: ShareCardTokens.footerSize,
              color: color.withValues(alpha: ShareCardTokens.footerOpacity),
            ),
          ),
        ],
      ),
    );
    if (!frame) return card;
    return CustomPaint(
      foregroundPainter: _OrnamentFrame(color.withValues(alpha: ShareCardTokens.frameOpacity)),
      child: card,
    );
  }
}

/// A double rule inset from the card's edge, with small diamonds at the
/// corners and the middle of the top and bottom: a placeholder for the
/// illustrator's harag border.
class _OrnamentFrame extends CustomPainter {
  const _OrnamentFrame(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = ShareCardTokens.frameStroke;
    final fill = Paint()..color = color;
    const inset = ShareCardTokens.frameInset;
    final outer = Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2);
    canvas
      ..drawRect(outer, line)
      ..drawRect(outer.deflate(ShareCardTokens.frameGap), line);
    const d = ShareCardTokens.frameDiamond;
    for (final c in [
      outer.topLeft,
      outer.topCenter,
      outer.topRight,
      outer.bottomLeft,
      outer.bottomCenter,
      outer.bottomRight,
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - d)
          ..lineTo(c.dx + d, c.dy)
          ..lineTo(c.dx, c.dy + d)
          ..lineTo(c.dx - d, c.dy)
          ..close(),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(_OrnamentFrame old) => old.color != color;
}

/// Shares the picture under [key] (a RepaintBoundary) as a 1080 px PNG with
/// [text], through the system share sheet; browsers without one download it.
/// [name] starts the file's name ("verse", "plan").
Future<void> sharePng(GlobalKey key, String text, {required String name}) async {
  final png = await renderCardPng(key);
  final file = '${name}_${DateTime.now().millisecondsSinceEpoch}.png';
  if (kIsWeb) {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, name: file, mimeType: 'image/png')],
        fileNameOverrides: [file],
        text: text,
      ),
    );
    return;
  }
  final path = p.join((await getTemporaryDirectory()).path, file);
  await File(path).writeAsBytes(png);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(path, mimeType: 'image/png')],
      text: text,
    ),
  );
}

/// The picture shared when a reading plan is finished: "Plan complete", the
/// plan's name and length, on the illuminated background in the ornament
/// frame. Square, laid out at 360 like [VerseCard].
class PlanCompleteCard extends StatelessWidget {
  const PlanCompleteCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.footer,
  });

  final String eyebrow;
  final String title;
  final String detail;
  final String footer;

  @override
  Widget build(BuildContext context) {
    const width = ShareCardTokens.canvasWidth;
    const background = illuminatedCard;
    final color = background.text;
    return CustomPaint(
      foregroundPainter: _OrnamentFrame(color.withValues(alpha: ShareCardTokens.frameOpacity)),
      child: Container(
        width: width,
        height: width,
        decoration: background.decoration,
        padding: ShareCardTokens.framedPadding,
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    eyebrow.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: ShareCardTokens.eyebrowSize,
                      letterSpacing: ShareCardTokens.eyebrowSpacing,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: ShareCardTokens.referenceGap),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.serif,
                      fontSize: ShareCardTokens.planTitleSize,
                      fontWeight: FontWeight.w600,
                      height: ShareCardTokens.planTitleHeight,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: ShareCardTokens.referenceGap),
                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: AppFonts.sans, fontSize: ShareCardTokens.referenceSize, color: color),
                  ),
                ],
              ),
            ),
            Text(
              footer,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: ShareCardTokens.footerSize,
                color: color.withValues(alpha: ShareCardTokens.footerOpacity),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the widget under [key] (a RepaintBoundary) to PNG bytes at a
/// size of 1080 px wide.
Future<Uint8List> renderCardPng(GlobalKey key) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ratio = ShareCardTokens.outputWidthPx / boundary.size.width;
  final image = await boundary.toImage(pixelRatio: ratio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
