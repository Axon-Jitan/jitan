import 'dart:math';

import 'package:jitan_api/src/time_registration/rounding/rounding_calculator.dart';
import 'package:jitan_api/src/time_registration/rounding/rounding_policy.dart';
import 'package:test/test.dart';

const _start = RoundingBoundary.start;
const _finish = RoundingBoundary.finish;

RoundingRule _up(RoundingInterval interval) => RoundingRule(interval: interval, direction: RoundingDirection.up);
RoundingRule _down(RoundingInterval interval) => RoundingRule(interval: interval, direction: RoundingDirection.down);

DateTime _t(int hour, int minute, [int second = 0, int day = 8]) => DateTime.utc(2026, 10, day, hour, minute, second);

DateTime _registered(DateTime actual, RoundingPolicy policy, {RoundingBoundary boundary = _start}) =>
    RoundingCalculator.round(actual: actual, boundary: boundary, policy: policy).registered;

void main() {
  group('HR chooses the direction and the interval (decision 2026-10-21)', () {
    test('arrives 08:04: up every 15 → 08:15, up every 30 → 08:30, down every 15 → 08:00', () {
      expect(_registered(_t(8, 4), RoundingPolicy(start: _up(RoundingInterval.minutes15))), _t(8, 15));
      expect(_registered(_t(8, 4), RoundingPolicy(start: _up(RoundingInterval.minutes30))), _t(8, 30));
      expect(_registered(_t(8, 4), RoundingPolicy(start: _down(RoundingInterval.minutes15))), _t(8, 0));
    });

    test('no rounding: the time is registered as it is, in whole minutes', () {
      expect(_registered(_t(8, 4, 40), const RoundingPolicy()), _t(8, 4));
      expect(_registered(_t(16, 47), const RoundingPolicy(), boundary: _finish), _t(16, 47));
    });

    test('start and finish are independent: different direction, interval, or none', () {
      final policy = RoundingPolicy(start: _up(RoundingInterval.minutes15), finish: _down(RoundingInterval.minutes30));

      expect(_registered(_t(8, 4), policy), _t(8, 15));
      expect(_registered(_t(16, 47), policy, boundary: _finish), _t(16, 30));
      expect(_registered(_t(16, 47), RoundingPolicy(start: _up(RoundingInterval.minutes15)), boundary: _finish), _t(16, 47),
          reason: 'finish not rounded');
    });

    test('5, 10 and 60 minutes', () {
      expect(_registered(_t(16, 47), RoundingPolicy(finish: _down(RoundingInterval.minutes5)), boundary: _finish), _t(16, 45));
      expect(_registered(_t(8, 1), RoundingPolicy(start: _up(RoundingInterval.minutes10))), _t(8, 10));
      expect(_registered(_t(8, 1), RoundingPolicy(start: _up(RoundingInterval.minutes60))), _t(9, 0));
    });
  });

  group('details', () {
    test('a time on a mark stays as it is, in both directions', () {
      for (final rule in [_up(RoundingInterval.minutes30), _down(RoundingInterval.minutes30)]) {
        expect(_registered(_t(8, 0), RoundingPolicy(start: rule)), _t(8, 0));
        expect(_registered(_t(0, 0), RoundingPolicy(start: rule)), _t(0, 0));
      }
    });

    test('seconds do not count: 08:00:20 counts as 08:00 and stays, also rounding up', () {
      final policy = RoundingPolicy(start: _up(RoundingInterval.minutes15));

      expect(_registered(_t(8, 0, 20), policy), _t(8, 0));
      expect(_registered(_t(8, 0, 59), policy), _t(8, 0));
      expect(_registered(_t(8, 1), policy), _t(8, 15));
    });

    test('rounding up late in the evening can give midnight of the next day', () {
      expect(_registered(_t(23, 50), RoundingPolicy(finish: _up(RoundingInterval.minutes30)), boundary: _finish), _t(0, 0, 0, 9));
    });

    test('the result keeps the actual time and the rule applied', () {
      final policy = RoundingPolicy(start: _up(RoundingInterval.minutes15));
      final result = RoundingCalculator.round(actual: _t(8, 4, 30), boundary: _start, policy: policy);

      expect(result.actual, _t(8, 4, 30), reason: 'never overwritten');
      expect(result.rule, _up(RoundingInterval.minutes15));
      expect(RoundingCalculator.round(actual: _t(8, 4), boundary: _finish, policy: policy).rule, isNull);
    });

    test('wall-clock local times stay local and keep their fields', () {
      final registered = _registered(DateTime(2026, 3, 29, 16, 22), RoundingPolicy(finish: _up(RoundingInterval.minutes30)),
          boundary: _finish);

      expect(registered.isUtc, isFalse);
      expect((registered.hour, registered.minute), (16, 30));
    });

    test('only 5, 10, 15, 30 and 60 minutes are intervals', () {
      expect([5, 10, 15, 30, 60].map(RoundingInterval.fromMinutes), RoundingInterval.values);
      for (final other in [0, 1, 7, 20, 45, 90]) {
        expect(RoundingInterval.fromMinutes(other), isNull, reason: '$other');
      }
    });
  });

  group('generated properties (20 000 random times per interval and direction)', () {
    final random = Random(20261021);
    DateTime randomTime() => DateTime.utc(2026, 1, 1).add(Duration(seconds: random.nextInt(366 * 24 * 3600)));
    DateTime minuteOf(DateTime t) => DateTime.utc(t.year, t.month, t.day, t.hour, t.minute);

    for (final interval in RoundingInterval.values) {
      for (final direction in RoundingDirection.values) {
        test('${interval.minutes} min, ${direction.name}: on a mark, right side, less than one interval away, '
            'idempotent, monotonic', () {
          final policy = RoundingPolicy(start: RoundingRule(interval: interval, direction: direction));
          final step = interval.duration;
          final times = [for (var i = 0; i < 20000; i++) randomTime()]..sort();
          DateTime? previous;
          for (final actual in times) {
            final registered = _registered(actual, policy);
            final sinceMidnight = registered.difference(DateTime.utc(registered.year, registered.month, registered.day));
            expect(sinceMidnight.inMinutes % interval.minutes, 0, reason: '$actual → $registered on a mark');
            final moved = registered.difference(minuteOf(actual));
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
  });
}
