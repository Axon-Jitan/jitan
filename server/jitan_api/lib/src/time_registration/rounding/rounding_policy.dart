/// Rounding settings, as HR/Admin configure them (Figma "Edit policy"
/// `215:84`): a start and a finish interval, how an exact halfway point
/// rounds, and a scheduled-time tolerance that is separate from the
/// interval. Pure values: where they are stored (`tblRoundingRule`,
/// `tblSchedule.scheduleMarginMin`) is open (CLARIFY-03, see
/// docs/TIME_ENGINE_ANALYSIS.md).
library;

/// The interval lengths HR/Admin may choose (agreed 2026-10-08).
enum RoundingInterval {
  minutes15(15),
  minutes30(30),
  minutes60(60);

  const RoundingInterval(this.minutes);

  final int minutes;

  Duration get duration => Duration(minutes: minutes);

  /// The interval for [minutes], or `null` when it is not an allowed value.
  static RoundingInterval? fromMinutes(int minutes) =>
      RoundingInterval.values.where((i) => i.minutes == minutes).firstOrNull;
}

/// What happens to a time exactly halfway between two interval marks
/// (Figma "Halfway rounding").
enum HalfwayRounding {
  /// To the later mark ("Round forward"), e.g. 16:15 → 16:30.
  forward,

  /// To the earlier mark, e.g. 16:15 → 16:00.
  backward,
}

/// Whether a registration starts or finishes a period: start and finish
/// have their own interval (Figma "Start interval" / "Finish interval").
enum RoundingBoundary { start, finish }

/// One boundary's rule.
class RoundingRule {
  const RoundingRule({required this.interval, this.halfway = HalfwayRounding.forward});

  final RoundingInterval interval;
  final HalfwayRounding halfway;

  @override
  bool operator ==(Object other) => other is RoundingRule && other.interval == interval && other.halfway == halfway;

  @override
  int get hashCode => Object.hash(interval, halfway);

  @override
  String toString() => 'RoundingRule(${interval.minutes} min, ${halfway.name})';
}

/// The full rounding settings for one employee's period.
class RoundingPolicy {
  const RoundingPolicy({required this.start, required this.finish, this.scheduledTolerance = Duration.zero})
      : assert(scheduledTolerance >= Duration.zero, 'tolerance cannot be negative');

  final RoundingRule start;
  final RoundingRule finish;

  /// "Scheduled-time tolerance" (e.g. ±15 minutes): a time this close to the
  /// scheduled start/finish is registered as the scheduled time. Zero means
  /// no tolerance. Applied before, and instead of, interval rounding.
  final Duration scheduledTolerance;

  RoundingRule ruleFor(RoundingBoundary boundary) => switch (boundary) {
        RoundingBoundary.start => start,
        RoundingBoundary.finish => finish,
      };
}
