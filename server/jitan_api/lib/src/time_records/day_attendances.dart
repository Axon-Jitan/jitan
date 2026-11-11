import 'package:jitan_models/jitan_models.dart';

import '../time_registration/rounding/attendance_calculator.dart';
import '../time_registration/workplace_clock.dart';
import 'week_plans.dart';

/// A finished day against its schedule (D11b), by the actual times and the
/// schedule's tolerances: the Dashboard counts it, Time records filters on it.
abstract final class DayAttendances {
  /// On time, late or left early; a day both late and left early counts once,
  /// as late. `null` for a day that isn't complete or corrected, or without a
  /// schedule to compare with.
  static DayAttendance? of(TimeRecordDay day, DayPlan? plan, WorkplaceClock clock) {
    if (day.status != TimeRecordStatus.complete && day.status != TimeRecordStatus.corrected) return null;
    final start = _at(day.date, plan?.start), finish = _at(day.date, plan?.finish);
    final startTime = day.start?.actual, finishTime = day.finish?.actual;
    if (plan == null || start == null || finish == null || startTime == null || finishTime == null) return null;
    final arrival = AttendanceCalculator.arrival(
      actual: clock.wallClockOf(startTime),
      scheduledStart: start,
      tolerance: Duration(minutes: plan.startMargin),
    );
    if (arrival == ArrivalStatus.late) return DayAttendance.late;
    final departure = AttendanceCalculator.departure(
      actual: clock.wallClockOf(finishTime),
      scheduledFinish: finish,
      tolerance: Duration(minutes: plan.finishMargin),
    );
    return departure == DepartureStatus.early ? DayAttendance.leftEarly : DayAttendance.onTime;
  }

  static DateTime? _at(DateTime date, String? hhmm) {
    final match = RegExp(r'^(\d\d):(\d\d)$').firstMatch(hhmm ?? '');
    if (match == null) return null;
    return DateTime.utc(date.year, date.month, date.day, int.parse(match.group(1)!), int.parse(match.group(2)!));
  }
}
