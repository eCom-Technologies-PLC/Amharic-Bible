import 'dart:async';

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
import '../state/study.dart';
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
  final s = S.of(context);
  return showAppBottomSheet<void>(
    context: context,
    title: s.goTo,
    builder: (sheet) => _ReferenceField(
      hint: s.goToHint,
      onSubmitted: (q) async {
        final r = (await ref.read(referenceParserProvider.future)).parse(q);
        if (sheet.mounted) Navigator.of(sheet).pop();
        if (!context.mounted) return null;
        context.go(
          r != null
              ? '/read?ref=${BibleRef(r.bookCode, r.chapter, r.verse).encode()}'
              : Uri(path: '/search', queryParameters: {'q': q}).toString(),
        );
        return null;
      },
    ),
  );
}

/// Asks which passage to put to the study assistant ("ዮሐ 3፥16", "Jn 3:16-18"),
/// then opens Ask about it.
Future<void> showAskForPassage(BuildContext context, WidgetRef ref) {
  final s = S.of(context);
  return showAppBottomSheet<void>(
    context: context,
    title: s.whichPassage,
    builder: (sheet) => _ReferenceField(
      hint: s.passageHint,
      onSubmitted: (q) async {
        final r = (await ref.read(referenceParserProvider.future)).parse(q);
        final books = await ref.read(refBooksProvider.future);
        final book = r == null ? null : books.where((b) => b.code == r.bookCode).firstOrNull;
        if (r == null || book == null) return s.notAReference;
        if (sheet.mounted) Navigator.of(sheet).pop();
        if (context.mounted) {
          final end = r.verseEnd;
          unawaited(
            context.push(
              '/ask?v=${vkey(book.num, r.chapter, r.verse ?? 1)}${end == null ? '' : '&end=${vkey(book.num, r.chapter, end)}'}',
            ),
          );
        }
        return null;
      },
    ),
  );
}

/// A field for a reference in a sheet. [onSubmitted] returns an error to show
/// under it, or null once handled. It owns its controller, which must outlive
/// the sheet's closing animation.
class _ReferenceField extends StatefulWidget {
  const _ReferenceField({required this.hint, required this.onSubmitted});

  final String hint;
  final Future<String?> Function(String text) onSubmitted;

  @override
  State<_ReferenceField> createState() => _ReferenceFieldState();
}

class _ReferenceFieldState extends State<_ReferenceField> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppTextField(
    controller: _controller,
    hint: widget.hint,
    error: _error,
    autofocus: true,
    prefixIcon: Icons.search,
    textInputAction: TextInputAction.go,
    onSubmitted: (text) async {
      final q = text.trim();
      if (q.isEmpty) return;
      final error = await widget.onSubmitted(q);
      if (mounted) setState(() => _error = error);
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
