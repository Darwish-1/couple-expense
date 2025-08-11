// lib/utils/date_utils_ext.dart
import 'package:intl/intl.dart';

DateTime? tryParseAnyDate(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  // quick-and-dirty parser; extend as you like
  final tryFormats = [
    'yyyy-MM-dd',
    'dd/MM/yyyy',
    'MM/dd/yyyy',
    'd MMM yyyy',
    'MMM d, yyyy',
  ];
  for (final f in tryFormats) {
    try {
      return DateFormat(f).parseStrict(s);
    } catch (_) {}
  }
  return null;
}

int monthFromString(String monthName) {
  final months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];
  final idx = months.indexWhere((m) => m.toLowerCase() == monthName.toLowerCase());
  return idx >= 0 ? idx + 1 : DateTime.now().month;
}

String getMonthName(int month) => DateFormat('MMMM').format(DateTime(2000, month, 1));
