import 'package:jitan_api/src/time_records/my_day_service.dart';
import 'package:jitan_api/src/time_records/time_record_days.dart';
import 'package:jitan_api/src/time_records/time_record_repository.dart';
import 'package:jitan_api/src/time_registration/workplace_clock.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

const _user = 11;
final _clock = WorkplaceClock('Europe/Brussels');
var _id = 0;

/// Brussels local time on 19 October (UTC+2).
DateTime _at(int hour, [int minute = 0]) => DateTime.utc(2026, 10, 19, hour - 2, minute);

RegistrationRow _row(String type, DateTime at, {bool active = true, String? comment}) =>
    (id: ++_id, userId: _user, typeName: type, at: at, manualEntry: false, comment: comment, active: active);

List<RegistrationRow> _start(int hour) => [_row('Start – actual – Manual', _at(hour)), _row('Start – rounded', _at(hour))];

List<RegistrationRow> _finish(int hour, [int minute = 0]) => [
  _row('Finish – actual – Manual', _at(hour, minute)),
  _row('Finish – rounded', _at(hour, minute)),
];

TimeRecordDay _day(List<RegistrationRow> rows) => TimeRecordDays.build(
  rows: rows,
  employees: const {
    _user: EmployeeSummary(id: _user, code: 'SBW', firstName: 'A', lastName: 'B', groups: [], isActive: true, isActivated: true),
  },
  clock: _clock,
  today: DateTime.utc(2026, 10, 22),
).single;

void main() {
  final van = [
    ..._start(8),
    _row('Activity – Internal', _at(8)),
    _row('Activity – Transport', _at(8, 15)),
    _row('Activity – Client on site', _at(9)),
    _row('Activity – Transport', _at(16, 30)),
    ..._finish(17, 15),
  ];

  test('D25, D46: the van journey has 1:30 of travel, shown next to the worked time and never in it', () {
    final day = _day(van);

    expect(day.transportMinutes, 90);
    expect(MyDayService.registeredMinutes(day, 30), 555 - 30 - 90);
  });

  test('a transport still running is not subtracted until it ends', () {
    expect(_day([..._start(8), _row('Activity – Transport', _at(9))]).transportMinutes, 0);
  });

  test('the finish ends a transport that nothing else ended', () {
    final day = _day([..._start(8), _row('Activity – Transport', _at(15)), ..._finish(16)]);

    expect(day.transportMinutes, 60);
  });

  test('a finish before the next activity ends the transport there', () {
    final day = _day([
      ..._start(8),
      _row('Activity – Transport', _at(10)),
      ..._finish(11),
      ..._start(13),
      _row('Activity – Internal', _at(13)),
    ]);

    expect(day.transportMinutes, 60);
  });

  test('more transport than time: never below zero', () {
    final day = _day([..._start(8), _row('Activity – Transport', _at(8)), ..._finish(8, 10)]);

    expect(MyDayService.registeredMinutes(day, 30), 0);
  });

  test('activity rows change nothing about the day', () {
    final plain = _day([..._start(8), ..._finish(16)]);
    final switched = _day([..._start(8), _row('Activity – Internal', _at(8)), _row('Activity – Client on site', _at(9)), ..._finish(16)]);

    expect(switched.status, plain.status);
    expect(switched.start?.actual, plain.start?.actual);
    expect(switched.finish?.actual, plain.finish?.actual);
    expect(MyDayService.registeredMinutes(switched, 30), MyDayService.registeredMinutes(plain, 30));
  });

  test('a day marked non-work stays non-work with its activity rows', () {
    final off = <RegistrationRow>[
      _row('Start – actual – Manual', _at(8), active: false),
      _row('Start – rounded', _at(8), active: false, comment: 'Holiday'),
      _row('Activity – Internal', _at(8)),
    ];

    expect(_day(off).status, TimeRecordStatus.nonWork);
  });

  test('a switched-off transport row does not count', () {
    final day = _day([..._start(8), _row('Activity – Transport', _at(9), active: false), ..._finish(16)]);

    expect(day.transportMinutes, 0);
  });
}
