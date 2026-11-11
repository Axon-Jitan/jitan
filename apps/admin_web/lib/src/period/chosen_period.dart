import 'package:jitan_models/jitan_models.dart';

import '../l10n/admin_text_keys.dart';

/// The picker's shortcuts, in Figma's order (`1475:16`).
enum DashboardPreset {
  today(AdminTextKeys.periodToday),
  yesterday(AdminTextKeys.periodYesterday),
  last7Days(AdminTextKeys.periodLast7Days),
  last30Days(AdminTextKeys.periodLast30Days),
  thisMonth(AdminTextKeys.periodThisMonth),
  lastMonth(AdminTextKeys.periodLastMonth),
  thisYear(AdminTextKeys.periodThisYear),
  custom(AdminTextKeys.periodCustom);

  const DashboardPreset(this.labelKey);

  final String labelKey;
}

/// The chosen days, both included, as local dates.
class DashboardPeriod {
  const DashboardPeriod(this.preset, this.from, this.to);

  /// [preset] as of [today]; `custom` keeps the last seven days as a start.
  factory DashboardPeriod.of(DashboardPreset preset, DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    DateTime back(int days) => DateTime(day.year, day.month, day.day - days);
    return switch (preset) {
      DashboardPreset.today => DashboardPeriod(preset, day, day),
      DashboardPreset.yesterday => DashboardPeriod(preset, back(1), back(1)),
      DashboardPreset.last30Days => DashboardPeriod(preset, back(29), day),
      DashboardPreset.thisMonth => DashboardPeriod(preset, DateTime(day.year, day.month), day),
      DashboardPreset.lastMonth => DashboardPeriod(preset, DateTime(day.year, day.month - 1), DateTime(day.year, day.month, 0)),
      DashboardPreset.thisYear => DashboardPeriod(preset, DateTime(day.year), day),
      DashboardPreset.last7Days || DashboardPreset.custom => DashboardPeriod(preset, back(6), day),
    };
  }

  /// What [encode] wrote, as of [today]; the default when there is nothing
  /// usable. A shortcut stays a shortcut, so "Last 7 days" keeps moving on.
  factory DashboardPeriod.decode(String? value, DateTime today) {
    final fallback = DashboardPeriod.of(DashboardPreset.last7Days, today);
    if (value == null) return fallback;
    final parts = value.split(':');
    if (parts case [final from, final to]) {
      final first = DateTime.tryParse(from), last = DateTime.tryParse(to);
      if (first == null || last == null) return fallback;
      final period = DashboardPeriod(DashboardPreset.custom, first, last);
      return period.isValid(today) ? period : fallback;
    }
    for (final preset in DashboardPreset.values) {
      if (preset.name == value && preset != DashboardPreset.custom) return DashboardPeriod.of(preset, today);
    }
    return fallback;
  }

  final DashboardPreset preset;
  final DateTime from;
  final DateTime to;

  /// Not reversed, no future days, and not longer than the server takes.
  bool isValid(DateTime today) =>
      !to.isBefore(from) &&
      !to.isAfter(DateTime(today.year, today.month, today.day)) &&
      DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays < Dashboard.maxDays;

  String encode() =>
      preset == DashboardPreset.custom ? '${TimeRecordDay.dateText(from)}:${TimeRecordDay.dateText(to)}' : preset.name;
}
