/// Rounding settings, as HR/Admin configure them per group schedule
/// (decision D11a in docs/TIME_ENGINE_ANALYSIS.md): for the start and for
/// the finish separately, a direction (up or down) and an interval, or no
/// rounding at all. Pure values. Stored as one `tblRoundingRule` per
/// "Work – start" / "Work – finish" schedule row: the interval in
/// `roundingRuleValueInMin`, the direction in `roundingRuleRoundUp`; no rule
/// means no rounding.
library;

/// The interval lengths HR/Admin pick from (decision 2026-10-21).
enum RoundingInterval {
  minutes5(5),
  minutes10(10),
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

/// Which way a time moves to an interval mark (`roundingRuleRoundUp`).
enum RoundingDirection {
  /// To the next mark, e.g. 15 minutes: 08:04 → 08:15 (`roundingRuleRoundUp = 1`).
  up,

  /// To the previous mark, e.g. 15 minutes: 08:04 → 08:00 (`roundingRuleRoundUp = 0`).
  down,
}

/// Whether a registration starts or finishes a period: start and finish
/// have their own rule (schedule types "Work – start" and "Work – finish").
enum RoundingBoundary { start, finish }

/// One boundary's rounding: an interval and a direction.
class RoundingRule {
  const RoundingRule({required this.interval, required this.direction});

  final RoundingInterval interval;
  final RoundingDirection direction;

  @override
  bool operator ==(Object other) => other is RoundingRule && other.interval == interval && other.direction == direction;

  @override
  int get hashCode => Object.hash(interval, direction);

  @override
  String toString() => 'RoundingRule(${interval.minutes} min, ${direction.name})';
}

/// The rounding of one employee's working day: a rule for the start and
/// one for the finish; `null` means that boundary is not rounded.
class RoundingPolicy {
  const RoundingPolicy({this.start, this.finish});

  final RoundingRule? start;
  final RoundingRule? finish;

  RoundingRule? ruleFor(RoundingBoundary boundary) => switch (boundary) {
        RoundingBoundary.start => start,
        RoundingBoundary.finish => finish,
      };
}
