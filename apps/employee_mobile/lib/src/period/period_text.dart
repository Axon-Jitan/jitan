import 'package:flutter/widgets.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';

/// The words of Period that depend on data: dates, durations, statuses and
/// timeline lines. Month and weekday names are the shared, translated ones.
abstract final class PeriodText {
  static String _month(BuildContext context, DateTime d) => context.t(CommonTextKeys.monthLong[d.month - 1]);

  /// "Friday, 2 October".
  static String dayMonth(BuildContext context, DateTime d) =>
      '${context.t(CommonTextKeys.weekdayLong[d.weekday - 1])}, ${d.day} ${_month(context, d)}';

  /// "Tuesday, 6 October 2026".
  static String fullDate(BuildContext context, DateTime d) => '${dayMonth(context, d)} ${d.year}';

  /// "5–11 October 2026", or "28 September – 4 October 2026" across months.
  static String range(BuildContext context, DateTime from, DateTime to) => from.month == to.month
      ? '${from.day}–${to.day} ${_month(context, to)} ${to.year}'
      : '${from.day} ${_month(context, from)} – ${to.day} ${_month(context, to)} ${to.year}';

  /// "October 2026".
  static String month(BuildContext context, DateTime d) => '${_month(context, d)} ${d.year}';

  /// "Mon 5".
  static String shortDay(BuildContext context, DateTime d) => '${context.t(CommonTextKeys.weekdayShort[d.weekday - 1])} ${d.day}';

  /// "8h" or "8h 30m".
  static String hours(BuildContext context, int minutes) => minutes % 60 == 0
      ? context.t(EmployeeTextKeys.periodHours, args: {'hours': minutes ~/ 60})
      : context.t(
          EmployeeTextKeys.todayDuration,
          args: {'hours': minutes ~/ 60, 'minutes': (minutes % 60).toString().padLeft(2, '0')},
        );

  /// The day's badge ("COMPLETE", "WAITING FOR HR", …).
  static String status(BuildContext context, TimeRecordStatus status) => context.t(switch (status) {
    TimeRecordStatus.complete => EmployeeTextKeys.periodStatusComplete,
    TimeRecordStatus.corrected => EmployeeTextKeys.periodStatusCorrected,
    TimeRecordStatus.pendingReview => EmployeeTextKeys.periodStatusWaiting,
    TimeRecordStatus.working => EmployeeTextKeys.periodStatusWorking,
    TimeRecordStatus.missingFinish => EmployeeTextKeys.periodStatusMissingFinish,
    TimeRecordStatus.missingStart => EmployeeTextKeys.periodStatusMissingStart,
    TimeRecordStatus.noRegistration => EmployeeTextKeys.periodStatusNoRegistration,
    TimeRecordStatus.nonWork => EmployeeTextKeys.periodStatusNonWork,
  });

  /// Orange for what the employee should act on or wait for.
  static Color statusColor(TimeRecordStatus status) => switch (status) {
    TimeRecordStatus.missingFinish ||
    TimeRecordStatus.missingStart ||
    TimeRecordStatus.noRegistration ||
    TimeRecordStatus.pendingReview => JitanColors.warning,
    _ => JitanColors.ink,
  };

  /// A timeline line's title.
  static String eventTitle(BuildContext context, TimeRecordEvent e) {
    final start = e.boundary == RegistrationBoundary.start;
    return context.t(switch (e.kind) {
      TimeRecordEventKind.registered => start ? EmployeeTextKeys.periodEventStart : EmployeeTextKeys.periodEventFinish,
      TimeRecordEventKind.correctionRequested =>
        start ? EmployeeTextKeys.periodEventStartRequested : EmployeeTextKeys.periodEventFinishRequested,
      TimeRecordEventKind.corrected => EmployeeTextKeys.periodEventCorrected,
      TimeRecordEventKind.rejected => EmployeeTextKeys.periodEventRejected,
      TimeRecordEventKind.nonWork => EmployeeTextKeys.periodEventNonWork,
    });
  }

  /// A timeline line's detail: how it was registered, or that it waits.
  /// [waiting]: the boundaries with a correction still waiting for HR (the
  /// request row stays in the timeline after approval, as history).
  static String? eventDetail(BuildContext context, TimeRecordEvent e, Set<RegistrationBoundary> waiting) => switch (e.kind) {
    TimeRecordEventKind.correctionRequested when e.active && waiting.contains(e.boundary) =>
      context.t(EmployeeTextKeys.periodEventWaiting),
    TimeRecordEventKind.registered => context.t(switch (e.method) {
      TimeRecordMethod.qr => EmployeeTextKeys.periodEventQr,
      TimeRecordMethod.geofence => EmployeeTextKeys.periodEventAutomatic,
      _ => EmployeeTextKeys.periodEventApp,
    }),
    _ => null,
  };

  /// The dot colour of a timeline line.
  static Color eventColor(TimeRecordEvent e) => switch (e.kind) {
    TimeRecordEventKind.correctionRequested => JitanColors.warning,
    TimeRecordEventKind.corrected => JitanColors.info,
    TimeRecordEventKind.rejected || TimeRecordEventKind.nonWork => JitanColors.inkMuted,
    TimeRecordEventKind.registered => e.boundary == RegistrationBoundary.start ? JitanColors.vermilion : JitanColors.success,
  };
}
