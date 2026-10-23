import 'package:jitan_api/src/time_records/time_record_repository.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

var _id = 0;
RegistrationRow _row(int userId, String type, DateTime at, {bool manual = false, String? comment, bool active = true}) =>
    (id: ++_id, userId: userId, typeName: type, at: at, manualEntry: manual, comment: comment, active: active);

/// The signed-in employee is 1. "Today" is Thursday 22 October 2026, 13:00
/// in Brussels (UTC+2). Thursday: 08:00–16:30, a 30-minute break.
TestApp _app() {
  final app = TestApp(devUserId: 1, activeUserIds: {1})..now = DateTime.utc(2026, 10, 22, 11);
  app.schedules.days = const [(id: 1, name: 'Monday'), (id: 4, name: 'Thursday')];
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

Future<MyDay> _today(TestApp app) async {
  final response = await app.get('/me/today');
  expect(response.statusCode, 200);
  return MyDay.fromJson(await jsonBody(response));
}

void main() {
  test('before the first registration ever: first day, with today\'s schedule', () async {
    final today = await _today(_app());

    expect((today.date, today.firstDay, today.scheduledStart, today.scheduledFinish, today.breakMinutes, today.day), (
      DateTime.utc(2026, 10, 22),
      true,
      '08:00',
      '16:30',
      30,
      null,
    ));
    expect((today.breakStart, today.breakFinish), ('12:00', '12:30'), reason: 'when the break is deducted during the day');
  });

  test('not started today after earlier days: not a first day', () async {
    final app = _app();
    app.timeRecords.rows = [_row(1, 'Start – actual – Manual', DateTime.utc(2026, 10, 21, 6))];

    final today = await _today(app);

    expect((today.firstDay, today.day), (false, null));
  });

  test('working: the day as HR sees it, no registered total yet', () async {
    final app = _app();
    app.timeRecords.rows = [
      _row(1, 'Start – actual – Manual', DateTime.utc(2026, 10, 22, 6, 4)),
      _row(1, 'Start – rounded', DateTime.utc(2026, 10, 22, 6, 4)),
    ];

    final today = await _today(app);

    expect((today.day!.status, today.day!.start!.actualLocal, today.registeredMinutes), (TimeRecordStatus.working, '08:04', null));
  });

  test('a finished day: rounded finish − rounded start − break (D13)', () async {
    final app = _app();
    app.timeRecords.rows = [
      _row(1, 'Start – actual – Manual', DateTime.utc(2026, 10, 22, 6, 4)),
      _row(1, 'Start – rounded', DateTime.utc(2026, 10, 22, 6, 15)),
      _row(1, 'Finish – actual – Manual', DateTime.utc(2026, 10, 22, 10, 41)),
      _row(1, 'Finish – rounded', DateTime.utc(2026, 10, 22, 10, 30)),
    ];

    final today = await _today(app);

    expect((today.day!.status, today.registeredMinutes), (TimeRecordStatus.complete, 4 * 60 + 15 - 30));
  });

  test('a correction waiting for HR: shown as pending, no total until HR approves (D31)', () async {
    final app = _app();
    app.timeRecords.rows = [
      _row(1, 'Start – actual – Manual', DateTime.utc(2026, 10, 22, 6, 4), manual: true, comment: 'Forgot to register'),
      _row(1, 'Finish – actual – Manual', DateTime.utc(2026, 10, 22, 10, 41)),
      _row(1, 'Finish – rounded', DateTime.utc(2026, 10, 22, 10, 41)),
    ];

    final today = await _today(app);

    expect((today.day!.status, today.day!.pending.single.requestedLocal, today.registeredMinutes), (
      TimeRecordStatus.pendingReview,
      '08:04',
      null,
    ));
  });

  test('no schedule today: no times, the day still shows', () async {
    final app = _app()..now = DateTime.utc(2026, 10, 24, 11);

    final today = await _today(app);

    expect((today.date, today.scheduledStart, today.scheduledFinish, today.breakMinutes), (DateTime.utc(2026, 10, 24), null, null, null));
  });

  test('only the signed-in employee: another employee\'s rows never show', () async {
    final app = _app();
    app.timeRecords.rows = [_row(2, 'Start – actual – QR', DateTime.utc(2026, 10, 22, 6))];

    final today = await _today(app);

    expect((today.day, today.firstDay), (null, true));
  });

  group('period (GET /me/period)', () {
    Future<MyPeriod> period(TestApp app, String from, String to) async {
      final response = await app.get('/me/period?from=$from&to=$to');
      expect(response.statusCode, 200);
      return MyPeriod.fromJson(await jsonBody(response));
    }

    test('every day of the week, planned from the schedule, registered once finished', () async {
      final app = _app()..now = DateTime.utc(2026, 10, 23, 11);
      app.schedules.days = const [(id: 4, name: 'Thursday'), (id: 5, name: 'Friday')];
      app.schedules.userSchedules = [
        for (final day in [4, 5])
          for (final (id, type, sh, sm, eh, em) in [
            (10 + day, 'Work – start', 8, 0, 16, 30),
            (20 + day, 'Work – finish', 8, 0, 16, 30),
            (30 + day, 'Break', 12, 0, 12, 30),
          ])
            (userId: 1, scheduleId: id, typeName: type, dayId: day, startHour: sh, startMinute: sm, stopHour: eh, stopMinute: em, marginMinutes: 0),
      ];
      app.timeRecords.rows = [
        _row(1, 'Start – actual – Manual', DateTime.utc(2026, 10, 22, 6)),
        _row(1, 'Start – rounded', DateTime.utc(2026, 10, 22, 6)),
        _row(1, 'Finish – actual – Manual', DateTime.utc(2026, 10, 22, 14)),
        _row(1, 'Finish – rounded', DateTime.utc(2026, 10, 22, 14)),
      ];

      final week = await period(app, '2026-10-19', '2026-10-25');

      expect(week.days, hasLength(7));
      expect([for (final d in week.days) d.plannedMinutes], [null, null, null, 480, 480, null, null], reason: 'Thu, Fri: 8h30 − 30 min');
      expect(week.days[3].registeredMinutes, 7 * 60 + 30, reason: 'Thursday 08:00–16:00 minus the break');
      expect(week.days[3].day!.status, TimeRecordStatus.complete);
      expect((week.plannedMinutes, week.registeredMinutes), (960, 450));
      expect(week.days[4].day, isNull, reason: 'today, nothing registered yet');
    });

    test('400 for a malformed, reversed or too long period', () async {
      final app = _app();
      expect((await app.get('/me/period?from=2026-10-19')).statusCode, 400);
      expect((await app.get('/me/period?from=2026-10-25&to=2026-10-19')).statusCode, 400);
      expect((await app.get('/me/period?from=2026-01-01&to=2026-12-31')).statusCode, 400);
    });
  });

  test('401 without an identity', () async {
    final app = TestApp(devUserId: null);
    expect((await app.get('/me/today')).statusCode, 401);
  });
}
