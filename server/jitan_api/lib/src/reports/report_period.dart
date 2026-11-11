import 'package:jitan_models/jitan_models.dart';

import '../http/api_exception.dart';

/// A report's period: `from` and `to` as workplace dates, both included, as
/// the Dashboard takes them.
abstract final class ReportPeriod {
  static final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// 400 for a missing, malformed, reversed or too long period.
  static ({DateTime first, DateTime last}) parse(String? from, String? to) {
    final first = date(from, 'from');
    final last = date(to, 'to');
    if (last.isBefore(first)) throw const ApiException.validation('to', 'The period ends before it starts.');
    if (last.difference(first).inDays + 1 > Dashboard.maxDays) {
      throw const ApiException.validation('to', 'A period can be at most ${Dashboard.maxDays} days.');
    }
    return (first: first, last: last);
  }

  /// `yyyy-MM-dd` as a UTC date; 400 on [field] otherwise.
  static DateTime date(String? value, String field) {
    final parsed = value != null && _date.hasMatch(value) ? DateTime.tryParse(value) : null;
    // DateTime.parse rolls 2026-02-31 over; a real date reads back the same.
    if (parsed == null || TimeRecordDay.dateText(parsed) != value) {
      throw ApiException.validation(field, 'Give "$field" as a date, e.g. 2026-10-22.');
    }
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }
}
