import 'package:amharic_bible/core/localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  // The app's delegates carry Amharic and English only (so the web download
  // leaves Flutter's other languages out); what they give must match Flutter's
  // own delegates exactly.
  for (final language in ['am', 'en']) {
    testWidgets('Flutter texts and dates in "$language" match Flutter\'s own delegates', (tester) async {
      Future<List<String>> texts(List<LocalizationsDelegate<dynamic>> delegates) async {
        late BuildContext context;
        await tester.pumpWidget(
          Localizations(
            locale: Locale(language),
            delegates: delegates,
            child: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        );
        final material = MaterialLocalizations.of(context);
        final cupertino = CupertinoLocalizations.of(context);
        final date = DateTime(2026, 11, 3, 14, 5);
        return [
          material.okButtonLabel,
          material.backButtonTooltip,
          material.modalBarrierDismissLabel,
          material.formatMediumDate(date),
          material.formatFullDate(date),
          material.formatMonthYear(date),
          material.formatTimeOfDay(TimeOfDay.fromDateTime(date)),
          material.formatDecimal(1234567),
          cupertino.datePickerMediumDate(date),
          cupertino.datePickerHour(14),
          cupertino.datePickerMinuteSemanticsLabel(5) ?? '',
          cupertino.todayLabel,
          WidgetsLocalizations.of(context).textDirection.name,
          // The app's own dates (features/common.dart) use intl's data.
          DateFormat.yMMMd(language).format(date),
        ];
      }

      final ours = await texts(appLocalizationsDelegates);
      final flutters = await texts(GlobalMaterialLocalizations.delegates);
      expect(ours, flutters);
      expect(ours.first, isNotEmpty);
    });
  }

  test('only the app\'s two languages are claimed', () {
    for (final delegate in appLocalizationsDelegates) {
      expect(delegate.isSupported(const Locale('am')), isTrue);
      expect(delegate.isSupported(const Locale('en', 'GB')), isTrue);
      expect(delegate.isSupported(const Locale('fr')), isFalse);
    }
  });
}
