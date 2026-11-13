import 'package:flutter/widgets.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';

/// The words of Period that depend on data: dates, durations, statuses and
/// timeline lines. Month and weekday names are the shared, translated ones.
abstract final class PeriodText {
  static String _month(BuildContext context, DateTime d) => context.t(CommonTextKeys.monthLong[d.month - 1]);

  /// "Friday 2 October".
  static String dayMonth(BuildContext context, DateTime d) =>
      '${context.t(CommonTextKeys.weekdayLong[d.weekday - 1])} ${d.day} ${_month(context, d)}';

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
      : context.t(EmployeeTextKeys.todayDuration, args: {'hours': minutes ~/ 60, 'minutes': (minutes % 60).toString().padLeft(2, '0')});

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
    // Only HR's Time records has it; the employee's own days never do.
    TimeRecordStatus.notStarted => EmployeeTextKeys.periodStatusNoRegistration,
  });

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

  /// "8h 00m": hours and minutes, always both, so the list lines up.
  static String duration(BuildContext context, int minutes) =>
      context.t(EmployeeTextKeys.todayDuration, args: {'hours': minutes ~/ 60, 'minutes': (minutes % 60).toString().padLeft(2, '0')});

  /// A day's value in the week list: its registered time, or what it needs
  /// ("Finish missing"), or its state ("Working").
  static String dayValue(BuildContext context, MyPeriodDay d) {
    final record = d.day?.status;
    if (d.needsAttention && record != null) return status(context, record);
    if (d.registeredMinutes case final minutes?) return duration(context, minutes);
    if (record != null) return status(context, record);
    return context.t(EmployeeTextKeys.periodNotCounted);
  }

  /// The line under a day's date: its times, or what it needs (amber).
  static (String, bool needsYou) dayLine(BuildContext context, MyPeriodDay d) {
    final record = d.day;
    if (record == null) {
      return (context.t(d.plannedMinutes == null ? EmployeeTextKeys.periodNothing : EmployeeTextKeys.periodSubNoRegistration), false);
    }
    String key(String k) => context.t(k);
    return switch (record.status) {
      TimeRecordStatus.missingFinish => (key(EmployeeTextKeys.periodSubMissingFinish), true),
      TimeRecordStatus.missingStart => (key(EmployeeTextKeys.periodSubMissingStart), true),
      TimeRecordStatus.noRegistration || TimeRecordStatus.notStarted => (key(EmployeeTextKeys.periodSubNoRegistration), true),
      TimeRecordStatus.pendingReview => (key(EmployeeTextKeys.periodSubWaiting), true),
      TimeRecordStatus.nonWork => (key(EmployeeTextKeys.periodSubNonWork), false),
      TimeRecordStatus.working => (key(EmployeeTextKeys.periodSubWorking), false),
      TimeRecordStatus.complete || TimeRecordStatus.corrected => (
        '${record.start?.roundedLocal ?? record.start?.actualLocal ?? '--:--'} – '
            '${record.finish?.roundedLocal ?? record.finish?.actualLocal ?? '--:--'}',
        false,
      ),
    };
  }

  /// The line under a day's total: the plan and its break, or how time
  /// away replaced the break (D34), or why it doesn't count yet.
  static String? totalLine(BuildContext context, MyPeriodDay d) {
    final record = d.day;
    if (d.registeredMinutes == null) {
      if (record == null) return null;
      if (record.pending.isNotEmpty) return context.t(EmployeeTextKeys.periodCountsAfterHr);
      if (record.status == TimeRecordStatus.working) {
        return context.t(
          EmployeeTextKeys.periodWorkingSince,
          args: {'time': record.start?.roundedLocal ?? record.start?.actualLocal ?? '--:--'},
        );
      }
      if (record.status == TimeRecordStatus.missingFinish && record.start != null && d.scheduledFinish != null) {
        return context.t(
          EmployeeTextKeys.periodStartedLine,
          args: {'start': record.start!.roundedLocal ?? record.start!.actualLocal, 'finish': d.scheduledFinish!},
        );
      }
      if (d.scheduledStart != null && d.scheduledFinish != null) {
        return context.t(EmployeeTextKeys.periodDayPlanned, args: {'range': '${d.scheduledStart} – ${d.scheduledFinish}'});
      }
      return null;
    }
    final planned = d.plannedMinutes;
    if (planned == null) return null;
    final breakMinutes = d.breakMinutes ?? 0;
    final total = duration(context, planned);
    if (record != null && record.awayMinutes > 0 && breakMinutes > 0) {
      return context.t(EmployeeTextKeys.periodAwayLine, args: {'total': total, 'away': record.awayMinutes, 'minutes': breakMinutes});
    }
    if (breakMinutes > 0) return context.t(EmployeeTextKeys.periodPlannedLine, args: {'total': total, 'minutes': breakMinutes});
    return context.t(EmployeeTextKeys.periodWeekPlanned, args: {'hours': total});
  }
}
