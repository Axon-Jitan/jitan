import '../l10n/admin_strings.dart';

/// "Today", "Yesterday", "3 days ago", "1 week ago", … by calendar day.
///
/// Compares calendar dates, not 24-hour periods: something from 23:50
/// yesterday is "Yesterday" at 00:10 today. A [moment] in the future (clock
/// skew) counts as today.
String relativeDateText(DateTime moment, {required DateTime now}) {
  final days = _calendarDaysBetween(moment, now);
  if (days <= 0) return AdminStrings.today;
  if (days == 1) return AdminStrings.yesterday;
  if (days < _daysPerWeek) return AdminStrings.daysAgo(days);
  if (days < _daysPerMonth) return AdminStrings.weeksAgo(days ~/ _daysPerWeek);
  if (days < _daysPerYear) return AdminStrings.monthsAgo(days ~/ _daysPerMonth);
  return AdminStrings.yearsAgo(days ~/ _daysPerYear);
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
