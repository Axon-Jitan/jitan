import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';

import '../l10n/admin_text_keys.dart';

/// The short name of an ISO weekday (1 = Monday … 7 = Sunday).
String dayShortName(Translations t, int weekday) => t.t(_dayKeys[weekday - 1]);

const _dayKeys = [
  AdminTextKeys.scheduleDayShort1,
  AdminTextKeys.scheduleDayShort2,
  AdminTextKeys.scheduleDayShort3,
  AdminTextKeys.scheduleDayShort4,
  AdminTextKeys.scheduleDayShort5,
  AdminTextKeys.scheduleDayShort6,
  AdminTextKeys.scheduleDayShort7,
];

/// "Up · 15 min", "Down · 15 min" or "No rounding".
String roundingText(Translations t, ScheduleRounding? rounding) => switch (rounding) {
  null => t.t(AdminTextKeys.scheduleRoundingNone),
  ScheduleRounding(roundUp: true, :final intervalMinutes) =>
    t.t(AdminTextKeys.scheduleRoundingUp, args: {'minutes': intervalMinutes}),
  ScheduleRounding(:final intervalMinutes) => t.t(AdminTextKeys.scheduleRoundingDown, args: {'minutes': intervalMinutes}),
};

/// "Mon–Fri 08:00–16:30 · ±5 min · start Up · 15 min, finish Down · 15 min".
/// Days with the same hours are joined; consecutive days become a range.
String workHoursSummary(Translations t, ScheduleVariant variant) {
  final days = variant.workDays.where((d) => d.start != null && d.finish != null).toList();
  if (days.isEmpty) return t.t(CommonTextKeys.valueUnavailable);
  final hours = [
    for (final (weekdays, (start, finish)) in _runs(t, [for (final d in days) (d.day.weekday, (d.start!.time, d.finish!.time))]))
      t.t(AdminTextKeys.scheduleSummaryHours, args: {'days': weekdays, 'start': start, 'finish': finish}),
  ].join(', ');
  final first = days.first;
  final arrival = first.start!.toleranceMinutes;
  final leaving = first.finish!.toleranceMinutes;
  final tolerance = arrival == leaving
      ? t.t(AdminTextKeys.scheduleSummaryTolerance, args: {'minutes': arrival})
      : t.t(AdminTextKeys.scheduleSummaryToleranceSplit, args: {'arrival': arrival, 'leaving': leaving});
  final rounding = t.t(
    AdminTextKeys.scheduleSummaryRounding,
    args: {'start': roundingText(t, first.start!.rounding), 'finish': roundingText(t, first.finish!.rounding)},
  );
  return '$hours · $tolerance · $rounding';
}

/// "Mon–Fri · 12:00 · 30 min".
String breaksSummary(Translations t, ScheduleVariant variant) {
  if (variant.breaks.isEmpty) return t.t(CommonTextKeys.valueUnavailable);
  return [
    for (final (weekdays, (start, minutes)) in _runs(t, [for (final b in variant.breaks) (b.day.weekday, (b.usualStart, b.lengthMinutes))]))
      t.t(AdminTextKeys.scheduleSummaryBreak, args: {'days': weekdays, 'start': start, 'minutes': minutes}),
  ].join(', ');
}

/// Groups days with an equal [V], in weekday order, and names each group:
/// "Mon–Fri" for consecutive days, "Mon, Wed" otherwise.
List<(String, V)> _runs<V>(Translations t, List<(int, V)> days) {
  final byValue = <V, List<int>>{};
  for (final (weekday, value) in [...days]..sort((a, b) => a.$1.compareTo(b.$1))) {
    (byValue[value] ??= []).add(weekday);
  }
  return [for (final MapEntry(key: value, value: weekdays) in byValue.entries) (_dayList(t, weekdays), value)];
}

String _dayList(Translations t, List<int> weekdays) {
  final parts = <String>[];
  var start = 0;
  for (var i = 1; i <= weekdays.length; i++) {
    if (i < weekdays.length && weekdays[i] == weekdays[i - 1] + 1) continue;
    final first = weekdays[start], last = weekdays[i - 1];
    parts.add(
      first == last
          ? dayShortName(t, first)
          : last == first + 1
          ? '${dayShortName(t, first)}, ${dayShortName(t, last)}'
          : t.t(AdminTextKeys.scheduleSummaryDayRange, args: {'first': dayShortName(t, first), 'last': dayShortName(t, last)}),
    );
    start = i;
  }
  return parts.join(', ');
}
