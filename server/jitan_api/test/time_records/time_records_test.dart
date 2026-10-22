import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_api/src/time_records/time_record_repository.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

EmployeeSummary _employee(int id, String first, String last, String code) => EmployeeSummary(
  id: id,
  firstName: first,
  lastName: last,
  code: code,
  groups: const [],
  isActive: true,
  isActivated: true,
);

final _disan = _employee(1, 'Disan', 'Ssebowa', 'SBW');
final _kevin = _employee(2, 'Kevin', 'De Vos', 'KDV');
final _pca = _employee(3, 'Pia', 'Claes', 'PCL');

var _id = 0;
RegistrationRow _row(
  int userId,
  String type,
  DateTime at, {
  bool manual = false,
  String? comment,
  bool active = true,
}) => (id: ++_id, userId: userId, typeName: type, at: at, manualEntry: manual, comment: comment, active: active);

/// "Today" is Thursday 22 October 2026, 15:00 in Brussels (UTC+2).
TestApp _app({bool allow = true}) {
  final app = TestApp(devUserId: 9, activeUserIds: {9}, allowPermissions: allow)..now = DateTime.utc(2026, 10, 22, 13);
  app.companies.existingIds = {7, 8};
  app.companies.companies = [company(7, 'Almeco'), company(8, 'PCA')];
  app.employees.byCompany = {
    7: [_disan, _kevin],
    8: [_pca],
  };
  return app;
}

Future<List<TimeRecordDay>> _days(TestApp app, String query) async {
  final response = await app.get('/time-records?$query');
  expect(response.statusCode, 200, reason: query);
  return TimeRecordList.fromJson(await jsonBody(response)).days;
}

void main() {
  test('a complete day: first start and last finish, each with its rounded time, method and correction', () async {
    final app = _app();
    app.timeRecords.rows = [
      _row(1, 'Start – actual – QR', DateTime.utc(2026, 10, 21, 6, 4)),
      _row(1, 'Start – rounded', DateTime.utc(2026, 10, 21, 6, 15)),
      _row(1, 'Finish – actual – Manual', DateTime.utc(2026, 10, 21, 14, 41)),
      _row(1, 'Finish – rounded', DateTime.utc(2026, 10, 21, 14, 30)),
    ];

    final [day] = await _days(app, 'from=2026-10-19&to=2026-10-25&company=7');

    expect((day.employeeId, day.firstName, day.employeeCode, day.date, day.status), (
      1,
      'Disan',
      'SBW',
      DateTime.utc(2026, 10, 21),
      TimeRecordStatus.complete,
    ));
    expect((day.start!.actual, day.start!.rounded, day.start!.method, day.start!.enteredByHand), (
      DateTime.utc(2026, 10, 21, 6, 4),
      DateTime.utc(2026, 10, 21, 6, 15),
      TimeRecordMethod.qr,
      false,
    ));
    expect((day.start!.actualLocal, day.start!.roundedLocal), ('08:04', '08:15'), reason: 'workplace time');
    expect((day.finish!.actual, day.finish!.rounded, day.finish!.method, day.finish!.enteredByHand, day.finish!.reason), (
      DateTime.utc(2026, 10, 21, 14, 41),
      DateTime.utc(2026, 10, 21, 14, 30),
      TimeRecordMethod.manual,
      false,
      null,
    ));
    expect([for (final e in day.events) (e.atLocal, e.kind, e.method)], [
      ('08:04', TimeRecordEventKind.registered, TimeRecordMethod.qr),
      ('16:41', TimeRecordEventKind.registered, TimeRecordMethod.manual),
    ], reason: 'the timeline: every start and finish of the day');
  });

  test('only a start: working today, missing finish on an earlier day; only a finish: missing start', () async {
    final app = _app();
    app.timeRecords.rows = [
      _row(1, 'Start – actual – Manual', DateTime.utc(2026, 10, 22, 6)),
      _row(1, 'Start – rounded', DateTime.utc(2026, 10, 22, 6)),
      _row(2, 'Start – actual – QR', DateTime.utc(2026, 10, 20, 6)),
      _row(2, 'Start – rounded', DateTime.utc(2026, 10, 20, 6)),
      _row(2, 'Finish – actual – QR', DateTime.utc(2026, 10, 21, 14)),
      _row(2, 'Finish – rounded', DateTime.utc(2026, 10, 21, 14)),
    ];

    final days = await _days(app, 'from=2026-10-19&to=2026-10-25');

    expect([for (final d in days) (d.employeeCode, TimeRecordDay.dateText(d.date), d.status)], [
      ('SBW', '2026-10-22', TimeRecordStatus.working),
      ('KDV', '2026-10-21', TimeRecordStatus.missingStart),
      ('KDV', '2026-10-20', TimeRecordStatus.missingFinish),
    ], reason: 'newest day first');
  });

  test('days are workplace-local: 00:30 in Brussels is the next day, though still the day before in UTC', () async {
    final app = _app();
    app.timeRecords.rows = [_row(1, 'Start – actual – QR', DateTime.utc(2026, 10, 20, 22, 30))];

    final [day] = await _days(app, 'from=2026-10-21&to=2026-10-21');

    expect(TimeRecordDay.dateText(day.date), '2026-10-21');
  });

  test('the period is read from local midnight to local midnight, across the winter-time switch', () async {
    final app = _app();

    await _days(app, 'from=2026-10-19&to=2026-10-25&company=7');

    final (_, from, to) = app.timeRecords.reads.single;
    expect(from, DateTime.utc(2026, 10, 18, 22), reason: '19 October 00:00 at UTC+2');
    expect(to, DateTime.utc(2026, 10, 25, 23), reason: '26 October 00:00 at UTC+1');
  });

  test('with a company: that company only, its right checked; without: every company the viewer may see', () async {
    final app = _app();
    app.timeRecords.rows = [
      _row(1, 'Start – actual – QR', DateTime.utc(2026, 10, 21, 6)),
      _row(3, 'Start – actual – QR', DateTime.utc(2026, 10, 21, 6)),
    ];

    expect([for (final d in await _days(app, 'from=2026-10-21&to=2026-10-21&company=7')) d.employeeCode], ['SBW']);
    expect(app.permissions.checked.last, (9, Permission.viewTimeRegistrations, 7));

    app.permissions.deniedCompanies = {8};
    expect([for (final d in await _days(app, 'from=2026-10-21&to=2026-10-21')) d.employeeCode], ['SBW']);
    app.permissions.deniedCompanies = {};
    expect([for (final d in await _days(app, 'from=2026-10-21&to=2026-10-21')) d.employeeCode], ['PCL', 'SBW'], reason: 'by last name');
  });

  test('403 for a company without the right; 404 for an unknown company', () async {
    expect((await _app(allow: false).get('/time-records?from=2026-10-21&to=2026-10-21&company=7')).statusCode, 403);
    expect((await _app().get('/time-records?from=2026-10-21&to=2026-10-21&company=99')).statusCode, 404);
  });

  test('400 for a missing or malformed date, a reversed or too long period', () async {
    final app = _app();
    for (final query in [
      'to=2026-10-21',
      'from=2026-10-21',
      'from=21-10-2026&to=2026-10-21',
      'from=2026-10-22&to=2026-10-21',
      'from=2026-01-01&to=2026-03-31',
    ]) {
      expect((await app.get('/time-records?$query')).statusCode, 400, reason: query);
    }
  });
}
