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

var _id = 0;
RegistrationRow _row(String type, DateTime at, {int userId = 11, bool manual = false, String? comment, bool active = true}) =>
    (id: ++_id, userId: userId, typeName: type, at: at, manualEntry: manual, comment: comment, active: active);

/// October: Brussels is UTC+2 until the 25th.
List<RegistrationRow> _day(int date, {int userId = 11}) => [
  _row('Start – actual – Manual', DateTime.utc(2026, 10, date, 6), userId: userId),
  _row('Start – rounded', DateTime.utc(2026, 10, date, 6), userId: userId),
  _row('Finish – actual – Manual', DateTime.utc(2026, 10, date, 14, 30), userId: userId),
  _row('Finish – rounded', DateTime.utc(2026, 10, date, 14, 30), userId: userId),
];

/// Company 7 with employee 11, who works Monday and Thursday 08:00–16:30 with
/// a 30-minute break. "Now" is Friday 23 October 2026.
TestApp _app() {
  final app = TestApp()..now = DateTime.utc(2026, 10, 23, 10);
  app.companies.existingIds = {7};
  app.companies.companies = [company(7, 'Almeco')];
  app.employees.byCompany = {
    7: [_employee(11, 'Emma', 'Janssens', 'EJA')],
  };
  app.schedules.days = const [(id: 1, name: 'Monday'), (id: 4, name: 'Thursday')];
  app.schedules.userSchedules = [
    for (final dayId in [1, 4])
      for (final (id, type, sh, sm, eh, em) in [
        (dayId * 10 + 1, 'Work – start', 8, 0, 16, 30),
        (dayId * 10 + 2, 'Work – finish', 8, 0, 16, 30),
        (dayId * 10 + 3, 'Break', 12, 0, 12, 30),
      ])
        (userId: 11, scheduleId: id, typeName: type, dayId: dayId, startHour: sh, startMinute: sm, stopHour: eh, stopMinute: em, marginMinutes: 0),
  ];
  return app;
}

Future<HoursReportEmployee> _emma(TestApp app, {String month = '2026-10'}) async {
  final response = await app.get('/reports/hours?month=$month');
  expect(response.statusCode, 200);
  return HoursReport.fromJson(await jsonBody(response)).employees.single;
}

