import 'dart:math';

import 'package:jitan_api/src/time_registration/rounding/rounding_calculator.dart';
import 'package:jitan_api/src/time_registration/rounding/rounding_policy.dart';
import 'package:test/test.dart';

const _start = RoundingBoundary.start;
const _finish = RoundingBoundary.finish;

RoundingPolicy _favouring(
  RoundingFavour favour,
  RoundingInterval interval, {
  RoundingInterval? finish,
  Duration startTolerance = Duration.zero,
  Duration finishTolerance = Duration.zero,
}) => RoundingPolicy.favouring(
  favour,
  startInterval: interval,
  finishInterval: finish ?? interval,
  startTolerance: startTolerance,
  finishTolerance: finishTolerance,
);

RoundingPolicy _company(RoundingInterval interval, {RoundingInterval? finish, Duration tolerance = Duration.zero}) =>
    _favouring(RoundingFavour.company, interval, finish: finish, startTolerance: tolerance, finishTolerance: tolerance);

RoundingPolicy _employee(RoundingInterval interval, {Duration tolerance = Duration.zero}) =>
    _favouring(RoundingFavour.employee, interval, startTolerance: tolerance, finishTolerance: tolerance);

DateTime _t(int hour, int minute, [int second = 0, int day = 8]) => DateTime.utc(2026, 10, day, hour, minute, second);

DateTime _registered(
  DateTime actual,
  RoundingPolicy policy, {
  RoundingBoundary boundary = _start,
  DateTime? scheduled,
}) => RoundingCalculator.round(actual: actual, boundary: boundary, policy: policy, scheduled: scheduled).registered;

