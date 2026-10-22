import 'package:flutter/widgets.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import '../schedules/schedule_summary_text.dart';
import 'time_records_controller.dart';

/// The words and colours of Time records that depend on data.
abstract final class TimeRecordText {
  static String status(BuildContext context, TimeRecordStatus status) => context.t(switch (status) {
    TimeRecordStatus.complete => AdminTextKeys.timeRecordsStatusComplete,
    TimeRecordStatus.working => AdminTextKeys.timeRecordsStatusWorking,
    TimeRecordStatus.missingFinish => AdminTextKeys.timeRecordsStatusMissingFinish,
    TimeRecordStatus.missingStart => AdminTextKeys.timeRecordsStatusMissingStart,
  });

  /// Complete in success green, problems in warning orange, Working neutral.
  static Color statusColor(TimeRecordStatus status) => switch (status) {
    TimeRecordStatus.complete => JitanColors.success,
    TimeRecordStatus.working => JitanColors.inkMuted,
    TimeRecordStatus.missingFinish || TimeRecordStatus.missingStart => JitanColors.warning,
  };

  static String method(BuildContext context, TimeRecordMethod method) => context.t(switch (method) {
    TimeRecordMethod.geofence => AdminTextKeys.timeRecordsMethodGeofence,
    TimeRecordMethod.qr => AdminTextKeys.timeRecordsMethodQr,
    TimeRecordMethod.manual => AdminTextKeys.timeRecordsMethodManual,
  });

  static String period(BuildContext context, TimeRecordPeriod period) => context.t(switch (period) {
    TimeRecordPeriod.thisWeek => AdminTextKeys.timeRecordsPeriodThisWeek,
    TimeRecordPeriod.lastWeek => AdminTextKeys.timeRecordsPeriodLastWeek,
    TimeRecordPeriod.thisMonth => AdminTextKeys.timeRecordsPeriodThisMonth,
    TimeRecordPeriod.lastMonth => AdminTextKeys.timeRecordsPeriodLastMonth,
  });

  /// "08:00–16:30", "08:00–—" (no finish), "—–16:30" (no start).
  static String range(String? start, String? finish) => '${start ?? '—'}–${finish ?? '—'}';

  static String name(TimeRecordDay day) {
    final name = [day.firstName, day.lastName].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    return name.isEmpty ? day.employeeCode : name;
  }

  /// "Tue 6 Oct" (the table's Date column).
  static String shortDate(BuildContext context, DateTime date) => context.t(
    AdminTextKeys.dateShort,
    args: {
      'weekday': dayShortName(TranslationScope.of(context), date.weekday),
      'day': date.day,
      'month': context.t(AdminTextKeys.monthShort[date.month - 1]),
    },
  );

  /// "Tuesday, 6 October 2026" (the day detail).
  static String longDate(BuildContext context, DateTime date) => context.t(
    AdminTextKeys.dateLong,
    args: {
      'weekday': context.t(AdminTextKeys.weekdayLong[date.weekday - 1]),
      'day': date.day,
      'month': context.t(AdminTextKeys.monthLong[date.month - 1]),
      'year': date.year,
    },
  );
}