void main() {
  test('planned up to today, registered from finished days, and the difference', () async {
    final app = _app();
    // Mondays 5, 12, 19; Thursdays 1, 8, 15, 22: seven planned days so far.
    app.timeRecords.rows = _day(19);

    final emma = await _emma(app);

    expect(emma.plannedMinutes, 7 * 480);
    expect(emma.registeredMinutes, 480);
    expect(emma.differenceMinutes, -6 * 480);
  });

  test('the month of a past month counts every planned day', () async {
    final app = _app()..now = DateTime.utc(2026, 11, 20, 10);

    expect((await _emma(app)).plannedMinutes, 9 * 480, reason: 'nine Mondays and Thursdays in October');
  });

  test('a missing finish and a correction waiting are to review, and not in Registered', () async {
    final app = _app();
    app.timeRecords.rows = [
      ..._day(15),
      _row('Start – actual – Manual', DateTime.utc(2026, 10, 19, 6)),
      _row('Start – rounded', DateTime.utc(2026, 10, 19, 6)),
      ..._day(22),
      _row('Finish – actual – Manual', DateTime.utc(2026, 10, 22, 15), manual: true, comment: 'Forgot'),
    ];

    final emma = await _emma(app);

    expect(emma.daysToReview, 2);
    expect(emma.registeredMinutes, 480);
    expect(emma.days.map((d) => (d.date.day, d.status)), [
      (22, TimeRecordStatus.pendingReview),
      (19, TimeRecordStatus.missingFinish),
      (15, TimeRecordStatus.complete),
    ], reason: 'newest first');
  });

  test('a scheduled day without registration, after the first one, is to review', () async {
    final app = _app();
    app.timeRecords.rows = [..._day(15), ..._day(22)];

    final emma = await _emma(app);

    expect(emma.days.where((d) => d.status == TimeRecordStatus.noRegistration).map((d) => d.date.day), [19]);
    expect(emma.daysToReview, 1);
  });

  test('a non-work day is neither planned nor to review', () async {
    final app = _app();
    app.timeRecords.rows = [
      ..._day(15),
      _row('Start – actual – Manual', DateTime.utc(2026, 10, 19, 6), active: false),
      _row('Start – rounded', DateTime.utc(2026, 10, 19, 6), active: false, comment: 'Sick'),
      ..._day(22),
    ];

    final emma = await _emma(app);

    expect(emma.plannedMinutes, 6 * 480);
    expect(emma.daysToReview, 0);
  });

  test('time away comes with the day, and replaces its break (D34)', () async {
    final app = _app();
    app.timeRecords.rows = [
      _row('Start – actual – Geofence', DateTime.utc(2026, 10, 22, 6)),
      _row('Start – rounded', DateTime.utc(2026, 10, 22, 6)),
      _row('Finish – actual – Geofence', DateTime.utc(2026, 10, 22, 11)),
      _row('Finish – rounded', DateTime.utc(2026, 10, 22, 11)),
      _row('Start – actual – Geofence', DateTime.utc(2026, 10, 22, 13)),
      _row('Start – rounded', DateTime.utc(2026, 10, 22, 13)),
      _row('Finish – actual – Geofence', DateTime.utc(2026, 10, 22, 15)),
      _row('Finish – rounded', DateTime.utc(2026, 10, 22, 15)),
    ];

    final emma = await _emma(app);
    final day = emma.days.first;

    expect((day.awayMinutes, day.registeredMinutes, day.start, day.finish), (120, 7 * 60, '08:00', '17:00'));
  });

  test('an employee with neither a schedule nor a day that month is left out', () async {
    final app = _app();
    app.employees.byCompany = {
      7: [_employee(11, 'Emma', 'Janssens', 'EJA'), _employee(12, 'Noor', 'Peeters', 'NPE')],
    };

    final report = HoursReport.fromJson(await jsonBody(await app.get('/reports/hours?month=2026-10')));

    expect(report.employees.map((e) => e.code), ['EJA']);
  });

  group('checks', () {
    for (final month in ['', '2026', '2026-13', '2026-00', '26-10', "2026-10' OR '1'='1"]) {
      test('month "$month" → 400 on month', () async {
        final response = await _app().get('/reports/hours?month=${Uri.encodeComponent(month)}');

        expect(response.statusCode, 400);
      });
    }

    test('an unknown company is 404', () async {
      expect((await _app().get('/reports/hours?month=2026-10&company=99')).statusCode, 404);
    });

    test('needs viewReports in the company asked for', () async {
      final app = TestApp(allowPermissions: false);
      app.companies.existingIds = {7};

      final response = await app.get('/reports/hours?month=2026-10&company=7');

      expect(response.statusCode, 403);
      expect(app.permissions.checked.map((c) => (c.$2, c.$3)), contains((Permission.viewReports, 7)));
    });

    test('without a company: only companies the viewer may see', () async {
      final app = _app();
      app.companies.companies = [company(7, 'Almeco'), company(8, 'PCA')];
      app.employees.byCompany = {
        ...app.employees.byCompany,
        8: [_employee(21, 'Other', 'Company', 'OCO')],
      };
      app.schedules.userSchedules = [
        for (final s in app.schedules.userSchedules) (userId: 21, scheduleId: s.scheduleId + 100, typeName: s.typeName, dayId: s.dayId, startHour: s.startHour, startMinute: s.startMinute, stopHour: s.stopHour, stopMinute: s.stopMinute, marginMinutes: s.marginMinutes),
        ...app.schedules.userSchedules,
      ];
      app.permissions.deniedCompanies = {7};

      final report = HoursReport.fromJson(await jsonBody(await app.get('/reports/hours?month=2026-10')));

      expect(report.employees.map((e) => e.code), ['OCO'], reason: 'nothing from company 7');
    });

    test('a session is required', () async {
      expect((await TestApp(devUserId: null).get('/reports/hours?month=2026-10')).statusCode, 401);
    });
  });
}