void main() {
  group('who the rounding favours (HR, decision 2026-10-20)', () {
    test('favours the company: start rounds up, finish rounds down (07:05 → 07:15, 16:25 → 16:15)', () {
      final policy = _company(RoundingInterval.minutes15);

      expect(_registered(_t(7, 5), policy), _t(7, 15));
      expect(_registered(_t(16, 25), policy, boundary: _finish), _t(16, 15));
    });

    test('favours the employee: start rounds down, finish rounds up (07:05 → 07:00, 16:25 → 16:30)', () {
      final policy = _employee(RoundingInterval.minutes15);

      expect(_registered(_t(7, 5), policy), _t(7, 0));
      expect(_registered(_t(16, 25), policy, boundary: _finish), _t(16, 30));
    });

    test('the favour only sets the directions of the two rules', () {
      expect(RoundingFavour.company.directionFor(_start), RoundingDirection.up);
      expect(RoundingFavour.company.directionFor(_finish), RoundingDirection.down);
      expect(RoundingFavour.employee.directionFor(_start), RoundingDirection.down);
      expect(RoundingFavour.employee.directionFor(_finish), RoundingDirection.up);
    });
  });

  group('interval rounding', () {
    test('30 and 60 minutes, both directions', () {
      final company30 = _company(RoundingInterval.minutes30);
      final company60 = _company(RoundingInterval.minutes60);

      expect(_registered(_t(8, 23), company30), _t(8, 30));
      expect(_registered(_t(16, 12), company30, boundary: _finish), _t(16, 0));
      expect(_registered(_t(8, 1), company60), _t(9, 0));
      expect(_registered(_t(16, 59), company60, boundary: _finish), _t(16, 0));
    });

    test('a time on a mark stays as it is, in both directions', () {
      for (final policy in [_company(RoundingInterval.minutes30), _employee(RoundingInterval.minutes30)]) {
        expect(_registered(_t(8, 0), policy), _t(8, 0));
        expect(_registered(_t(16, 30), policy, boundary: _finish), _t(16, 30));
        expect(_registered(_t(0, 0), policy), _t(0, 0));
      }
    });

    test('seconds do not count: 08:00:20 counts as 08:00 and stays, 08:00:59 too', () {
      final policy = _company(RoundingInterval.minutes15);

      expect(_registered(_t(8, 0, 20), policy), _t(8, 0));
      expect(_registered(_t(8, 0, 59), policy), _t(8, 0));
      expect(_registered(_t(8, 1, 0), policy), _t(8, 15));
      expect(_registered(_t(16, 29, 59), policy, boundary: _finish), _t(16, 15));
    });

    test('rounding up late in the evening can give midnight of the next day', () {
      expect(_registered(_t(23, 50), _employee(RoundingInterval.minutes30), boundary: _finish), _t(0, 0, 0, 9));
    });

    test('start and finish use their own interval', () {
      final policy = _company(RoundingInterval.minutes15, finish: RoundingInterval.minutes60);

      expect(_registered(_t(8, 20), policy), _t(8, 30));
      expect(_registered(_t(16, 50), policy, boundary: _finish), _t(16, 0));
    });
  });

  group('scheduled-time tolerance (applied first, per boundary)', () {
    final policy = _company(RoundingInterval.minutes15, tolerance: const Duration(minutes: 10));

    test('within the tolerance the scheduled time is registered, whatever the direction (08:07 → 08:00)', () {
      final result = RoundingCalculator.round(actual: _t(8, 7), boundary: _start, policy: policy, scheduled: _t(8, 0));

      expect(result.registered, _t(8, 0));
      expect(result.reason, RoundingReason.scheduledTolerance);
      expect(result.actual, _t(8, 7), reason: 'the actual time is kept');
      expect(_registered(_t(7, 52), policy, scheduled: _t(8, 0)), _t(8, 0));
    });

    test('the tolerance is inclusive, in whole minutes (08:10:40 is still within ±10)', () {
      expect(_registered(_t(8, 10), policy, scheduled: _t(8, 0)), _t(8, 0));
      expect(_registered(_t(8, 10, 40), policy, scheduled: _t(8, 0)), _t(8, 0));
      expect(_registered(_t(7, 50), policy, scheduled: _t(8, 0)), _t(8, 0));
    });

    test('outside the tolerance: interval rounding in the rule direction', () {
      final result = RoundingCalculator.round(actual: _t(8, 11), boundary: _start, policy: policy, scheduled: _t(8, 0));

      expect(result.registered, _t(8, 15));
      expect(result.reason, RoundingReason.interval);
      expect(_registered(_t(16, 12), policy, boundary: _finish, scheduled: _t(16, 30)), _t(16, 0));
    });

    test('start and finish have their own tolerance', () {
      final mixed = _favouring(
        RoundingFavour.company,
        RoundingInterval.minutes15,
        startTolerance: const Duration(minutes: 10),
      );

      expect(_registered(_t(8, 7), mixed, scheduled: _t(8, 0)), _t(8, 0), reason: 'start: ±10');
      expect(_registered(_t(16, 25), mixed, boundary: _finish, scheduled: _t(16, 30)), _t(16, 15), reason: 'finish: no tolerance');
    });

    test('no scheduled time, or no tolerance: interval rounding only', () {
      expect(_registered(_t(8, 7), policy), _t(8, 15));
      expect(
        RoundingCalculator.round(
          actual: _t(8, 7),
          boundary: _start,
          policy: _company(RoundingInterval.minutes15),
          scheduled: _t(8, 0),
        ).reason,
        RoundingReason.interval,
      );
    });
  });

  group('the result is complete and reproducible', () {
    test('it echoes what was applied, so a stored result can be explained later', () {
      final policy = _company(RoundingInterval.minutes15, finish: RoundingInterval.minutes30);

      final result = RoundingCalculator.round(actual: _t(17, 2), boundary: _finish, policy: policy, scheduled: _t(16, 0));

      expect(result.boundary, _finish);
      expect(result.rule, const RoundingRule(interval: RoundingInterval.minutes30, direction: RoundingDirection.down));
      expect(result.scheduled, _t(16, 0));
      expect(result.registered, _t(17, 0));
    });

    test('wall-clock local times stay local and keep their fields', () {
      final local = DateTime(2026, 3, 29, 16, 22);

      final registered = _registered(local, _employee(RoundingInterval.minutes30), boundary: _finish);

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

  group('generated properties (20 000 random times per interval and direction)', () {
    final random = Random(20261020);
    DateTime randomTime() => DateTime.utc(2026, 1, 1).add(Duration(seconds: random.nextInt(366 * 24 * 3600)));
    DateTime minuteOf(DateTime t) => DateTime.utc(t.year, t.month, t.day, t.hour, t.minute);

    for (final interval in RoundingInterval.values) {
      for (final direction in RoundingDirection.values) {
        test('${interval.minutes} min, ${direction.name}: on a mark, right side, less than one interval away, '
            'idempotent, monotonic', () {
          final rule = RoundingRule(interval: interval, direction: direction);
          final policy = RoundingPolicy(start: rule, finish: rule);
          final step = interval.duration;
          final times = [for (var i = 0; i < 20000; i++) randomTime()]..sort();
          DateTime? previous;
          for (final actual in times) {
            final registered = _registered(actual, policy);
            final minute = minuteOf(actual);
            final sinceMidnight = registered.difference(DateTime.utc(registered.year, registered.month, registered.day));
            expect(sinceMidnight.inMinutes % interval.minutes, 0, reason: '$actual → $registered on a mark');
            final moved = registered.difference(minute);
            if (direction == RoundingDirection.up) {
              expect(moved >= Duration.zero && moved < step, isTrue, reason: '$actual → $registered rounds up');
            } else {
              expect(moved <= Duration.zero && -moved < step, isTrue, reason: '$actual → $registered rounds down');
            }
            expect(_registered(registered, policy), registered, reason: 'rounding twice changes nothing');
            if (previous != null) expect(registered.isBefore(previous), isFalse, reason: 'later actual, never earlier result');
            previous = registered;
          }
        });
      }
    }

    test('with a tolerance, a result is the scheduled time only when within it (whole minutes)', () {
      final policy = _company(RoundingInterval.minutes30, tolerance: const Duration(minutes: 15));
      for (var i = 0; i < 20000; i++) {
        final scheduled = DateTime.utc(2026, 10, 8, 6 + random.nextInt(12), random.nextInt(4) * 15);
        final actual = scheduled.add(Duration(seconds: random.nextInt(7200) - 3600));
        final result = RoundingCalculator.round(actual: actual, boundary: _start, policy: policy, scheduled: scheduled);
        final within = minuteOf(actual).difference(scheduled).abs() <= const Duration(minutes: 15);
        expect(result.reason == RoundingReason.scheduledTolerance, within, reason: '$scheduled / $actual');
        expect(result.actual, actual);
      }
    });
  });
}
