import 'package:amharic_bible/core/strings.dart';
import 'package:amharic_bible/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {ReaderTheme mode = ReaderTheme.light}) => MaterialApp(
  theme: buildAppTheme(
    mode: mode,
    platformBrightness: Brightness.light,
    readingFontSize: 19,
    readingLineHeight: 1.7,
    serif: true,
  ),
  locale: const Locale('en'),
  supportedLocales: S.supported,
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('AppButton sizes and states', (tester) async {
    for (final size in AppButtonSize.values) {
      await tester.pumpWidget(_app(AppButton(label: 'Go', size: size, onPressed: () {})));
      final box = tester.getSize(find.byType(FilledButton));
      // Visual height is the token; small buttons still get a 48dp target.
      expect(box.height, greaterThanOrEqualTo(size.height));
      expect(box.height, greaterThanOrEqualTo(AppDimens.touchTarget));
    }
    var taps = 0;
    await tester.pumpWidget(_app(AppButton(label: 'Go', loading: true, onPressed: () => taps++)));
    await tester.tap(find.byType(FilledButton));
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('every AppButton variant renders', (tester) async {
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (final v in AppButtonVariant.values) AppButton(label: v.name, variant: v, onPressed: () {})],
        ),
      ),
    );
    for (final v in AppButtonVariant.values) {
      expect(find.text(v.name), findsOneWidget);
    }
  });

  testWidgets('SwatchButton has a 48dp tap target', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _app(SwatchButton(semanticLabel: 'yellow', color: Colors.yellow, onTap: () => tapped = true)),
    );
    expect(tester.getSize(find.byType(SwatchButton)), const Size.square(AppDimens.touchTarget));
    await tester.tap(find.bySemanticsLabel('yellow'));
    expect(tapped, isTrue);
  });

  testWidgets('AsyncView shows a friendly error with retry, not the exception', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _app(
        AsyncView<int>(
          value: AsyncError(StateError('db exploded'), StackTrace.empty),
          data: (_) => const SizedBox(),
          onRetry: () => retried = true,
        ),
      ),
    );
    expect(find.textContaining('db exploded'), findsNothing);
    expect(find.text("Couldn't load this."), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('confirm dialog resolves true/false', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (c) => SizedBox(
            key: const Key('host'),
            child: Builder(
              builder: (c2) {
                ctx = c2;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    final result = showConfirmDialog(
      context: ctx,
      title: 'Delete?',
      message: 'Sure?',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      destructive: true,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });

  testWidgets('text field shows label, required mark and one error style', (tester) async {
    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 300,
          child: AppTextField(label: 'Email', required: true, error: 'Bad'),
        ),
      ),
    );
    expect(find.text('Email *'), findsOneWidget);
    expect(find.text('Bad'), findsOneWidget);
  });

  testWidgets('theme extensions exist in every reading theme', (tester) async {
    for (final mode in ReaderTheme.values) {
      await tester.pumpWidget(
        _app(
          Builder(builder: (c) => Text('x', style: c.reading.verse)),
          mode: mode,
        ),
      );
      final t = Theme.of(tester.element(find.text('x')));
      expect(t.extension<AppColors>(), isNotNull);
      expect(t.extension<ReadingStyles>()!.verse.fontSize, 19);
    }
  });

  testWidgets('status badge and empty state', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBadge('3 days behind', tone: BadgeTone.warning),
            SizedBox(height: 200, child: EmptyState(message: 'Nothing here')),
          ],
        ),
      ),
    );
    expect(find.text('3 days behind'), findsOneWidget);
    expect(find.text('Nothing here'), findsOneWidget);
  });
}
