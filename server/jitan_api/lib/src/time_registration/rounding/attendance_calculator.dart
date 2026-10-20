import 'rounding_calculator.dart';

/// Whether an employee arrived on time (decision D11b in
/// docs/TIME_ENGINE_ANALYSIS.md).
enum ArrivalStatus {
  /// At or before the scheduled start, or within the arrival tolerance.
  onTime,

  /// More than the arrival tolerance after the scheduled start.
  late,
}

/// Whether an employee left on time.
enum DepartureStatus {
  /// At or after the scheduled finish.
  onTime,

  /// Before the scheduled finish, but within the leaving tolerance.
  withinTolerance,

  /// More than the leaving tolerance before the scheduled finish.
  early,
}

/// The attendance status of a start or finish, from the **actual** time and
/// the schedule (decision D11b). Tolerance is one-sided and changes no time:
///
/// - **Arrival tolerance** (`scheduleMarginMin` of the "Work – start" row):
///   start 08:00, tolerance 1 → 08:00 and 08:01 on time, 08:02 late.
/// - **Leaving tolerance** (`scheduleMarginMin` of the "Work – finish" row):
///   finish 16:30, tolerance 5 → 16:30 on time, 16:28 and 16:25 within
///   tolerance, 16:24 early.
///
/// Like rounding, it counts whole minutes (seconds are dropped) and works on
/// wall-clock fields. Pure: no database, clock or source input.
abstract final class AttendanceCalculator {
  static ArrivalStatus arrival({
    required DateTime actual,
    required DateTime scheduledStart,
    required Duration tolerance,
  }) {
    final late = RoundingCalculator.wholeMinute(actual).difference(RoundingCalculator.wholeMinute(scheduledStart));
    return late > tolerance ? ArrivalStatus.late : ArrivalStatus.onTime;
  }

  static DepartureStatus departure({
    required DateTime actual,
    required DateTime scheduledFinish,
    required Duration tolerance,
  }) {
    final early = RoundingCalculator.wholeMinute(scheduledFinish).difference(RoundingCalculator.wholeMinute(actual));
    if (early <= Duration.zero) return DepartureStatus.onTime;
    return early <= tolerance ? DepartureStatus.withinTolerance : DepartureStatus.early;
  }
}
