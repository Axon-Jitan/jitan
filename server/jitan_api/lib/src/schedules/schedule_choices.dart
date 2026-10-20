import '../time_registration/rounding/rounding_policy.dart';

/// The fixed choices of the HR/Admin schedule form (decisions 2026-10-21).
/// Defined once: `GET /schedules/options` sends them to the form and the
/// server validates against the same values.
abstract final class ScheduleChoices {
  /// Rounding intervals HR picks from: 5, 10, 15, 30, 60 minutes.
  static final roundingIntervalMinutes = [for (final interval in RoundingInterval.values) interval.minutes];

  /// Arrival and leaving tolerance: any whole number of minutes up to this.
  static const maxToleranceMinutes = 60;

  static const breakLengthMinutes = [15, 30, 45, 60];
}
