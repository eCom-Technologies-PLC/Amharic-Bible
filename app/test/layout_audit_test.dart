// Layout audit: renders every screen on a small phone with large text, a
// normal phone and a tablet, in both UI languages and every reading theme, and
// fails on any layout error (RenderFlex overflow, unbounded sizes, etc.).
import 'dart:io';

import 'package:amharic_bible/app.dart';
import 'package:amharic_bible/data/audio_repository.dart';
import 'package:amharic_bible/data/user_repository.dart';
import 'package:amharic_bible/features/reader/paragraph_view.dart';
import 'package:amharic_bible/state/providers.dart';
import 'package:amharic_bible/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

const routes = [
  '/home',
  '/read?ref=JHN.3',
  '/read?ref=PSA.23',
  '/search',
  '/me',
  '/me/plans',
  '/me/plans/nt-90',
  '/me/plans/bible-year',
  '/me/activity',
  '/me/library',
  '/me/settings',
  '/me/account',
  '/me/about',
  '/me/downloads',
  '/books',
  '/player',
  '/note?start=43003016',
  '/share-image?keys=43003016,43003017',
];

class Device {
  const Device(this.name, this.size, this.textScale);
  final String name;
  final Size size; // logical pixels
  final double textScale;
}

const smallLargeText = Device('320dp @1.3x', Size(320, 640), 1.3);
const phone = Device('393dp', Size(393, 852), 1.0);
const tablet = Device('tablet', Size(1280, 800), 1.0);

Future<List<String>> render(
  WidgetTester tester, {
  required String route,
  required Device device,
  required Settings settings,
  Future<void> Function(WidgetTester)? interact,
}) async {
  (rootBundle as CachingAssetBundle).clear();
  late Database content, user;
  await tester.runAsync(() async {
    content = await openSampleContentDb();
    user = await openTestUserDb();
    await UserRepository(user).startPlan('nt-90');
    await UserRepository(user).setHighlight([43003016], HighlightColor.yellow);
    await UserRepository(user).toggleBookmarks([43003016]);
    await UserRepository(user).saveNote(vkeyStart: 43003016, vkeyEnd: 43003016, body: 'ማስታወሻ');
  });
  tester.view.physicalSize = device.size * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = device.textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (d) {
    errors.add(d.exceptionAsString().split('\n').first);
    if (Platform.environment['AUDIT_VERBOSE'] != null) stderr.writeln(d.toString());
  };
  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentDbProvider.overrideWithValue(content),
          userDbProvider.overrideWithValue(user),
          initialSettingsProvider.overrideWithValue(settings),
          audioRepositoryProvider.overrideWithValue(AudioRepository(baseUrl: '', storageDir: Directory.systemTemp)),
          routerProvider.overrideWithValue(buildRouter(initialLocation: route)),
        ],
        child: const AmharicBibleApp(),
      ),
    );
    await _settle(tester);
    if (interact != null) {
      await interact(tester);
      await _settle(tester);
    }
  } finally {
    FlutterError.onError = previous;
  }
  await tester.pumpWidget(const SizedBox());
  return errors.toSet().toList();
}

// Fixed pumps instead of pumpAndSettle: some screens legitimately animate.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('small phone, large text, every theme and language', () {
    for (final theme in [ReaderTheme.light, ReaderTheme.sepia, ReaderTheme.dark, ReaderTheme.black]) {
      for (final lang in ['am', 'en']) {
        for (final route in routes) {
          testWidgets('${theme.name} $lang $route', (tester) async {
            final errors = await render(
              tester,
              route: route,
              device: smallLargeText,
              settings: Settings(languageCode: lang, readerTheme: theme, parallelVersionId: 'WEB'),
            );
            expect(errors, isEmpty);
          });
        }
      }
    }
  });

  group('phone and tablet', () {
    for (final device in [phone, tablet]) {
      for (final route in routes) {
        testWidgets('${device.name} $route', (tester) async {
          final errors = await render(
            tester,
            route: route,
            device: device,
            settings: const Settings(parallelVersionId: 'WEB'),
          );
          expect(errors, isEmpty);
        });
      }
    }
  });

  group('interactive states on a small phone with large text', () {
    for (final lang in ['am', 'en']) {
      testWidgets('$lang reader with a verse selected', (tester) async {
        final errors = await render(
          tester,
          route: '/read?ref=GEN.1',
          device: smallLargeText,
          settings: Settings(languageCode: lang),
          interact: (t) async {
            final para = find.byType(ParagraphView).first;
            await t.tapAt(t.getTopLeft(para) + const Offset(60, 20));
          },
        );
        expect(errors, isEmpty);
      });

      testWidgets('$lang text settings sheet', (tester) async {
        final errors = await render(
          tester,
          route: '/read?ref=JHN.3',
          device: smallLargeText,
          settings: Settings(languageCode: lang),
          interact: (t) => t.tap(find.byIcon(Icons.text_fields)),
        );
        expect(errors, isEmpty);
      });

      testWidgets('$lang settings option picker', (tester) async {
        final errors = await render(
          tester,
          route: '/me/settings',
          device: smallLargeText,
          settings: Settings(languageCode: lang),
          interact: (t) => t.tap(find.byIcon(Icons.view_column_outlined)),
        );
        expect(errors, isEmpty);
      });
    }
  });
}
