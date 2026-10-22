import 'dart:convert';

import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _path = '/me/time-registrations';

/// Thursday 22 October 2026: Brussels is UTC+2 (summer time ends on 25
/// October).
TestApp _app({bool withSchedule = true}) {
  final app = TestApp(devUserId: 9, activeUserIds: {9})..now = DateTime.utc(2026, 10, 26, 18);
  app.schedules.days = const [(id: 1, name: 'Monday'), (id: 4, name: 'Thursday')];
  if (withSchedule) {
    app.schedules.userSchedules = [
      for (final (scheduleId, dayId, type) in [
        (11, 4, 'Work – start'),
        (12, 4, 'Work – finish'),
        (21, 1, 'Work – start'),
        (22, 1, 'Work – finish'),
      ])
        (
          userId: 9,
          scheduleId: scheduleId,
          typeName: type,
          dayId: dayId,
          startHour: 8,
          startMinute: 0,
          stopHour: 16,
          stopMinute: 30,
          marginMinutes: 0,
        ),
    ];
    // Start: up every 15 minutes; finish: down every 15 minutes.
    app.schedules.rules = const [
      (scheduleId: 11, intervalMinutes: 15, roundUp: true),
      (scheduleId: 12, intervalMinutes: 15, roundUp: false),
      (scheduleId: 21, intervalMinutes: 15, roundUp: true),
      (scheduleId: 22, intervalMinutes: 15, roundUp: false),
    ];
  }
  return app;
}

String _body({
  String boundary = 'start',
  String method = 'manual',
  String entry = 'now',
  String at = '2026-10-22T06:04:37Z',
  Object? reason,
}) =>
    jsonEncode({'boundary': boundary, 'method': method, 'entry': entry, 'at': at, 'reason': reason});

Future<Map<String, Object?>> _error(TestApp app, String body) async {
  final response = await app.post(_path, body);
  return {'status': response.statusCode, ...(await jsonBody(response))['error']! as Map<String, Object?>};
}

