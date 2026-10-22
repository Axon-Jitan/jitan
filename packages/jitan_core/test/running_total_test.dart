import 'package:jitan_core/jitan_core.dart';
import 'package:test/test.dart';

void main() {
  final start = DateTime(2026, 10, 22, 8);
  int at(int hour, int minute) => RunningTotal.minutes(
    start: start,
    now: DateTime(2026, 10, 22, hour, minute),
    breakStart: '12:00',
    breakFinish: '12:30',
  );

  test('before the break nothing is deducted', () {
    expect(at(10, 14), 2 * 60 + 14);
  });

  test('during the break only the part already passed is deducted', () {
    expect(at(12, 15), 4 * 60);
  });

  test('after the break the whole break is deducted, meeting the finished total', () {
    expect(at(16, 0), 7 * 60 + 30, reason: '08:00–16:00 minus 30 min, as the server registers it');
    expect(at(16, 8), 7 * 60 + 38);
  });

  test('a start after the break deducts nothing; no break window deducts nothing; never negative', () {
    expect(RunningTotal.minutes(start: DateTime(2026, 10, 22, 13), now: DateTime(2026, 10, 22, 14), breakStart: '12:00', breakFinish: '12:30'), 60);
    expect(RunningTotal.minutes(start: start, now: DateTime(2026, 10, 22, 16)), 8 * 60);
    expect(RunningTotal.minutes(start: start, now: DateTime(2026, 10, 22, 7)), 0);
  });
}
