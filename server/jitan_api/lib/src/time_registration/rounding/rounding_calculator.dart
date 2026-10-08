import 'rounding_policy.dart';

/// Why the registered time is what it is.
enum RoundingReason {
  /// Within the scheduled-time tolerance: the scheduled time.
  scheduledTolerance,

  /// Rounded to the nearest interval mark.
  interval,
}

/// The outcome for one registration. [actual] is the input, unchanged: the
/// actual detected time is never overwritten (roadmap §16). Everything that
/// produced [registered] is included, so it can be recorded and the result
/// reproduced later even if the policy changes.
class RoundedTime {
  const RoundedTime({
    required this.actual,
    required this.registered,
    required this.boundary,
    required this.reason,
    required this.rule,
    required this.scheduled,
    required this.scheduledTolerance,
  });

  final DateTime actual;
  final DateTime registered;
  final RoundingBoundary boundary;
  final RoundingReason reason;

  /// The interval rule of [boundary] that was in effect.
  final RoundingRule rule;

  /// The scheduled time compared against, if any.
  final DateTime? scheduled;
  final Duration scheduledTolerance;

  @override
  String toString() => 'RoundedTime($actual → $registered, ${boundary.name}, ${reason.name}, $rule)';
}

/// The registered-time calculation (roadmap §16–17, Figma "How rounding
/// works"): pure, deterministic, with no database, clock or source input.
/// The same call gives the same result for a geofence, QR or manual
/// registration: the source is not a parameter.
///
/// 1. **Scheduled-time tolerance** (when a scheduled time is given and the
///    tolerance is not zero): an actual time within ±tolerance of it,
///    inclusive, is registered as the scheduled time ("08:03 → 08:00").
/// 2. Otherwise **interval rounding**: the nearest mark of the boundary's
///    interval, counted from midnight ("30 min: 16:10 → 16:00, 16:22 → 16:30,
///    16:50 → 17:00"); an exact halfway point follows [HalfwayRounding].
///
/// Times are wall-clock values (timezone is GAP-02): arithmetic is done on
/// their fields, independent of the machine's timezone and daylight saving,
/// and the result keeps the input's `isUtc`. Seconds and below count, so
/// 16:14:59 is before the halfway point of 16:00–16:30.
abstract final class RoundingCalculator {
  static RoundedTime round({
    required DateTime actual,
    required RoundingBoundary boundary,
    required RoundingPolicy policy,
    DateTime? scheduled,
  }) {
    final rule = policy.ruleFor(boundary);
    final tolerance = policy.scheduledTolerance;
    RoundedTime result(DateTime registered, RoundingReason reason) => RoundedTime(
          actual: actual,
          registered: registered,
          boundary: boundary,
          reason: reason,
          rule: rule,
          scheduled: scheduled,
          scheduledTolerance: tolerance,
        );

    if (scheduled != null && tolerance > Duration.zero) {
      final distance = _fields(actual).difference(_fields(scheduled)).abs();
      if (distance <= tolerance) return result(scheduled, RoundingReason.scheduledTolerance);
    }
    return result(_toInterval(actual, rule), RoundingReason.interval);
  }

  /// The nearest interval mark of the same day's clock (may be midnight of
  /// the next day).
  static DateTime _toInterval(DateTime actual, RoundingRule rule) {
    final wall = _fields(actual);
    final midnight = DateTime.utc(wall.year, wall.month, wall.day);
    final sinceMidnight = wall.difference(midnight).inMicroseconds;
    final step = rule.interval.duration.inMicroseconds;
    final below = sinceMidnight ~/ step * step;
    final offset = sinceMidnight - below;
    final half = step ~/ 2;
    final up = offset > half || (offset == half && rule.halfway == HalfwayRounding.forward);
    final rounded = midnight.add(Duration(microseconds: up && offset != 0 ? below + step : below));
    return _like(actual, rounded);
  }

  /// [time]'s wall-clock fields as a UTC value, so arithmetic ignores DST.
  static DateTime _fields(DateTime time) => DateTime.utc(
        time.year,
        time.month,
        time.day,
        time.hour,
        time.minute,
        time.second,
        time.millisecond,
        time.microsecond,
      );

  /// [fields] as the same kind of value as [like] (UTC or local wall clock).
  static DateTime _like(DateTime like, DateTime fields) => like.isUtc
      ? fields
      : DateTime(fields.year, fields.month, fields.day, fields.hour, fields.minute, fields.second, fields.millisecond,
          fields.microsecond);
}
