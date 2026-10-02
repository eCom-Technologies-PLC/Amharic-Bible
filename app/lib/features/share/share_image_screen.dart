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
    final ready = content.value;
    return AppScaffold(
      title: s.shareImage,
      body: AsyncView(
        value: content,
        data: (c) {
          if (c == null) return EmptyState(message: s.notInVersion, icon: Icons.image_not_supported_outlined);
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
                        reference: '${c.reference} (${c.version})',
                        footer: s.appName,
                        background: cardBackgrounds[_bg],
                        shape: _shape,
                        fontFamily: _serif ? AppFonts.serif : AppFonts.sans,
                      ),
                    ),
                  ),
                ),
              ),
              SectionHeader(s.background),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen - AppSpacing.xs),
                child: Row(
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
              Gutter(
                vertical: AppSpacing.lg,
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
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
                  ],
                ),
              ),
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
                  onPressed: () => _share('${ready.reference} (${ready.version})'),
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
  });

  final String text;
  final String reference;
  final String footer;
  final CardBackground background;
  final CardShape shape;
  final String fontFamily;

  @override
  Widget build(BuildContext context) {
    const width = ShareCardTokens.canvasWidth;
    final color = background.text;
    return Container(
      width: width,
      height: width / shape.aspect,
      decoration: background.decoration,
      padding: ShareCardTokens.padding,
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
                      fontSize: ShareCardTokens.verseSize(text.length),
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
