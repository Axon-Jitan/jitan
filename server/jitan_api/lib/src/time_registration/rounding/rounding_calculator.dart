import 'rounding_policy.dart';

/// The outcome for one registration. [actual] is the input, unchanged: the
/// actual detected time is never overwritten (roadmap §16). The rule that
/// produced [registered] is included, so it can be explained later even if
/// the schedule changes.
class RoundedTime {
  const RoundedTime({required this.actual, required this.registered, required this.boundary, required this.rule});

  final DateTime actual;
  final DateTime registered;
  final RoundingBoundary boundary;

  /// The rule of [boundary] that was applied; `null` when it is not rounded.
  final RoundingRule? rule;

  @override
  String toString() => 'RoundedTime($actual → $registered, ${boundary.name}, $rule)';
}

/// The registered-time calculation (decision D11a in
/// docs/TIME_ENGINE_ANALYSIS.md): pure, deterministic, with no database,
/// clock or source input. The same call gives the same result for a
/// geofence, QR or manual registration: the source is not a parameter.
///
/// - The actual time counts in **whole minutes**: seconds are dropped
///   (08:00:20 counts as 08:00), so a second never moves a time to the next
///   mark.
/// - With a rule, the time moves to a mark counted from midnight in the
///   rule's direction: up to the next mark ("15 min: 08:04 → 08:15"), down to
///   the previous one ("08:04 → 08:00"). A time on a mark stays.
/// - Without a rule (no rounding), the whole-minute time is registered.
///
/// The scheduled-time tolerance does **not** change any time: it only decides
/// the attendance status (`AttendanceCalculator`).
///
/// Times are wall-clock values: arithmetic is done on their fields,
/// independent of the machine's timezone and daylight saving, and the result
/// keeps the input's `isUtc`.
abstract final class RoundingCalculator {
  static RoundedTime round({
    required DateTime actual,
    required RoundingBoundary boundary,
    required RoundingPolicy policy,
  }) {
    final rule = policy.ruleFor(boundary);
    final minute = wholeMinute(actual);
    return RoundedTime(
      actual: actual,
      registered: _like(actual, rule == null ? minute : _toInterval(minute, rule)),
      boundary: boundary,
      rule: rule,
    );
  }

  /// The interval mark of the same day's clock in the rule's direction (up
  /// may give midnight of the next day).
  static DateTime _toInterval(DateTime minute, RoundingRule rule) {
    final midnight = DateTime.utc(minute.year, minute.month, minute.day);
    final sinceMidnight = minute.difference(midnight).inMinutes;
    final step = rule.interval.minutes;
    final below = sinceMidnight ~/ step * step;
    final mark = switch (rule.direction) {
      RoundingDirection.down => below,
      RoundingDirection.up => below == sinceMidnight ? below : below + step,
    };
    return midnight.add(Duration(minutes: mark));
  }

  /// [time]'s wall-clock fields without seconds, as a UTC value so
  /// arithmetic ignores DST.
  static DateTime wholeMinute(DateTime time) => DateTime.utc(time.year, time.month, time.day, time.hour, time.minute);

  /// [fields] as the same kind of value as [like] (UTC or local wall clock).
  static DateTime _like(DateTime like, DateTime fields) =>
      like.isUtc ? fields : DateTime(fields.year, fields.month, fields.day, fields.hour, fields.minute);
}
