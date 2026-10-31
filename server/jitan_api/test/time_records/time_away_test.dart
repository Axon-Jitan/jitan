import 'package:jitan_api/src/time_records/my_day_service.dart';
import 'package:jitan_api/src/time_records/time_record_repository.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

var _id = 0;
RegistrationRow _row(String type, DateTime at, {bool manual = false, String? comment}) =>
    (id: ++_id, userId: 1, typeName: type, at: at, manualEntry: manual, comment: comment, active: true);

/// Local Brussels time on Thursday 22 October 2026 (UTC+2).
DateTime _at(int hour, [int minute = 0]) => DateTime.utc(2026, 10, 22, hour - 2, minute);

List<RegistrationRow> _start(int hour, [int minute = 0]) => [
  _row('Start – actual – Geofence', _at(hour, minute)),
  _row('Start – rounded', _at(hour, minute)),
];

List<RegistrationRow> _finish(int hour, [int minute = 0]) => [
  _row('Finish – actual – Geofence', _at(hour, minute)),
  _row('Finish – rounded', _at(hour, minute)),
];

/// Thursday 08:00–16:30 with a 30-minute break. "Now" is 18:00.
TestApp _app() {
  final app = TestApp(devUserId: 1, activeUserIds: {1})..now = _at(18);
  app.schedules.days = const [(id: 4, name: 'Thursday')];
  app.schedules.userSchedules = [
    for (final (id, type, sh, sm, eh, em) in [
      (11, 'Work – start', 8, 0, 16, 30),
      (12, 'Work – finish', 8, 0, 16, 30),
      (13, 'Break', 12, 0, 12, 30),
    ])
      (userId: 1, scheduleId: id, typeName: type, dayId: 4, startHour: sh, startMinute: sm, stopHour: eh, stopMinute: em, marginMinutes: 0),
  ];
  return app;
}

Future<MyDay> _today(TestApp app) async => MyDay.fromJson(await jsonBody(await app.get('/me/today')));

void main() {
  test('Break / personal, then back: the time away is not work and replaces the break (D34)', () async {
    final app = _app();
    app.timeRecords.rows = [..._start(8), ..._finish(13), ..._start(15), ..._finish(17)];

    final today = await _today(app);

    expect(today.day!.awayMinutes, 120);
    expect(today.day!.status, TimeRecordStatus.complete);
    expect(today.registeredMinutes, 7 * 60, reason: '9 h − 2 h away, the 30-minute break not taken off as well');
  });

  test('back and still working: the day is open again, with no finish', () async {
    final app = _app()..now = _at(15, 30);
    app.timeRecords.rows = [..._start(8), ..._finish(13), ..._start(15)];

    final today = await _today(app);

    expect((today.day!.status, today.day!.finish, today.day!.awayMinutes, today.registeredMinutes), (
      TimeRecordStatus.working,
      null,
      120,
      null,
    ));
  });

  test('left and not back: the time left is the finish, with the usual break', () async {
    final app = _app();
    app.timeRecords.rows = [..._start(8), ..._finish(16)];

    final today = await _today(app);

    expect((today.day!.status, today.day!.awayMinutes, today.registeredMinutes), (TimeRecordStatus.complete, 0, 7 * 60 + 30));
  });

  test('a past day that came back and never finished is a missing finish', () async {
    final app = _app()..now = DateTime.utc(2026, 10, 23, 8);
    app.timeRecords.rows = [..._start(8), ..._finish(13), ..._start(15)];

    final response = await app.get('/me/period?from=2026-10-22&to=2026-10-22');
    final day = MyPeriod.fromJson(await jsonBody(response)).days.single;

    expect((day.day!.status, day.registeredMinutes), (TimeRecordStatus.missingFinish, null));
  });

  test('two breaks add up', () async {
    final app = _app();
    app.timeRecords.rows = [..._start(8), ..._finish(10), ..._start(11), ..._finish(13), ..._start(14), ..._finish(17)];

    final today = await _today(app);

    expect((today.day!.awayMinutes, today.registeredMinutes), (120, 7 * 60));
  });

  test('travelling, waiting for HR: no total yet (D31)', () async {
    final app = _app();
    app.timeRecords.rows = [
      ..._start(8),
      ..._finish(13),
      _row('Finish – actual – Manual', _at(15), manual: true, comment: 'Drove to the client'),
      ..._start(15),
      ..._finish(17),
    ];

    final today = await _today(app);

    expect((today.day!.status, today.registeredMinutes), (TimeRecordStatus.pendingReview, null));
  });

  test('travelling approved by HR: the gap closes, and the usual break applies', () async {
    final app = _app();
    final request = _row('Finish – actual – Manual', _at(15), manual: true, comment: 'Drove to the client');
    app.timeRecords.rows = [
      ..._start(8),
      ..._finish(13),
      request,
      ..._start(15),
      ..._finish(17),
      // HR approves after the day has ended.
      _row('Finish – corrected', _at(15)),
      _row('Finish – rounded', _at(15)),
    ];

    final today = await _today(app);

    expect(today.day!.awayMinutes, 0);
    expect(today.registeredMinutes, 8 * 60 + 30);
  });

  test('an approved part of the time away counts; the rest does not', () async {
    final app = _app();
    app.timeRecords.rows = [
      ..._start(8),
      ..._finish(13),
      _row('Finish – actual – Manual', _at(14), manual: true, comment: 'Drove part of the way'),
      _row('Finish – corrected', _at(14)),
      _row('Finish – rounded', _at(14)),
      ..._start(15),
      ..._finish(17),
    ];

    expect((await _today(app)).day!.awayMinutes, 60);
  });

  test('a correction of the first start is not time away', () async {
    final app = _app();
    app.timeRecords.rows = [
      ..._start(9),
      _row('Start – corrected', _at(8)),
      _row('Start – rounded', _at(8)),
      ..._finish(17),
    ];

    final today = await _today(app);

    expect((today.day!.awayMinutes, today.registeredMinutes), (0, 8 * 60 + 30));
  });

  test('never below zero', () {
    final day = TimeRecordDay(
      employeeId: 1,
      employeeCode: 'X',
      date: DateTime.utc(2026, 10, 22),
      status: TimeRecordStatus.complete,
      awayMinutes: 600,
      start: TimeRecordTime(actualId: 1, actual: _at(8), rounded: _at(8), method: TimeRecordMethod.geofence, enteredByHand: false, actualLocal: '08:00', roundedLocal: '08:00'),
      finish: TimeRecordTime(actualId: 2, actual: _at(9), rounded: _at(9), method: TimeRecordMethod.geofence, enteredByHand: false, actualLocal: '09:00', roundedLocal: '09:00'),
    );

    expect(MyDayService.registeredMinutes(day, 30), 0);
  });
}
