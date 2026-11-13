import 'package:flutter/widgets.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../activity/activity_text.dart';
import '../l10n/employee_text_keys.dart';
import '../today/today_text.dart';
import 'home_timeline.dart';

/// The words of Home that depend on the day (Figma `1585:2`).
abstract final class HomeText {
  /// "08:00 – 16:30"; a time that is not there is "--:--".
  static String span(String? start, String? finish) => '${start ?? '--:--'} – ${finish ?? '--:--'}';

  /// "Since 08:00 · Started in the app".
  static String since(BuildContext context, MyDay day) {
    final start = shownTime(day.day, RegistrationBoundary.start);
    final how = start.pending
        ? context.t(EmployeeTextKeys.todayStartWaitsForHr)
        : context.t(switch (day.day?.start?.method ?? TimeRecordMethod.manual) {
            TimeRecordMethod.geofence => EmployeeTextKeys.todayWorkdayStartedAutomatically,
            TimeRecordMethod.qr => EmployeeTextKeys.todayScannedAtTerminal,
            TimeRecordMethod.manual => EmployeeTextKeys.todayWorkdayStartedInApp,
          });
    return context.t(EmployeeTextKeys.todaySince, args: {'time': start.local ?? '--:--', 'how': how});
  }

  /// "Planned finish 16:30 · + 42m travel": travel next to the worked time,
  /// never in it (D46).
  static String? workingLine(BuildContext context, MyDay day, ActivityBreakdown travel) {
    final parts = [
      if (day.scheduledFinish case final finish?) context.t(EmployeeTextKeys.todayPlannedFinish, args: {'time': finish}),
      if (travel.transportMinutes > 0) _travel(context, travel),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _travel(BuildContext context, ActivityBreakdown travel) {
    final time = TodayText.duration(context, travel.transportMinutes);
    return travel.distanceMetres > 0 && travel.tripsWithoutDistance == 0
        ? context.t(EmployeeTextKeys.todayWorkingTravelKm, args: {'time': time, 'km': (travel.distanceMetres / 1000).round()})
        : context.t(EmployeeTextKeys.todayWorkingTravel, args: {'time': time});
  }

  /// "Planned 8h 00m · 30 min break" under a finished day's total. The
  /// planned time is today's schedule as HR set it, shown only.
  static String? plannedLine(BuildContext context, MyDay day) {
    final breakMinutes = day.breakMinutes ?? 0;
    final planned = plannedMinutes(day);
    final parts = [
      if (planned != null) context.t(EmployeeTextKeys.todayPlannedTotal, args: {'time': TodayText.duration(context, planned)}),
      if (breakMinutes > 0) context.t(EmployeeTextKeys.todayBreak, args: {'minutes': breakMinutes}),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Today's planned work time from the schedule, minus the break; `null`
  /// without a schedule. Shown only: the totals are the server's.
  static int? plannedMinutes(MyDay day) => switch ((_minutes(day.scheduledStart), _minutes(day.scheduledFinish))) {
    (final start?, final finish?) when finish > start => finish - start - (day.breakMinutes ?? 0),
    _ => null,
  };

  static int? _minutes(String? hhmm) {
    if (hhmm == null || hhmm.length < 5) return null;
    return int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3, 5));
  }

  /// Started, what the day went on, and Finished once it is done.
  static List<HomeMoment> timeline(BuildContext context, MyDay day, MyActivity activity) {
    final start = shownTime(day.day, RegistrationBoundary.start);
    final finish = shownTime(day.day, RegistrationBoundary.finish);
    return [
      if (start.local case final time?)
        HomeMoment(
          time: time,
          title: context.t(EmployeeTextKeys.todayTimelineStarted),
          detail: _how(context, day.day?.start?.method, pending: start.pending),
          waiting: start.pending,
        ),
      // The first switch is usually the start itself: shown once.
      for (final entry in activity.today)
        if (entry.timeLocal != start.local)
          HomeMoment(time: entry.timeLocal, title: ActivityText.kind(context, entry.kind), detail: _where(context, entry)),
      if (finish.local case final time?)
        HomeMoment(
          time: time,
          title: context.t(EmployeeTextKeys.todayTimelineFinished),
          detail: _how(context, day.day?.finish?.method, pending: finish.pending),
          waiting: finish.pending,
        ),
    ];
  }

  static String _how(BuildContext context, TimeRecordMethod? method, {required bool pending}) {
    if (pending) return context.t(EmployeeTextKeys.todayWaitingForHr);
    return context.t(switch (method ?? TimeRecordMethod.manual) {
      TimeRecordMethod.geofence => EmployeeTextKeys.todayByGeofence,
      TimeRecordMethod.qr => EmployeeTextKeys.todayByTerminal,
      TimeRecordMethod.manual => EmployeeTextKeys.todayByApp,
    });
  }

  static String? _where(BuildContext context, ActivityEntry entry) {
    if (entry.kind == ActivityKind.transport) {
      final metres = entry.metres;
      return metres == null ? null : context.t(EmployeeTextKeys.activityKilometres, args: {'km': (metres / 1000).round()});
    }
    return entry.placeName ?? entry.projectName;
  }
}
