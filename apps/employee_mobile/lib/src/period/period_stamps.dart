import 'package:flutter/widgets.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../activity/activity_text.dart';
import '../l10n/employee_text_keys.dart';
import 'period_text.dart';

/// The dot of a stamp: red start, green finish, a small dark dot for an
/// activity, a hollow ring for a break or time away, amber for what waits
/// for HR, blue for HR's confirmation, grey for the rest.
enum StampDot { start, finish, activity, pause, waiting, confirmed, quiet }

/// One line of a day's timeline (Figma `1595:577`, 2026-11-13).
class PeriodStamp {
  const PeriodStamp({required this.time, required this.dot, required this.title, this.detail, this.detailColor, this.reason});

  /// Workplace-local `HH:mm`.
  final String time;
  final StampDot dot;
  final String title;
  final String? detail;
  final Color? detailColor;

  /// The employee's own words for a correction.
  final String? reason;

  bool get isPause => dot == StampDot.pause;
}

/// What a day's timeline shows, oldest first: the registrations as they
/// happened, what the day went on (activities), and the break.
///
/// Only what Jitan knows (rule §10): the automatic break is shown at the
/// schedule's usual time and says it comes from the schedule (D13, never
/// registered); time away is the gap between a finish and the next start,
/// which replaces the break (D34). The totals stay the server's.
abstract final class PeriodStamps {
  static List<PeriodStamp> of(
    BuildContext context, {
    required TimeRecordDay? day,
    List<ActivityEntry> activities = const [],
    String? breakStart,
    int? breakMinutes,
    String? now,
  }) {
    final events = [...?day?.events]..sort((a, b) => a.atLocal.compareTo(b.atLocal));
    final waiting = {for (final p in day?.pending ?? const <TimeRecordPending>[]) p.boundary};
    final registered = [
      for (final e in events)
        if (e.active && e.kind == TimeRecordEventKind.registered) e,
    ];

    // A finish followed by a start: time away, one line instead of two.
    final gaps = <(TimeRecordEvent, TimeRecordEvent)>[];
    for (var i = 0; i + 1 < registered.length; i++) {
      if (registered[i].boundary == RegistrationBoundary.finish && registered[i + 1].boundary == RegistrationBoundary.start) {
        gaps.add((registered[i], registered[i + 1]));
      }
    }
    final inGap = {
      for (final (a, b) in gaps) ...[a, b],
    };
    final firstStart = registered.where((e) => e.boundary == RegistrationBoundary.start).firstOrNull;
    // The day's start as shown, also when it waits for HR: the first switch
    // at that minute is the start itself, shown once (as on Home).
    final startTime =
        firstStart?.atLocal ??
        events
            .where((e) => e.active && e.kind == TimeRecordEventKind.correctionRequested && e.boundary == RegistrationBoundary.start)
            .firstOrNull
            ?.atLocal;

    final ranked = <(int, PeriodStamp)>[];
    for (final e in events) {
      if (inGap.contains(e)) continue;
      ranked.add(_ofEvent(context, e, waiting));
    }
    for (final (away, back) in gaps) {
      final minutes = _minuteOf(back.atLocal) - _minuteOf(away.atLocal);
      ranked.add((
        1,
        PeriodStamp(
          time: away.atLocal,
          dot: StampDot.pause,
          title: context.t(EmployeeTextKeys.periodTimeAway, args: {'minutes': minutes}),
          detail: context.t(EmployeeTextKeys.periodTimeAwayDetail),
        ),
      ));
    }
    for (final entry in activities) {
      // The first switch is usually the start itself: shown once, as on Home.
      if (entry.timeLocal == startTime) continue;
      ranked.add((
        1,
        PeriodStamp(
          time: entry.timeLocal,
          dot: StampDot.activity,
          title: ActivityText.kind(context, entry.kind),
          detail: _where(context, entry),
        ),
      ));
    }
    // The break counts on a finished day, or today once its time came.
    final minutes = breakMinutes ?? 0;
    final breakAt = breakStart;
    if (gaps.isEmpty &&
        breakAt != null &&
        minutes > 0 &&
        firstStart != null &&
        firstStart.atLocal.compareTo(breakAt) <= 0 &&
        (now == null
            ? registered.any((e) => e.boundary == RegistrationBoundary.finish && e.atLocal.compareTo(breakAt) > 0)
            : now.compareTo(breakAt) >= 0)) {
      ranked.add((
        1,
        PeriodStamp(
          time: breakAt,
          dot: StampDot.pause,
          title: context.t(EmployeeTextKeys.periodBreak, args: {'minutes': minutes}),
          detail: context.t(EmployeeTextKeys.periodBreakDetail),
        ),
      ));
    }
    final ordered = ranked.indexed.toList()
      ..sort((a, b) {
        final byTime = a.$2.$2.time.compareTo(b.$2.$2.time);
        if (byTime != 0) return byTime;
        final byRank = a.$2.$1.compareTo(b.$2.$1);
        return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
      });
    return [for (final (_, (_, stamp)) in ordered) stamp];
  }

  /// A registration or a correction; the rank keeps a start first and a
  /// finish last among lines at the same minute.
  static (int, PeriodStamp) _ofEvent(BuildContext context, TimeRecordEvent e, Set<RegistrationBoundary> waiting) {
    final start = e.boundary == RegistrationBoundary.start;
    final reason = e.reason == null || e.reason!.isEmpty ? null : e.reason;
    switch (e.kind) {
      case TimeRecordEventKind.registered:
        return (
          start ? 0 : 2,
          PeriodStamp(
            time: e.atLocal,
            dot: start ? StampDot.start : StampDot.finish,
            title: context.t(start ? EmployeeTextKeys.todayTimelineStarted : EmployeeTextKeys.todayTimelineFinished),
            detail: context.t(switch (e.method) {
              TimeRecordMethod.geofence => EmployeeTextKeys.todayByGeofence,
              TimeRecordMethod.qr => EmployeeTextKeys.todayByTerminal,
              _ => EmployeeTextKeys.todayByApp,
            }),
          ),
        );
      case TimeRecordEventKind.correctionRequested:
        final pending = e.active && waiting.contains(e.boundary);
        return (
          start ? 0 : 2,
          PeriodStamp(
            time: e.atLocal,
            dot: pending ? StampDot.waiting : StampDot.quiet,
            title: PeriodText.eventTitle(context, e),
            detail: pending ? context.t(EmployeeTextKeys.periodEventWaiting) : null,
            detailColor: pending ? JitanColors.warning : null,
            reason: reason,
          ),
        );
      case TimeRecordEventKind.corrected:
        return (1, PeriodStamp(time: e.atLocal, dot: StampDot.confirmed, title: PeriodText.eventTitle(context, e), reason: reason));
      case TimeRecordEventKind.rejected || TimeRecordEventKind.nonWork:
        return (1, PeriodStamp(time: e.atLocal, dot: StampDot.quiet, title: PeriodText.eventTitle(context, e), reason: reason));
    }
  }

  /// "P-1057 Cooling towers · Engis", or "36 km" for a trip.
  static String? _where(BuildContext context, ActivityEntry entry) {
    if (entry.kind == ActivityKind.transport) {
      final metres = entry.metres;
      return metres == null ? null : context.t(EmployeeTextKeys.activityKilometres, args: {'km': (metres / 1000).round()});
    }
    final project = entry.projectName, place = entry.placeName;
    final parts = [?project, if (place != project) ?place];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static int _minuteOf(String hhmm) => int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3, 5));
}
