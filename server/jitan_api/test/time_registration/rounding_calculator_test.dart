import 'dart:math';

import 'package:jitan_api/src/time_registration/rounding/rounding_calculator.dart';
import 'package:jitan_api/src/time_registration/rounding/rounding_policy.dart';
import 'package:test/test.dart';

const _start = RoundingBoundary.start;
const _finish = RoundingBoundary.finish;

RoundingPolicy _policy(
  RoundingInterval interval, {
  RoundingInterval? finish,
  HalfwayRounding halfway = HalfwayRounding.forward,
  Duration tolerance = Duration.zero,
}) => RoundingPolicy(
  start: RoundingRule(interval: interval, halfway: halfway),
  finish: RoundingRule(interval: finish ?? interval, halfway: halfway),
  scheduledTolerance: tolerance,
);

DateTime _t(int hour, int minute, [int second = 0, int day = 8]) => DateTime.utc(2026, 10, day, hour, minute, second);

DateTime _registered(
  DateTime actual,
  RoundingPolicy policy, {
  RoundingBoundary boundary = _start,
  DateTime? scheduled,
}) => RoundingCalculator.round(actual: actual, boundary: boundary, policy: policy, scheduled: scheduled).registered;

void main() {
  group('interval rounding (Figma "How rounding works")', () {
    final thirty = _policy(RoundingInterval.minutes30);

    test('30-minute intervals: 16:10 → 16:00, 16:22 → 16:30, 16:50 → 17:00', () {
      expect(_registered(_t(16, 10), thirty), _t(16, 0));
      expect(_registered(_t(16, 22), thirty, boundary: _finish), _t(16, 30));
      expect(_registered(_t(16, 50), thirty, boundary: _finish), _t(17, 0));
    });

    test('15 and 60 minutes', () {
      final fifteen = _policy(RoundingInterval.minutes15);
      final sixty = _policy(RoundingInterval.minutes60);

      expect(_registered(_t(8, 3), fifteen), _t(8, 0));
      expect(_registered(_t(8, 8), fifteen), _t(8, 15));
      expect(_registered(_t(8, 29), sixty), _t(8, 0));
      expect(_registered(_t(8, 31), sixty), _t(9, 0));
    });

    test('an exact halfway point follows the halfway setting', () {
      expect(_registered(_t(16, 15), thirty), _t(16, 30), reason: 'round forward (Figma default)');
      expect(_registered(_t(16, 15), _policy(RoundingInterval.minutes30, halfway: HalfwayRounding.backward)), _t(16, 0));
      expect(_registered(_t(8, 30), _policy(RoundingInterval.minutes60)), _t(9, 0));
    });

    test('seconds count: just before the halfway point rounds down, just after rounds up', () {
      expect(_registered(_t(16, 14, 59), thirty), _t(16, 0));
      expect(_registered(_t(16, 15, 1), _policy(RoundingInterval.minutes30, halfway: HalfwayRounding.backward)), _t(16, 30));
    });

    test('a time on a mark stays as it is', () {
      expect(_registered(_t(8, 0), thirty), _t(8, 0));
      expect(_registered(_t(0, 0), thirty), _t(0, 0));
    });

    test('late evening can round to midnight of the next day', () {
      expect(_registered(_t(23, 50), thirty, boundary: _finish), _t(0, 0, 0, 9));
    });

    test('start and finish use their own interval', () {
      final policy = _policy(RoundingInterval.minutes15, finish: RoundingInterval.minutes60);

      expect(_registered(_t(16, 20), policy), _t(16, 15));
      expect(_registered(_t(16, 20), policy, boundary: _finish), _t(16, 0));
    });
  });

  group('scheduled-time tolerance (separate from the interval)', () {
    final policy = _policy(RoundingInterval.minutes30, tolerance: const Duration(minutes: 15));

    test('arrival after the scheduled start, within tolerance: the scheduled start (08:03 → 08:00)', () {
      final result = RoundingCalculator.round(actual: _t(8, 3), boundary: _start, policy: policy, scheduled: _t(8, 0));

      expect(result.registered, _t(8, 0));
      expect(result.reason, RoundingReason.scheduledTolerance);
      expect(result.actual, _t(8, 3), reason: 'the actual time is kept');
    });

    test('arrival before the scheduled start, within tolerance: the scheduled start', () {
      expect(_registered(_t(7, 47), policy, scheduled: _t(8, 0)), _t(8, 0));
    });

    test('the tolerance is inclusive at exactly ±15 minutes', () {
      expect(_registered(_t(8, 15), policy, scheduled: _t(8, 0)), _t(8, 0));
      expect(_registered(_t(7, 45), policy, scheduled: _t(8, 0)), _t(8, 0));
    });

    test('outside the tolerance: interval rounding, not the scheduled time', () {
      final result = RoundingCalculator.round(actual: _t(8, 16), boundary: _start, policy: policy, scheduled: _t(8, 0));

      expect(result.registered, _t(8, 30));
      expect(result.reason, RoundingReason.interval);
      expect(_registered(_t(7, 44), policy, scheduled: _t(8, 0)), _t(7, 30));
    });

    test('a scheduled finish works the same way (16:22 with finish 16:30 → 16:30)', () {
      expect(_registered(_t(16, 22), policy, boundary: _finish, scheduled: _t(16, 30)), _t(16, 30));
    });

    test('a scheduled time that is not on an interval mark is kept as scheduled', () {
      expect(_registered(_t(8, 50), policy, scheduled: _t(8, 45)), _t(8, 45));
    });

    test('no scheduled time, or no tolerance: interval rounding only', () {
      expect(_registered(_t(8, 3), policy), _t(8, 0));
      expect(
        RoundingCalculator.round(
          actual: _t(8, 10),
          boundary: _start,
          policy: _policy(RoundingInterval.minutes30),
          scheduled: _t(8, 30),
        ).reason,
        RoundingReason.interval,
      );
    });
  });

  group('the result is complete and reproducible', () {
    test('it echoes what was applied, so a stored result can be explained later', () {
      final policy = _policy(RoundingInterval.minutes15, finish: RoundingInterval.minutes30, tolerance: const Duration(minutes: 10));

      final result = RoundingCalculator.round(actual: _t(17, 2), boundary: _finish, policy: policy, scheduled: _t(16, 0));

      expect(result.boundary, _finish);
      expect(result.rule, const RoundingRule(interval: RoundingInterval.minutes30));
      expect(result.scheduled, _t(16, 0));
      expect(result.scheduledTolerance, const Duration(minutes: 10));
      expect(result.registered, _t(17, 0));
    });

    test('the same input always gives the same result (no source, clock or database input)', () {
      final policy = _policy(RoundingInterval.minutes30, tolerance: const Duration(minutes: 15));
      final results = {
        for (var i = 0; i < 3; i++)
          RoundingCalculator.round(actual: _t(8, 7), boundary: _start, policy: policy, scheduled: _t(8, 0)).registered,
      };

      expect(results, {_t(8, 0)});
    });

    test('wall-clock local times stay local and keep their fields', () {
      final local = DateTime(2026, 3, 29, 16, 22);

      final registered = _registered(local, _policy(RoundingInterval.minutes30), boundary: _finish);

      expect(registered.isUtc, isFalse);
      expect((registered.hour, registered.minute), (16, 30));
    });
  });

  test('only 15, 30 and 60 minutes are intervals', () {
    expect([15, 30, 60].map(RoundingInterval.fromMinutes), RoundingInterval.values);
    for (final other in [0, 5, 10, 20, 45, 90]) {
      expect(RoundingInterval.fromMinutes(other), isNull, reason: '$other');
    }
  });

  group('generated properties (20 000 random times per interval)', () {
    final random = Random(20261008);
    DateTime randomTime() => DateTime.utc(2026, 1, 1).add(Duration(seconds: random.nextInt(366 * 24 * 3600)));

    for (final interval in RoundingInterval.values) {
      for (final halfway in HalfwayRounding.values) {
        test('${interval.minutes} min, ${halfway.name}: on a mark, within half an interval, idempotent, monotonic', () {
          final policy = _policy(interval, halfway: halfway);
          final step = interval.duration;
          final times = [for (var i = 0; i < 20000; i++) randomTime()]..sort();
          DateTime? previous;
          for (final actual in times) {
            final registered = _registered(actual, policy);
            final sinceMidnight = registered.difference(DateTime.utc(registered.year, registered.month, registered.day));
            expect(sinceMidnight.inMicroseconds % step.inMicroseconds, 0, reason: '$actual → $registered on a mark');
            expect(registered.difference(actual).abs() <= step ~/ 2, isTrue, reason: '$actual → $registered');
            expect(_registered(registered, policy), registered, reason: 'rounding twice changes nothing');
            if (previous != null) expect(registered.isBefore(previous), isFalse, reason: 'later actual, never earlier result');
            previous = registered;
          }
        });
      }
    }

    test('with a tolerance, a result is the scheduled time only when within it', () {
      final policy = _policy(RoundingInterval.minutes30, tolerance: const Duration(minutes: 15));
      for (var i = 0; i < 20000; i++) {
        final scheduled = DateTime.utc(2026, 10, 8, 6 + random.nextInt(12), random.nextInt(4) * 15);
        final actual = scheduled.add(Duration(seconds: random.nextInt(7200) - 3600));
        final result = RoundingCalculator.round(actual: actual, boundary: _start, policy: policy, scheduled: scheduled);
        final within = actual.difference(scheduled).abs() <= const Duration(minutes: 15);
        expect(result.reason == RoundingReason.scheduledTolerance, within, reason: '$scheduled / $actual');
        expect(result.actual, actual);
      }
    });
  });
}
