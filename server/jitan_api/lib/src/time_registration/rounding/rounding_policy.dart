/// Rounding settings, as HR/Admin configure them per schedule: for the start
/// and for the finish, an interval, a direction and a scheduled-time
/// tolerance. Pure values. Where they are stored (docs/TIME_ENGINE_ANALYSIS.md,
/// decisions D10–D11): the interval in `tblRoundingRule.roundingRuleValueInMin`,
/// the direction in `tblRoundingRule.roundingRuleRoundUp`, the tolerance in
/// `tblSchedule.scheduleMarginMin` of the "Work – start" / "Work – finish" row.
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

/// Which way a time moves to an interval mark (`roundingRuleRoundUp`).
enum RoundingDirection {
  /// To the next mark, e.g. 15 minutes: 07:05 → 07:15 (`roundingRuleRoundUp = 1`).
  up,

  /// To the previous mark, e.g. 15 minutes: 16:25 → 16:15 (`roundingRuleRoundUp = 0`).
  down,
}

/// Whether a registration starts or finishes a period: start and finish
/// have their own rule (schedule types "Work – start" and "Work – finish").
enum RoundingBoundary { start, finish }

/// Who the rounding favours, as HR chooses it for a schedule (decision D11a,
/// 2026-10-20). It only sets the directions of the start and finish rules.
enum RoundingFavour {
  /// The default: a start rounds up, a finish rounds down.
  company,

  /// A start rounds down, a finish rounds up.
  employee;

  RoundingDirection directionFor(RoundingBoundary boundary) => switch ((this, boundary)) {
        (company, RoundingBoundary.start) || (employee, RoundingBoundary.finish) => RoundingDirection.up,
        (company, RoundingBoundary.finish) || (employee, RoundingBoundary.start) => RoundingDirection.down,
      };
}

/// One boundary's rule: interval, direction and scheduled-time tolerance.
class RoundingRule {
  const RoundingRule({required this.interval, required this.direction, this.tolerance = Duration.zero});

  final RoundingInterval interval;
  final RoundingDirection direction;

  /// "Scheduled-time tolerance" (e.g. ±10 minutes): a time this close to the
  /// scheduled time is registered as the scheduled time. Zero (or a negative
  /// value, which the schedule service never stores) means none. Applied
  /// before, and instead of, interval rounding.
  final Duration tolerance;

  @override
  bool operator ==(Object other) =>
      other is RoundingRule && other.interval == interval && other.direction == direction && other.tolerance == tolerance;

  @override
  int get hashCode => Object.hash(interval, direction, tolerance);

  @override
  String toString() => 'RoundingRule(${interval.minutes} min, ${direction.name}, ±${tolerance.inMinutes} min)';
}

/// The full rounding settings for one employee's period.
class RoundingPolicy {
  const RoundingPolicy({required this.start, required this.finish});

  /// Both rules with the directions of [favour].
  RoundingPolicy.favouring(
    RoundingFavour favour, {
    required RoundingInterval startInterval,
    required RoundingInterval finishInterval,
    Duration startTolerance = Duration.zero,
    Duration finishTolerance = Duration.zero,
  })  : start = RoundingRule(
          interval: startInterval,
          direction: favour.directionFor(RoundingBoundary.start),
          tolerance: startTolerance,
        ),
        finish = RoundingRule(
          interval: finishInterval,
          direction: favour.directionFor(RoundingBoundary.finish),
          tolerance: finishTolerance,
        );

  final RoundingRule start;
  final RoundingRule finish;

  RoundingRule ruleFor(RoundingBoundary boundary) => switch (boundary) {
        RoundingBoundary.start => start,
        RoundingBoundary.finish => finish,
      };
}
