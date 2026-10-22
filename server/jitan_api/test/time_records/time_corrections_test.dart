import 'dart:convert';

import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_api/src/time_records/time_record_repository.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

const _disan = EmployeeSummary(
  id: 1,
  firstName: 'Disan',
  lastName: 'Ssebowa',
  code: 'SBW',
  groups: [],
  isActive: true,
  isActivated: true,
);

var _id = 0;
RegistrationRow _row(String type, DateTime at, {bool manual = false, String? comment, bool active = true}) =>
    (id: ++_id, userId: 1, typeName: type, at: at, manualEntry: manual, comment: comment, active: active);

/// "Today" is Friday 23 October 2026, 12:00 in Brussels (UTC+2); the day
/// corrected is Thursday 22 October. Thursday's schedule rounds the start up
/// and the finish down, every 15 minutes.
TestApp _app({bool allow = true}) {
  final app = TestApp(devUserId: 9, activeUserIds: {9}, allowPermissions: allow)..now = DateTime.utc(2026, 10, 23, 10);
  app.companies.existingIds = {7};
  app.companies.companies = [company(7, 'Almeco')];
  app.employees.byCompany = {7: [_disan]};
  app.employees.members = {(7, 1)};
  app.schedules.days = const [(id: 1, name: 'Monday'), (id: 4, name: 'Thursday')];
  app.schedules.userSchedules = [
    for (final (id, day, type) in [(11, 4, 'Work – start'), (12, 4, 'Work – finish'), (21, 1, 'Work – start')])
      (userId: 1, scheduleId: id, typeName: type, dayId: day, startHour: 8, startMinute: 0, stopHour: 16, stopMinute: 30, marginMinutes: 0),
  ];
  app.schedules.rules = const [
    (scheduleId: 11, intervalMinutes: 15, roundUp: true),
    (scheduleId: 12, intervalMinutes: 15, roundUp: false),
  ];
  return app;
}

const _base = '/companies/7/employees/1';

Future<TimeRecordDay?> _post(TestApp app, String path, Map<String, Object?> body, {int status = 200}) async {
  final response = await app.post('$_base$path', jsonEncode(body));
  expect(response.statusCode, status, reason: path);
  if (status != 200) return null;
  return TimeRecordList.fromJson(await jsonBody(response)).days.firstOrNull;
}

Future<TimeRecordDay> _day(TestApp app) async {
  final response = await app.get('/time-records?from=2026-10-22&to=2026-10-22&company=7');
  return TimeRecordList.fromJson(await jsonBody(response)).days.single;
}

