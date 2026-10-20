import 'package:jitan_api/src/time_registration/rounding/attendance_calculator.dart';
import 'package:test/test.dart';

DateTime _t(int hour, int minute, [int second = 0]) => DateTime.utc(2026, 10, 8, hour, minute, second);

void main() {
  group('arrival tolerance (minutes after the start that still count as on time)', () {
    ArrivalStatus arrival(DateTime actual, {int tolerance = 1}) =>
        AttendanceCalculator.arrival(actual: actual, scheduledStart: _t(8, 0), tolerance: Duration(minutes: tolerance));

    test('start 08:00, tolerance 1: 08:00 and 08:01 on time, 08:02 and 08:03 late (requirements example)', () {
      expect([for (final m in [0, 1, 2, 3]) arrival(_t(8, m))],
          [ArrivalStatus.onTime, ArrivalStatus.onTime, ArrivalStatus.late, ArrivalStatus.late]);
    });

    test('arriving early is on time; seconds do not count (08:01:59 is still 08:01)', () {
      expect(arrival(_t(7, 40)), ArrivalStatus.onTime);
      expect(arrival(_t(8, 1, 59)), ArrivalStatus.onTime);
    });

    test('tolerance 0: any minute after the start is late', () {
      expect(arrival(_t(8, 0), tolerance: 0), ArrivalStatus.onTime);
      expect(arrival(_t(8, 1), tolerance: 0), ArrivalStatus.late);
    });
  });

  group('leaving tolerance (minutes before the finish that are within tolerance)', () {
    DepartureStatus departure(DateTime actual, {int tolerance = 5}) =>
        AttendanceCalculator.departure(actual: actual, scheduledFinish: _t(16, 30), tolerance: Duration(minutes: tolerance));

    test('finish 16:30, tolerance 5: 16:30 on time, 16:28 and 16:25 within tolerance, 16:24 early (requirements example)', () {
      expect(departure(_t(16, 30)), DepartureStatus.onTime);
      expect(departure(_t(16, 28)), DepartureStatus.withinTolerance);
      expect(departure(_t(16, 25)), DepartureStatus.withinTolerance);
      expect(departure(_t(16, 24)), DepartureStatus.early);
    });

    test('leaving after the finish is on time; tolerance 0 makes any earlier minute early', () {
      expect(departure(_t(17, 5)), DepartureStatus.onTime);
      expect(departure(_t(16, 29), tolerance: 0), DepartureStatus.early);
    });
  });
}
