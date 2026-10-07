import 'package:jitan_core/jitan_core.dart';

/// "Today", "Yesterday", "3 days ago", "1 week ago", … by calendar day.
///
/// Compares calendar dates, not 24-hour periods: something from 23:50
/// yesterday is "Yesterday" at 00:10 today. A [moment] in the future (clock
/// skew) counts as today.
String relativeDateText(Translations t, DateTime moment, {required DateTime now}) {
  final days = _calendarDaysBetween(moment, now);
  if (days <= 0) return t.t(CommonTextKeys.dateToday);
  if (days == 1) return t.t(CommonTextKeys.dateYesterday);
  if (days < _daysPerWeek) return t.plural(CommonTextKeys.dateDaysAgo, days);
  if (days < _daysPerMonth) return t.plural(CommonTextKeys.dateWeeksAgo, days ~/ _daysPerWeek);
  if (days < _daysPerYear) return t.plural(CommonTextKeys.dateMonthsAgo, days ~/ _daysPerMonth);
  return t.plural(CommonTextKeys.dateYearsAgo, days ~/ _daysPerYear);
}

const _daysPerWeek = 7;
const _daysPerMonth = 30;
const _daysPerYear = 365;

int _calendarDaysBetween(DateTime from, DateTime to) {
  // UTC dates avoid daylight-saving days being 23 or 25 hours long.
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}