void main() {
  group('an employee correction waits for HR (D31)', () {
    late TestApp app;
    late RegistrationRow request;

    setUp(() {
      app = _app();
      request = _row('Start – actual – Manual', DateTime.utc(2026, 10, 22, 6, 4), manual: true, comment: 'Forgot to tap');
      app.timeRecords.rows = [
        request,
        _row('Finish – actual – Manual', DateTime.utc(2026, 10, 22, 14, 41)),
        _row('Finish – rounded', DateTime.utc(2026, 10, 22, 14, 30)),
      ];
    });

    test('pending: it does not count; the day shows what it would count as after rounding', () async {
      final day = await _day(app);

      expect(day.status, TimeRecordStatus.pendingReview);
      expect(day.start, isNull, reason: 'not counted yet');
      final pending = day.pending.single;
      expect((pending.id, pending.boundary, pending.requestedLocal, pending.roundedLocal, pending.reason), (
        request.id,
        RegistrationBoundary.start,
        '08:04',
        '08:15',
        'Forgot to tap',
      ));
    });

    test('approve: HR\'s corrected time and its rounded time count; the request stays as history', () async {
      final day = await _post(app, '/time-registrations/${request.id}/approve', const {});

      expect(day!.status, TimeRecordStatus.corrected);
      expect(day.pending, isEmpty);
      expect((day.start!.actualLocal, day.start!.roundedLocal, day.start!.correctedBy, day.start!.reason), (
        '08:04',
        '08:15',
        TimeCorrectionBy.hr,
        'Forgot to tap',
      ));
      expect(app.timeRecords.rows.firstWhere((r) => r.id == request.id).active, isTrue);
      expect(app.audit.events.single.type, AuditEventType.timeCorrectionApproved);
      expect(app.audit.events.single.actorUserId, 9);
      expect(app.transactions.outcomes.last, 'commit');

      // Approving again: nothing is waiting any more.
      await _post(app, '/time-registrations/${request.id}/approve', const {}, status: 404);
    });

    test('reject: the request is switched off, kept, and the day is as before', () async {
      final day = await _post(app, '/time-registrations/${request.id}/reject', const {});

      expect(day!.status, TimeRecordStatus.missingStart);
      expect(app.timeRecords.rows.firstWhere((r) => r.id == request.id).active, isFalse);
      expect(day.events.first.kind, TimeRecordEventKind.rejected);
      expect(app.audit.events.single.type, AuditEventType.timeCorrectionRejected);
    });

    test('a day with only a pending correction can not be marked non-work (409)', () async {
      app.timeRecords.rows = [request];

      final response = await app.post('$_base/time-records/2026-10-22/non-work', jsonEncode({'reason': 'Holiday'}));

      expect(response.statusCode, 409);
      expect(((await jsonBody(response))['error']! as Map)['code'], ApiErrorCode.nothingToMarkNonWork);
    });
  });

  group('HR corrections (D7, D8)', () {
    test('correcting a start: a corrected row and its rounded row count; the old rounded row is switched off', () async {
      final app = _app();
      final oldRounded = _row('Start – rounded', DateTime.utc(2026, 10, 22, 6, 15));
      app.timeRecords.rows = [
        _row('Start – actual – Manual', DateTime.utc(2026, 10, 22, 6, 4)),
        oldRounded,
        _row('Finish – actual – Manual', DateTime.utc(2026, 10, 22, 14, 41)),
        _row('Finish – rounded', DateTime.utc(2026, 10, 22, 14, 30)),
      ];

      final day = await _post(app, '/time-records/2026-10-22/correct', {
        'boundary': 'start',
        'time': '07:58',
        'reason': 'Was at the gate before 08:00',
      });

      expect(day!.status, TimeRecordStatus.corrected);
      expect((day.start!.actualLocal, day.start!.roundedLocal, day.start!.originalLocal, day.start!.correctedBy), (
        '07:58',
        '08:00',
        '08:04',
        TimeCorrectionBy.hr,
      ));
      expect(app.timeRecords.rows.firstWhere((r) => r.id == oldRounded.id).active, isFalse, reason: 'kept, switched off');
      final event = app.audit.events.single;
      expect((event.type, event.actorUserId, event.references[EventLogReference.company]), (AuditEventType.timeCorrected, 9, 7));

      // A second correction replaces the first one; both stay as history.
      final again = await _post(app, '/time-records/2026-10-22/correct', {
        'boundary': 'start',
        'time': '08:00',
        'reason': 'Checked the camera',
      });
      expect(again!.start!.actualLocal, '08:00');
      expect(app.timeRecords.rows.where((r) => r.typeName == 'Start – corrected' && r.active), hasLength(1));
      expect(app.timeRecords.rows.where((r) => r.typeName == 'Start – corrected'), hasLength(2));
    });

    test('adding a missing finish completes the day', () async {
      final app = _app();
      app.timeRecords.rows = [
        _row('Start – actual – Manual', DateTime.utc(2026, 10, 22, 6)),
        _row('Start – rounded', DateTime.utc(2026, 10, 22, 6)),
      ];
      expect((await _day(app)).status, TimeRecordStatus.missingFinish);

      final day = await _post(app, '/time-records/2026-10-22/correct', {
        'boundary': 'finish',
        'time': '16:22',
        'reason': 'Employee confirmed with HR',
      });

      expect(day!.status, TimeRecordStatus.corrected);
      expect((day.finish!.actualLocal, day.finish!.roundedLocal, day.finish!.originalLocal), ('16:22', '16:15', null));
    });

    test('mark as non-work: every row switched off, the reason kept, the day shows non-work', () async {
      final app = _app();
      app.timeRecords.rows = [
        _row('Start – actual – Manual', DateTime.utc(2026, 10, 22, 6)),
        _row('Start – rounded', DateTime.utc(2026, 10, 22, 6)),
      ];

      final day = await _post(app, '/time-records/2026-10-22/non-work', {'reason': 'Confirmed non-working day'});

      expect((day!.status, day.nonWorkReason, day.start), (TimeRecordStatus.nonWork, 'Confirmed non-working day', null));
      expect(app.timeRecords.rows.every((r) => !r.active), isTrue);
      expect(day.events.single.kind, TimeRecordEventKind.nonWork);
      expect(app.audit.events.single.type, AuditEventType.timeMarkedNonWork);
    });

    test('400 for a missing reason, a time that is not HH:mm, or a time in the future', () async {
      final app = _app();
      for (final body in [
        {'boundary': 'start', 'time': '08:00', 'reason': '  '},
        {'boundary': 'start', 'time': '25:00', 'reason': 'x'},
        {'boundary': 'start', 'time': '8h', 'reason': 'x'},
      ]) {
        expect((await app.post('$_base/time-records/2026-10-22/correct', jsonEncode(body))).statusCode, 400, reason: '$body');
      }
      app.now = DateTime.utc(2026, 10, 22, 5);
      final future = {'boundary': 'start', 'time': '08:00', 'reason': 'x'};
      expect((await app.post('$_base/time-records/2026-10-22/correct', jsonEncode(future))).statusCode, 400);
      expect(app.timeRecords.rows, isEmpty);
    });

    test('403 without the right; 404 for an employee outside the company or another employee\'s row', () async {
      final noRight = _app(allow: false);
      final body = jsonEncode({'boundary': 'start', 'time': '08:00', 'reason': 'x'});
      expect((await noRight.post('$_base/time-records/2026-10-22/correct', body)).statusCode, 403);
      expect(noRight.permissions.checked.single.$2, Permission.correctTimeRegistrations);

      final app = _app();
      expect((await app.post('/companies/7/employees/2/time-records/2026-10-22/correct', body)).statusCode, 404);
      final other = (id: ++_id, userId: 2, typeName: 'Start – actual – Manual', at: DateTime.utc(2026, 10, 22, 6), manualEntry: true, comment: 'x', active: true);
      app.timeRecords.rows = [other];
      expect((await app.post('$_base/time-registrations/${other.id}/approve', '{}')).statusCode, 404);
    });
  });

  test('a past scheduled working day without any registration shows "No registration"', () async {
    final app = _app()..now = DateTime.utc(2026, 10, 22, 10);
    // First registration the week before; this week Monday has none.
    app.timeRecords.rows = [_row('Start – actual – Manual', DateTime.utc(2026, 10, 12, 6))];

    final response = await app.get('/time-records?from=2026-10-19&to=2026-10-25&company=7');

    final days = TimeRecordList.fromJson(await jsonBody(response)).days;
    expect([for (final d in days) (TimeRecordDay.dateText(d.date), d.status)], [('2026-10-19', TimeRecordStatus.noRegistration)],
        reason: 'Thursday 22 is today; other days have no schedule');
  });

  test('rounding preview: what a time would count as, nothing stored', () async {
    final app = _app();

    final response = await app.get('$_base/time-records/2026-10-22/rounding?boundary=finish&time=16:22');

    expect(response.statusCode, 200);
    expect(await jsonBody(response), {'rounded': '16:15'});
    expect(app.timeRecords.rows, isEmpty);
    expect((await app.get('$_base/time-records/2026-10-22/rounding?boundary=finish&time=x')).statusCode, 400);
  });
}