void main() {
  test('201: stores the actual time and the time rounded with the day\'s rule, in one audited transaction', () async {
    final app = _app();

    final response = await app.post(_path, _body());

    expect(response.statusCode, 201);
    final registered = RegisteredTime.fromJson(await jsonBody(response));
    // 06:04 UTC = 08:04 in Brussels; up every 15 → 08:15 = 06:15 UTC.
    expect(registered.actualAt, DateTime.utc(2026, 10, 22, 6, 4, 37));
    expect(registered.roundedAt, DateTime.utc(2026, 10, 22, 6, 15));

    final [actual, rounded] = app.timeRegistrationWrites.rows;
    expect((actual.userId, actual.typeId, actual.at, actual.manualEntry, actual.comment), (
      9,
      4,
      DateTime.utc(2026, 10, 22, 6, 4, 37),
      false,
      null,
    ));
    expect((rounded.typeId, rounded.at, rounded.manualEntry, rounded.comment), (8, DateTime.utc(2026, 10, 22, 6, 15), false, null));
    expect((registered.actualId, registered.roundedId), (actual.id, rounded.id));
    expect(app.timeRegistrationWrites.locked, [9]);
    expect(app.transactions.outcomes, ['commit']);
    final event = app.audit.events.single;
    expect(event.type, AuditEventType.timeRegistered);
    expect(event.actorUserId, 9);
    expect(event.references, {EventLogReference.user: 9, EventLogReference.timeReg: actual.id, EventLogReference.timeRegType: 4});
  });

  test('a finish is rounded with the finish rule (down)', () async {
    final app = _app();

    final response = await app.post(_path, _body(boundary: 'finish', at: '2026-10-22T14:41:00Z'));

    final registered = RegisteredTime.fromJson(await jsonBody(response));
    // 16:41 local, down every 15 → 16:30 = 14:30 UTC.
    expect(registered.roundedAt, DateTime.utc(2026, 10, 22, 14, 30));
    expect([for (final r in app.timeRegistrationWrites.rows) r.typeId], [7, 9]);
  });

  test('rounding follows local time across the switch to winter time', () async {
    final app = _app();

    // Monday 26 October: Brussels is UTC+1. 07:04 UTC = 08:04 local → 08:15 = 07:15 UTC.
    final response = await app.post(_path, _body(at: '2026-10-26T07:04:00Z'));

    expect(RegisteredTime.fromJson(await jsonBody(response)).roundedAt, DateTime.utc(2026, 10, 26, 7, 15));
  });

  test('no schedule that day: the rounded time is the actual time in whole minutes', () async {
    final app = _app(withSchedule: false);

    final response = await app.post(_path, _body());

    expect(RegisteredTime.fromJson(await jsonBody(response)).roundedAt, DateTime.utc(2026, 10, 22, 6, 4));
  });

  test('an offset other than Z is the same moment', () async {
    final app = _app();

    final response = await app.post(_path, _body(at: '2026-10-22T08:04:37+02:00'));

    expect(RegisteredTime.fromJson(await jsonBody(response)).actualAt, DateTime.utc(2026, 10, 22, 6, 4, 37));
  });

  test('a retry adds nothing and returns the stored pair (200)', () async {
    final app = _app();
    final first = RegisteredTime.fromJson(await jsonBody(await app.post(_path, _body())));

    final again = await app.post(_path, _body());

    expect(again.statusCode, 200);
    final second = RegisteredTime.fromJson(await jsonBody(again));
    expect((second.actualId, second.roundedId, second.roundedAt), (first.actualId, first.roundedId, first.roundedAt));
    expect(app.timeRegistrationWrites.rows, hasLength(2));
    expect(app.audit.events, hasLength(1));
  });

  test('D31: a corrected time waits for HR: only its actual row, no rounded row, audited as a request', () async {
    final app = _app();

    final response = await app.post(_path, _body(entry: 'corrected', reason: 'Forgot my phone'));

    expect(response.statusCode, 201);
    final registered = RegisteredTime.fromJson(await jsonBody(response));
    expect((registered.isPending, registered.roundedAt), (true, null));
    final actual = app.timeRegistrationWrites.rows.single;
    expect((actual.typeId, actual.manualEntry, actual.comment), (4, true, 'Forgot my phone'));
    expect(app.audit.events.single.type, AuditEventType.timeCorrectionRequested);

    final again = await app.post(_path, _body(entry: 'corrected', reason: 'Forgot my phone'));
    expect(again.statusCode, 200, reason: 'a retry adds nothing');
    expect(RegisteredTime.fromJson(await jsonBody(again)).actualId, actual.id);
    expect(app.timeRegistrationWrites.rows, hasLength(1));
  });

  test('D30: tapped when it happens needs no reason and is not a manual entry', () async {
    final app = _app();

    final response = await app.post(_path, _body(entry: 'now', reason: null));

    expect(response.statusCode, 201);
    final actual = app.timeRegistrationWrites.rows.first;
    expect((actual.manualEntry, actual.comment), (false, null));
  });

  test('D30: the first-day arrival needs no reason, is a manual entry, and only while nothing is registered', () async {
    final app = _app();

    final first = await app.post(_path, _body(entry: 'first_day', reason: null));
    expect(first.statusCode, 201);
    expect(app.timeRegistrationWrites.rows.first.manualEntry, isTrue);

    final again = await _error(app, _body(entry: 'first_day', at: '2026-10-22T06:30:00Z', reason: null));
    expect(again, containsPair('status', 400));
    expect(again, containsPair('field', 'entry'));
  });

  test('D30: a corrected time needs a reason of at most 500 characters', () async {
    for (final reason in [null, '   ', 'x' * (RegisterTimeRequest.maxReasonLength + 1)]) {
      final app = _app();
      final error = await _error(app, _body(entry: 'corrected', reason: reason));
      expect(error, containsPair('status', 400), reason: '$reason');
      expect(error, containsPair('field', 'reason'));
      expect(app.timeRegistrationWrites.rows, isEmpty);
    }
  });

  test('a time in the future is refused; a phone clock a little ahead is fine', () async {
    final app = _app()..now = DateTime.utc(2026, 10, 22, 6, 3);

    expect((await app.post(_path, _body(at: '2026-10-22T06:04:59Z'))).statusCode, 201, reason: 'within 2 minutes');
    final error = await _error(app, _body(at: '2026-10-22T06:06:00Z'));
    expect(error, containsPair('status', 400));
    expect(error, containsPair('field', 'at'));
  });

  test('400 for a time without offset, an unknown boundary or method', () async {
    final app = _app();
    for (final body in [
      _body(at: '2026-10-22T06:04:00'),
      _body(boundary: 'pause'),
      _body(method: 'geofence'),
      _body(entry: 'later'),
    ]) {
      expect((await app.post(_path, body)).statusCode, 400, reason: body);
    }
    expect(app.timeRegistrationWrites.rows, isEmpty);
  });

  test('two start schedules on one day is a configuration error, not a guess; nothing is written', () async {
    final app = _app();
    app.schedules.userSchedules = [
      ...app.schedules.userSchedules,
      (userId: 9, scheduleId: 13, typeName: 'Work – start', dayId: 4, startHour: 9, startMinute: 0, stopHour: 17, stopMinute: 0, marginMinutes: 0),
    ];

    final error = await _error(app, _body());

    expect(error['status'], 409);
    expect(error['code'], 'configuration_error');
    expect(app.timeRegistrationWrites.rows, isEmpty);
  });
}
