// lib/utils/date_utils_ext.dart
import 'package:intl/intl.dart';

/// Try parse a date string using a few common formats.
/// Returns null if not parseable.
DateTime? tryParseAnyDate(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final tryFormats = <String>[
    'yyyy-MM-dd',
    'dd/MM/yyyy',
    'MM/dd/yyyy',
    'd MMM yyyy',
    'MMM d, yyyy',
    "yyyy-MM-dd'T'HH:mm:ss'Z'",
    "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
  ];
  for (final f in tryFormats) {
    try {
      return DateFormat(f).parseStrict(s);
    } catch (_) {}
  }
  return null;
}

/// Month number (1..12) from an English month name.
int monthFromString(String monthName) {
  final months = const [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];
  final idx = months.indexWhere((m) => m.toLowerCase() == monthName.toLowerCase());
  return idx >= 0 ? idx + 1 : DateTime.now().month;
}

/// Month full name from 1..12 (locale-aware).
String getMonthName(int month) => DateFormat('MMMM').format(DateTime(2000, month, 1));

/// Month short name from 1..12 (locale-aware).
String getMonthShort(int month) => DateFormat('MMM').format(DateTime(2000, month, 1));

/// Label like "August 2025".
String monthLabel(int year, int month) => DateFormat('MMMM yyyy').format(DateTime(year, month, 1));

/// Key like "2025-08"
String monthKeyOf(int year, int month) => DateFormat('yyyy-MM').format(DateTime(year, month, 1));

/// Number of days in a month.
int daysInMonth(int year, int month) {
  final beginningNextMonth = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
  return beginningNextMonth.subtract(const Duration(days: 1)).day;
}

/// Clamp helper
int _clamp(int v, int min, int max) => v < min ? min : (v > max ? max : v);

/// Given a label (year, month) and an anchor day-of-month, return the inclusive start of the budget period.
/// Example: year=2025, month=8, anchorDay=7  => 2025-08-07 00:00
DateTime startOfBudgetPeriod(int year, int month, int anchorDay) {
  final d = _clamp(anchorDay, 1, daysInMonth(year, month));
  return DateTime(year, month, d); // local midnight
}

/// Returns the exclusive end (== next period start) for Firestore range queries.
/// Example: year=2025, month=8, anchorDay=7  => 2025-09-07 00:00
DateTime nextStartOfBudgetPeriod(int year, int month, int anchorDay) {
  final nextYear = (month == 12) ? year + 1 : year;
  final nextMonth = (month == 12) ? 1 : month + 1;
  final d = _clamp(anchorDay, 1, daysInMonth(nextYear, nextMonth));
  return DateTime(nextYear, nextMonth, d);
}
