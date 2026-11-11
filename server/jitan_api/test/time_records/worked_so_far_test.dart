import 'package:jitan_api/src/time_records/my_day_service.dart';
import 'package:jitan_api/src/time_records/week_plans.dart';
import 'package:jitan_api/src/time_registration/workplace_clock.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

// November in Brussels is UTC+1.
final _clock = WorkplaceClock('Europe/Brussels');
DateTime _at(String hhmm) => _clock.utcOf(DateTime(2026, 11, 11, int.parse(hhmm.substring(0, 2)), int.parse(hhmm.substring(3))));

const DayPlan _plan = (
  start: '08:00',
  finish: '16:30',
  breakStart: '12:00',
  breakFinish: '12:30',
  breakMinutes: 30,
  startMargin: 5,
  finishMargin: 5,
);

TimeRecordDay _day({
  TimeRecordStatus status = TimeRecordStatus.working,
  String start = '08:00',
  int transport = 0,
  DateTime? travellingSince,
}) => TimeRecordDay(
  employeeId: 1,
  employeeCode: 'KDV',
  date: DateTime.utc(2026, 11, 11),
  status: status,
  start: TimeRecordTime(
    actualId: 1,
    actual: _at(start),
    rounded: _at(start),
    method: TimeRecordMethod.geofence,
    enteredByHand: false,
    actualLocal: start,
  ),
  transportMinutes: transport,
  travellingSince: travellingSince,
);

int? _soFar(TimeRecordDay day, String now) => MyDayService.workedSoFar(day, _plan, _at(now), _clock);

void main() {
  test('before the break: from the start until now', () {
    expect(_soFar(_day(), '11:30'), 3 * 60 + 30);
  });

  test('during and after the break: only the part passed is taken off', () {
    expect(_soFar(_day(), '12:10'), 4 * 60);
    expect(_soFar(_day(), '13:00'), 5 * 60 - 30);
  });

  test('travel is never worked: finished travel comes off, and a trip under way stops the clock', () {
    expect(_soFar(_day(transport: 40), '11:00'), 3 * 60 - 40);
    expect(_soFar(_day(travellingSince: _at('10:00')), '11:00'), 2 * 60);
  });

  test('only a day still running; a finished day counts its registered time instead', () {
    expect(_soFar(_day(status: TimeRecordStatus.complete), '13:00'), isNull);
    expect(_soFar(_day(status: TimeRecordStatus.missingFinish), '13:00'), isNull);
  });

  test('a rounded start still to come counts nothing yet', () {
    expect(_soFar(_day(start: '08:15'), '08:10'), 0);
  });
}
