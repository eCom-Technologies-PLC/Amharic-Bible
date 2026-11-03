import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../core/ethiopian_calendar.dart';
import '../core/web/web_storage.dart';
import '../core/geez.dart';
import '../core/strings.dart';
import '../core/vkey.dart';
import '../domain/models.dart';
import '../state/providers.dart';
import '../ui/ui.dart';

/// Compresses verse numbers into ranges: [1,2,3,5] -> "1-3, 5".
String verseRanges(Iterable<int> verses) {
  final v = verses.toSet().toList()..sort();
  final parts = <String>[];
  for (var i = 0; i < v.length;) {
    var j = i;
    while (j + 1 < v.length && v[j + 1] == v[j] + 1) {
      j++;
    }
    parts.add(i == j ? '${v[i]}' : '${v[i]}-${v[j]}');
    i = j + 1;
  }
  return parts.join(', ');
}

/// "ዮሐንስ 3፥16-17" for Amharic text, "John 3:16-17" otherwise.
String formatReference(Book book, int chapter, Iterable<int> verses, {required bool amharic}) {
  final sep = amharic ? '፥' : ':';
  final vs = verseRanges(verses);
  return vs.isEmpty ? '${book.shortName} $chapter' : '${book.shortName} $chapter$sep$vs';
}

/// Reference for verse keys that may span chapters or books.
String formatKeys(List<Book> books, List<int> keys, {required bool amharic}) {
  if (keys.isEmpty) return '';
  final byNum = {for (final b in books) b.num: b};
  final groups = <(int, int), List<int>>{};
  for (final k in keys) {
    (groups[(vkeyBook(k), vkeyChapter(k))] ??= []).add(vkeyVerse(k));
  }
  return [
    for (final e in groups.entries)
      if (byNum[e.key.$1] case final b?) formatReference(b, e.key.$2, e.value, amharic: amharic),
  ].join('; ');
}

/// "07:00" for 420 minutes after midnight.
String formatTimeOfDay(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

String formatNumber(int n, Settings s) => s.geezNumerals ? intToGeez(n) : '$n';

String formatDate(DateTime d, Settings s, S strings) {
  if (s.ethiopianCalendar) return EthiopianDate.fromGregorian(d.toLocal()).format(amharic: strings.isAmharic);
  return DateFormat.yMMMd(strings.locale.languageCode).format(d.toLocal());
}

/// Shares [text] with the system share sheet. Browsers without one (most
/// desktop browsers) would open an email instead, so there the text is copied
/// and the reader is told.
Future<void> shareText(BuildContext context, String text, {String? subject}) async {
  if (kIsWeb && !webCanShare()) {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showAppSnack(context, S.of(context).copiedForSharing);
    return;
  }
  await SharePlus.instance.share(ShareParams(text: text, subject: subject));
}

/// The "Go to" box (Ctrl+K or ⌘K): a reference ("ዮሐ 3፥16", "Jn 3:16") opens
/// the reader there; anything else opens search with it.
Future<void> showGoTo(BuildContext context, WidgetRef ref) {
  return showAppBottomSheet<void>(
    context: context,
    title: S.of(context).goTo,
    builder: (sheet) => _GoToField(
      onSubmitted: (q) async {
        final r = (await ref.read(referenceParserProvider.future)).parse(q);
        if (sheet.mounted) Navigator.of(sheet).pop();
        if (!context.mounted) return;
        context.go(
          r != null
              ? '/read?ref=${BibleRef(r.bookCode, r.chapter, r.verse).encode()}'
              : Uri(path: '/search', queryParameters: {'q': q}).toString(),
        );
      },
    ),
  );
}

/// The Go-to box's field; it owns its controller, which must outlive the
/// sheet's closing animation.
class _GoToField extends StatefulWidget {
  const _GoToField({required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

  @override
  State<_GoToField> createState() => _GoToFieldState();
}

class _GoToFieldState extends State<_GoToField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppTextField(
    controller: _controller,
    hint: S.of(context).goToHint,
    autofocus: true,
    prefixIcon: Icons.search,
    textInputAction: TextInputAction.go,
    onSubmitted: (text) {
      final q = text.trim();
      if (q.isNotEmpty) widget.onSubmitted(q);
    },
  );
}

/// Shown for a link that matches no screen (a typo, or an old address).
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AppScaffold(
      body: EmptyState(
        message: s.pageNotFound,
        icon: Icons.explore_off_outlined,
        action: AppButton(label: s.home, icon: Icons.home_outlined, onPressed: () => context.go('/home')),
      ),
    );
  }
}

/// Banner shown when the bundled content is sample text only.
class SampleBanner extends ConsumerWidget {
  const SampleBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sample = ref.watch(isSampleProvider).value ?? false;
    if (!sample) return const SizedBox.shrink();
    final colors = context.appColors;
    return Material(
      color: colors.infoContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: AppIconSize.sm, color: colors.onInfoContainer),
            const SizedBox(width: AppSpacing.iconGap),
            Expanded(
              child: Text(
                S.of(context).sampleBanner,
                style: context.text.bodySmall?.copyWith(color: colors.onInfoContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
