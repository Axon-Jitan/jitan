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
    TimeRecordStatus.corrected => AdminTextKeys.timeRecordsStatusCorrected,
    TimeRecordStatus.pendingReview => AdminTextKeys.timeRecordsStatusPendingReview,
    TimeRecordStatus.nonWork => AdminTextKeys.timeRecordsStatusNonWork,
    TimeRecordStatus.noRegistration => AdminTextKeys.timeRecordsStatusNoRegistration,
    TimeRecordStatus.working => AdminTextKeys.timeRecordsStatusWorking,
    TimeRecordStatus.missingFinish => AdminTextKeys.timeRecordsStatusMissingFinish,
    TimeRecordStatus.missingStart => AdminTextKeys.timeRecordsStatusMissingStart,
  });

  /// As Figma 160:2: Complete green, Corrected blue, problems and Pending
  /// review orange; Working, Non-work and No registration neutral.
  static Color statusColor(TimeRecordStatus status) => switch (status) {
    TimeRecordStatus.complete => JitanColors.success,
    TimeRecordStatus.corrected => JitanColors.info,
    TimeRecordStatus.missingFinish || TimeRecordStatus.missingStart || TimeRecordStatus.pendingReview => JitanColors.warning,
    TimeRecordStatus.working || TimeRecordStatus.nonWork || TimeRecordStatus.noRegistration => JitanColors.inkMuted,
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
