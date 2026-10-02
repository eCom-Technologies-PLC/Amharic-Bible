/// Gregorian <-> Ethiopian calendar conversion (via Julian Day Number).
///
/// Dates are stored in UTC and converted only for display.
class EthiopianDate {
  const EthiopianDate(this.year, this.month, this.day);

  final int year;
  final int month; // 1..13
  final int day; // 1..30 (1..5/6 in month 13, ጳጉሜን)

  static const _epoch = 1723856; // JDN offset used by the conversion below

  static const monthNamesAm = [
    'መስከረም', 'ጥቅምት', 'ኅዳር', 'ታኅሣሥ', 'ጥር', 'የካቲት', 'መጋቢት',
    'ሚያዝያ', 'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሐሴ', 'ጳጉሜን', //
  ];

  factory EthiopianDate.fromGregorian(DateTime date) {
    final jdn = _gregorianToJdn(date.year, date.month, date.day);
    final r = (jdn - _epoch) % 1461;
    final n = r % 365 + 365 * (r ~/ 1460);
    final year = 4 * ((jdn - _epoch) ~/ 1461) + r ~/ 365 - r ~/ 1460;
    return EthiopianDate(year, n ~/ 30 + 1, n % 30 + 1);
  }

  DateTime toGregorian() {
    final jdn = _epoch + 365 + 365 * (year - 1) + year ~/ 4 + 30 * month + day - 31;
    return _jdnToGregorian(jdn);
  }

  /// e.g. "መስከረም 22, 2019 ዓ.ም."
  String format() => '${monthNamesAm[month - 1]} $day, $year ዓ.ም.';

  @override
  bool operator ==(Object other) =>
      other is EthiopianDate && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'EthiopianDate($year-$month-$day)';
}

int _gregorianToJdn(int year, int month, int day) {
  final a = (14 - month) ~/ 12;
  final y = year + 4800 - a;
  final m = month + 12 * a - 3;
  return day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
}

DateTime _jdnToGregorian(int jdn) {
  final a = jdn + 32044;
  final b = (4 * a + 3) ~/ 146097;
  final c = a - 146097 * b ~/ 4;
  final d = (4 * c + 3) ~/ 1461;
  final e = c - 1461 * d ~/ 4;
  final m = (5 * e + 2) ~/ 153;
  final day = e - (153 * m + 2) ~/ 5 + 1;
  final month = m + 3 - 12 * (m ~/ 10);
  final year = 100 * b + d - 4800 + m ~/ 10;
  return DateTime.utc(year, month, day);
}
