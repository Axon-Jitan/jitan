import 'package:flutter/widgets.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'time_record_status_filter.dart';
import 'time_records_controller.dart';

/// The words and colours of Time records that depend on data.
abstract final class TimeRecordText {
  static String status(BuildContext context, TimeRecordStatus status) => context.t(switch (status) {
    TimeRecordStatus.complete => AdminTextKeys.timeRecordsStatusComplete,
    TimeRecordStatus.corrected => AdminTextKeys.timeRecordsStatusCorrected,
    TimeRecordStatus.pendingReview => AdminTextKeys.timeRecordsStatusPendingReview,
    TimeRecordStatus.nonWork => AdminTextKeys.timeRecordsStatusNonWork,
    TimeRecordStatus.noRegistration => AdminTextKeys.timeRecordsStatusNoRegistration,
    TimeRecordStatus.notStarted => AdminTextKeys.timeRecordsStatusNotStarted,
    TimeRecordStatus.working => AdminTextKeys.timeRecordsStatusWorking,
    TimeRecordStatus.missingFinish => AdminTextKeys.timeRecordsStatusMissingFinish,
    TimeRecordStatus.missingStart => AdminTextKeys.timeRecordsStatusMissingStart,
  });

  /// As Figma `1565:2`: Registered green, Corrected blue, every day HR
  /// must fix or review amber; Working, Non-work and Not started neutral.
  static Color statusColor(TimeRecordStatus status) => switch (status) {
    TimeRecordStatus.complete => JitanColors.success,
    TimeRecordStatus.corrected => JitanColors.info,
    TimeRecordStatus.missingFinish ||
    TimeRecordStatus.missingStart ||
    TimeRecordStatus.pendingReview ||
    TimeRecordStatus.noRegistration => JitanColors.warning,
    TimeRecordStatus.working || TimeRecordStatus.nonWork || TimeRecordStatus.notStarted => JitanColors.inkMuted,
  };

  static String method(BuildContext context, TimeRecordMethod method) => context.t(switch (method) {
    TimeRecordMethod.geofence => AdminTextKeys.timeRecordsMethodGeofence,
    TimeRecordMethod.qr => AdminTextKeys.timeRecordsMethodQr,
    TimeRecordMethod.manual => AdminTextKeys.timeRecordsMethodManual,
  });

  static String boundary(BuildContext context, RegistrationBoundary boundary) => context.t(switch (boundary) {
    RegistrationBoundary.start => AdminTextKeys.timeRecordBoundaryStart,
    RegistrationBoundary.finish => AdminTextKeys.timeRecordBoundaryFinish,
  });

  /// One line of the detailed registration timeline.
  static String event(BuildContext context, TimeRecordEvent event) {
    final args = {
      'boundary': boundary(context, event.boundary),
      'method': event.method == null ? '' : method(context, event.method!),
    };
    return context.t(switch (event.kind) {
      TimeRecordEventKind.registered => AdminTextKeys.timeRecordEventRegistered,
      TimeRecordEventKind.correctionRequested => AdminTextKeys.timeRecordEventRequested,
      TimeRecordEventKind.corrected => AdminTextKeys.timeRecordEventCorrected,
      TimeRecordEventKind.rejected => AdminTextKeys.timeRecordEventRejected,
      TimeRecordEventKind.nonWork => AdminTextKeys.timeRecordEventNonWork,
    }, args: args);
  }

  static String period(BuildContext context, TimeRecordPeriod period) => context.t(switch (period) {
    TimeRecordPeriod.thisWeek => AdminTextKeys.timeRecordsPeriodThisWeek,
    TimeRecordPeriod.lastWeek => AdminTextKeys.timeRecordsPeriodLastWeek,
    TimeRecordPeriod.thisMonth => AdminTextKeys.timeRecordsPeriodThisMonth,
    TimeRecordPeriod.lastMonth => AdminTextKeys.timeRecordsPeriodLastMonth,
  });

  /// "08:45 – 16:45"; a day still open "08:45 – …", a missing time "—",
  /// nothing at all "—".
  static String range(String? start, String? finish, {bool open = false}) {
    if (start == null && finish == null) return '—';
    return '${start ?? '—'} – ${finish ?? (open ? '…' : '—')}';
  }

  static String name(TimeRecordDay day) {
    final name = [day.firstName, day.lastName].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    return name.isEmpty ? day.employeeCode : name;
  }

  /// "Thursday 12 November" (the pop-ups, today's and yesterday's heading).
  static String dayDate(BuildContext context, DateTime date) => context.t(
    AdminTextKeys.timeRecordsDayDate,
    args: {
      'weekday': context.t(AdminTextKeys.weekdayLong[date.weekday - 1]),
      'day': date.day,
      'month': context.t(AdminTextKeys.monthLong[date.month - 1]),
    },
  );

  /// A day's heading in the list (Figma `1565:2`): "Today" and "Thursday 12
  /// November", "Yesterday" and its date, else "Tuesday" and "10 November".
  static (String, String) dayHeading(BuildContext context, DateTime date, DateTime today) {
    final ago = DateTime.utc(today.year, today.month, today.day).difference(DateTime.utc(date.year, date.month, date.day)).inDays;
    return switch (ago) {
      0 => (context.t(AdminTextKeys.timeRecordsDayToday), dayDate(context, date)),
      1 => (context.t(AdminTextKeys.timeRecordsDayYesterday), dayDate(context, date)),
      _ => (
        context.t(AdminTextKeys.weekdayLong[date.weekday - 1]),
        context.t(AdminTextKeys.timeRecordsDayMonth, args: {'day': date.day, 'month': context.t(AdminTextKeys.monthLong[date.month - 1])}),
      ),
    };
  }

  /// A day's summary at the right of its heading: "5 to review", "2 working ·
  /// 29 not started", "31 finished · 6 late". Counts of what the server said.
  static String daySummary(BuildContext context, List<TimeRecordDay> days) {
    int count(bool Function(TimeRecordDay) test) => days.where(test).length;
    return [
      for (final (key, n) in [
        (AdminTextKeys.timeRecordsSummaryToReview, count(TimeRecordStatusFilter.toReview.lets)),
        (AdminTextKeys.timeRecordsSummaryWorking, count((d) => d.status == TimeRecordStatus.working)),
        (AdminTextKeys.timeRecordsSummaryNotStarted, count((d) => d.status == TimeRecordStatus.notStarted)),
        (AdminTextKeys.timeRecordsSummaryFinished, count(TimeRecordStatusFilter.finished.lets)),
        (AdminTextKeys.timeRecordsSummaryLate, count((d) => d.attendance == DayAttendance.late)),
      ])
        if (n > 0) context.t(key, args: {'n': n}),
    ].join(' · ');
  }

  /// "Registered · Late": the status, and Late or Left early when it was.
  static String statusLine(BuildContext context, TimeRecordDay day) => [
    status(context, day.status),
    if (day.attendance case final a? when a != DayAttendance.onTime)
      context.t(a == DayAttendance.late ? AdminTextKeys.timeRecordsAttendanceLate : AdminTextKeys.timeRecordsAttendanceLeftEarly),
  ].join(' · ');
}
