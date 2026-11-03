import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'date_data.dart';

/// Flutter's own texts (buttons, pickers, screen-reader labels, dates) in the
/// app's two languages.
///
/// `GlobalMaterialLocalizations.delegates` gives the same texts, but it picks
/// them from every language Flutter supports (about 80), all of which the web
/// app would download; these delegates name Amharic and English only, so the
/// compiler leaves the rest out. The dates are formatted as Flutter's
/// delegates format them.
const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  _MaterialTexts(),
  _CupertinoTexts(),
  _WidgetsTexts(),
];

bool _isAppLanguage(Locale locale) => locale.languageCode == 'am' || locale.languageCode == 'en';

class _MaterialTexts extends LocalizationsDelegate<MaterialLocalizations> {
  const _MaterialTexts();

  @override
  bool isSupported(Locale locale) => _isAppLanguage(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    initializeAppDateFormatting();
    final name = locale.languageCode;
    final fullYearFormat = intl.DateFormat.y(name);
    final compactDateFormat = intl.DateFormat.yMd(name);
    final shortDateFormat = intl.DateFormat.yMMMd(name);
    final mediumDateFormat = intl.DateFormat.MMMEd(name);
    final longDateFormat = intl.DateFormat.yMMMMEEEEd(name);
    final yearMonthFormat = intl.DateFormat.yMMMM(name);
    final shortMonthDayFormat = intl.DateFormat.MMMd(name);
    final decimalFormat = intl.NumberFormat.decimalPattern(name);
    final twoDigitZeroPaddedFormat = intl.NumberFormat('00', name);
    return SynchronousFuture<MaterialLocalizations>(
      name == 'am'
          ? MaterialLocalizationAm(
              fullYearFormat: fullYearFormat,
              compactDateFormat: compactDateFormat,
              shortDateFormat: shortDateFormat,
              mediumDateFormat: mediumDateFormat,
              longDateFormat: longDateFormat,
              yearMonthFormat: yearMonthFormat,
              shortMonthDayFormat: shortMonthDayFormat,
              decimalFormat: decimalFormat,
              twoDigitZeroPaddedFormat: twoDigitZeroPaddedFormat,
            )
          : MaterialLocalizationEn(
              fullYearFormat: fullYearFormat,
              compactDateFormat: compactDateFormat,
              shortDateFormat: shortDateFormat,
              mediumDateFormat: mediumDateFormat,
              longDateFormat: longDateFormat,
              yearMonthFormat: yearMonthFormat,
              shortMonthDayFormat: shortMonthDayFormat,
              decimalFormat: decimalFormat,
              twoDigitZeroPaddedFormat: twoDigitZeroPaddedFormat,
            ),
    );
  }

  @override
  bool shouldReload(_MaterialTexts old) => false;
}

class _CupertinoTexts extends LocalizationsDelegate<CupertinoLocalizations> {
  const _CupertinoTexts();

  @override
  bool isSupported(Locale locale) => _isAppLanguage(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    initializeAppDateFormatting();
    final name = locale.languageCode;
    final fullYearFormat = intl.DateFormat.y(name);
    final dayFormat = intl.DateFormat.d(name);
    final weekdayFormat = intl.DateFormat.E(name);
    final mediumDateFormat = intl.DateFormat.MMMEd(name);
    final singleDigitHourFormat = intl.DateFormat('HH', name);
    final singleDigitMinuteFormat = intl.DateFormat.m(name);
    final doubleDigitMinuteFormat = intl.DateFormat('mm', name);
    final singleDigitSecondFormat = intl.DateFormat.s(name);
    final decimalFormat = intl.NumberFormat.decimalPattern(name);
    return SynchronousFuture<CupertinoLocalizations>(
      name == 'am'
          ? CupertinoLocalizationAm(
              fullYearFormat: fullYearFormat,
              dayFormat: dayFormat,
              weekdayFormat: weekdayFormat,
              mediumDateFormat: mediumDateFormat,
              singleDigitHourFormat: singleDigitHourFormat,
              singleDigitMinuteFormat: singleDigitMinuteFormat,
              doubleDigitMinuteFormat: doubleDigitMinuteFormat,
              singleDigitSecondFormat: singleDigitSecondFormat,
              decimalFormat: decimalFormat,
            )
          : CupertinoLocalizationEn(
              fullYearFormat: fullYearFormat,
              dayFormat: dayFormat,
              weekdayFormat: weekdayFormat,
              mediumDateFormat: mediumDateFormat,
              singleDigitHourFormat: singleDigitHourFormat,
              singleDigitMinuteFormat: singleDigitMinuteFormat,
              doubleDigitMinuteFormat: doubleDigitMinuteFormat,
              singleDigitSecondFormat: singleDigitSecondFormat,
              decimalFormat: decimalFormat,
            ),
    );
  }

  @override
  bool shouldReload(_CupertinoTexts old) => false;
}

class _WidgetsTexts extends LocalizationsDelegate<WidgetsLocalizations> {
  const _WidgetsTexts();

  @override
  bool isSupported(Locale locale) => _isAppLanguage(locale);

  @override
  Future<WidgetsLocalizations> load(Locale locale) => SynchronousFuture<WidgetsLocalizations>(
    locale.languageCode == 'am' ? const WidgetsLocalizationAm() : const WidgetsLocalizationEn(),
  );

  @override
  bool shouldReload(_WidgetsTexts old) => false;
}
