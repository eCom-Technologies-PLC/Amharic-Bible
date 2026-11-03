import 'dart:async';

import 'package:amharic_bible/core/strings.dart';
import 'package:amharic_bible/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  group('sheets', () {
    // A button that opens a sheet, at [alignment] in a window of [size].
    Future<void> host(
      WidgetTester tester,
      Size size,
      Future<void> Function(BuildContext button) open, {
      Alignment alignment = Alignment.topLeft,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(
            mode: ReaderTheme.light,
            platformBrightness: Brightness.light,
            readingFontSize: 19,
            readingLineHeight: 1.7,
            serif: true,
          ),
          locale: const Locale('en'),
          supportedLocales: S.supported,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => LastPress(child: child!),
          home: Scaffold(
            body: Align(
              alignment: alignment,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxxl),
                child: Builder(
                  builder: (button) => AppButton(label: 'Open', onPressed: () => open(button)),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Rect popover(WidgetTester tester, String text) =>
        tester.getRect(find.ancestor(of: find.text(text), matching: find.byType(Material)).first);

    testWidgets('rise from the bottom on a phone', (tester) async {
      await host(
        tester,
        const Size(400, 800),
        (b) => showAppBottomSheet<void>(context: b, anchor: b, title: 'Details', builder: (_) => const Text('Body')),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('open under their control on a wide window, and close with Esc', (tester) async {
      await host(
        tester,
        const Size(1280, 800),
        (b) => showAppBottomSheet<void>(context: b, anchor: b, title: 'Details', builder: (_) => const Text('Body')),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      final button = tester.getRect(find.byType(AppButton));
      final sheet = popover(tester, 'Body');
      expect(sheet.top, button.bottom + AppSpacing.xs);
      expect(sheet.left, button.left);
      expect(sheet.width, AppDimens.popoverWidth);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Body'), findsNothing);
    });

    testWidgets('open above a control near the bottom, inside the window', (tester) async {
      await host(
        tester,
        const Size(1280, 800),
        (b) => showAppBottomSheet<void>(
          context: b,
          anchor: b,
          title: 'More',
          builder: (_) => const SizedBox(height: 300, child: Text('Body')),
        ),
        alignment: Alignment.bottomRight,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final button = tester.getRect(find.byType(AppButton));
      final sheet = popover(tester, 'Body');
      expect(sheet.bottom, button.top - AppSpacing.xs);
      expect(sheet.right, lessThanOrEqualTo(1280 - AppSpacing.lg));
    });

    testWidgets('options open where they were pressed and return the choice', (tester) async {
      String? chosen;
      await host(tester, const Size(1280, 800), (b) async {
        chosen = await showOptionPicker<String>(
          context: b,
          title: 'Language',
          selected: 'am',
          options: const [PickerOption('am', 'አማርኛ'), PickerOption('en', 'English')],
        );
      });
      final spot = tester.getCenter(find.text('Open'));
      await tester.tapAt(spot);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(popover(tester, 'English').topLeft, spot + const Offset(0, AppSpacing.xs));
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(chosen, 'en');
      expect(find.text('English'), findsNothing);
    });

    testWidgets('open centered when nothing was pressed, or for a moment', (tester) async {
      await host(
        tester,
        const Size(1280, 800),
        (b) => showAppBottomSheet<void>(context: b, centered: true, title: 'Done!', builder: (_) => const Text('Body')),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      Navigator.of(tester.element(find.text('Body'))).pop();
      await tester.pumpAndSettle();

      // Opened by a keyboard shortcut, just after that click: the key press
      // means the click didn't open it, so there is nothing to point at.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      final context = tester.element(find.text('Open'));
      unawaited(showAppBottomSheet<void>(context: context, title: 'Go to', builder: (_) => const Text('Field')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Field'), findsOneWidget);
    });
  });
}
