import 'package:intl/intl.dart';

/// Centralized formatting helpers (PHP currency, areas, dates, percentages).
class Fmt {
  const Fmt._();

  static final NumberFormat _peso =
      NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
  static final NumberFormat _pesoCompact =
      NumberFormat.compactCurrency(locale: 'en_PH', symbol: '₱');
  static final NumberFormat _decimal = NumberFormat('#,##0.##', 'en_PH');
  static final NumberFormat _int = NumberFormat('#,##0', 'en_PH');
  static final DateFormat _date = DateFormat('MMM d, yyyy');
  static final DateFormat _dateShort = DateFormat('MMM d');
  static final DateFormat _dateTime = DateFormat('MMM d, yyyy • h:mm a');

  static String peso(num value) => _peso.format(value);

  static String pesoCompact(num value) =>
      value.abs() >= 100000 ? _pesoCompact.format(value) : _peso.format(value);

  static String number(num value) => _decimal.format(value);

  static String integer(num value) => _int.format(value);

  static String percent(num fraction, {int decimals = 1}) =>
      '${(fraction * 100).toStringAsFixed(decimals)}%';

  static String percentValue(num value, {int decimals = 1}) =>
      '${value.toStringAsFixed(decimals)}%';

  static String area(num hectares) => '${_decimal.format(hectares)} ha';

  static String weightKg(num kg) {
    if (kg >= 1000) return '${_decimal.format(kg / 1000)} t';
    return '${_decimal.format(kg)} kg';
  }

  static String tons(num tons) => '${_decimal.format(tons)} t';

  static String date(DateTime? value) =>
      value == null ? '—' : _date.format(value.toLocal());

  static String dateShort(DateTime? value) =>
      value == null ? '—' : _dateShort.format(value.toLocal());

  static String dateTime(DateTime? value) =>
      value == null ? '—' : _dateTime.format(value.toLocal());

  /// Human "in 12 days" / "3 days ago" style relative label.
  static String relativeDays(DateTime? value) {
    if (value == null) return '—';
    final now = DateTime.now();
    final diff = DateTime(value.year, value.month, value.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff > 1) return 'in $diff days';
    return '${diff.abs()} days ago';
  }

  /// ISO week label such as "2026-W26" used to bucket harvest peaks.
  static String isoWeekLabel(DateTime date) {
    final week = isoWeekNumber(date);
    return '${date.year}-W${week.toString().padLeft(2, '0')}';
  }

  /// ISO-8601 week number (1–53).
  static int isoWeekNumber(DateTime date) {
    final dayOfYear = int.parse(DateFormat('D').format(date));
    final woy = ((dayOfYear - date.weekday + 10) / 7).floor();
    if (woy < 1) return isoWeekNumber(DateTime(date.year - 1, 12, 31));
    if (woy > 52) {
      final isLong = _isLongIsoYear(date.year);
      if (!isLong) return 1;
    }
    return woy;
  }

  static bool _isLongIsoYear(int year) {
    int p(int y) => (y + (y ~/ 4) - (y ~/ 100) + (y ~/ 400)) % 7;
    return p(year) == 4 || p(year - 1) == 3;
  }
}
