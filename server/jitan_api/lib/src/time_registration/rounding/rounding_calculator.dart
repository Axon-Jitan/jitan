import 'rounding_policy.dart';

/// Why the registered time is what it is.
enum RoundingReason {
  /// Within the scheduled-time tolerance: the scheduled time.
  scheduledTolerance,

  /// Moved to an interval mark in the rule's direction.
  interval,
}

/// The outcome for one registration. [actual] is the input, unchanged: the
/// actual detected time is never overwritten (roadmap §16). Everything that
/// produced [registered] is included, so it can be explained later even if
/// the schedule changes.
class RoundedTime {
  const RoundedTime({
    required this.actual,
    required this.registered,
    required this.boundary,
    required this.reason,
    required this.rule,
    required this.scheduled,
  });

  final DateTime actual;
  final DateTime registered;
  final RoundingBoundary boundary;
  final RoundingReason reason;

  /// The rule of [boundary] that was in effect.
  final RoundingRule rule;

  /// The scheduled time compared against, if any.
  final DateTime? scheduled;

  @override
  String toString() => 'RoundedTime($actual → $registered, ${boundary.name}, ${reason.name}, $rule)';
}

/// The registered-time calculation (decisions D10–D11b in
/// docs/TIME_ENGINE_ANALYSIS.md): pure, deterministic, with no database,
/// clock or source input. The same call gives the same result for a
/// geofence, QR or manual registration: the source is not a parameter.
///
/// 0. The actual time counts in **whole minutes**: seconds are dropped
///    (08:00:20 counts as 08:00), so a second never moves a time to the next
///    mark.
/// 1. **Scheduled-time tolerance** (when a scheduled time is given and the
///    rule's tolerance is not zero): a time within ±tolerance of it,
///    inclusive, is registered as the scheduled time ("08:03 → 08:00").
/// 2. Otherwise **interval rounding** in the rule's direction, to a mark
///    counted from midnight: up to the next mark ("15 min: 07:05 → 07:15"),
///    down to the previous one ("16:25 → 16:15"). A time on a mark stays.
///
/// Times are wall-clock values: arithmetic is done on their fields,
/// independent of the machine's timezone and daylight saving, and the result
/// keeps the input's `isUtc`.
abstract final class RoundingCalculator {
  static RoundedTime round({
    required DateTime actual,
    required RoundingBoundary boundary,
    required RoundingPolicy policy,
    DateTime? scheduled,
  }) {
    final rule = policy.ruleFor(boundary);
    final minute = _wholeMinute(_fields(actual));
    RoundedTime result(DateTime registered, RoundingReason reason) => RoundedTime(
          actual: actual,
          registered: registered,
          boundary: boundary,
          reason: reason,
          rule: rule,
          scheduled: scheduled,
        );

    if (scheduled != null && rule.tolerance > Duration.zero) {
      final distance = minute.difference(_wholeMinute(_fields(scheduled))).abs();
      if (distance <= rule.tolerance) return result(scheduled, RoundingReason.scheduledTolerance);
    }
    return result(_like(actual, _toInterval(minute, rule)), RoundingReason.interval);
  }

  /// The interval mark of the same day's clock in the rule's direction (up
  /// may give midnight of the next day).
  static DateTime _toInterval(DateTime minute, RoundingRule rule) {
    final midnight = DateTime.utc(minute.year, minute.month, minute.day);
    final sinceMidnight = minute.difference(midnight).inMinutes;
    final step = rule.interval.minutes;
    final below = sinceMidnight ~/ step * step;
    final onMark = below == sinceMidnight;
    final mark = switch (rule.direction) {
      RoundingDirection.down => below,
      RoundingDirection.up => onMark ? below : below + step,
    };
    return midnight.add(Duration(minutes: mark));
  }

  /// [time] without its seconds and fractions.
  static DateTime _wholeMinute(DateTime time) =>
      DateTime.utc(time.year, time.month, time.day, time.hour, time.minute);

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
