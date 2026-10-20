import '../time_registration/rounding/rounding_policy.dart';

/// The fixed choices of the HR/Admin schedule form (design brief
/// 2026-10-20). Defined once: `GET /schedules/options` sends them to the
/// form and the server validates against the same lists.
abstract final class ScheduleChoices {
  static final roundingIntervalMinutes = [for (final interval in RoundingInterval.values) interval.minutes];

  /// Scheduled-time tolerance, either side of the start or finish.
  static const toleranceMinutes = [0, 5, 10, 15];

  static const breakLengthMinutes = [15, 30, 45, 60];
}
