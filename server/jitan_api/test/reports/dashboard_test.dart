import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_api/src/time_records/time_record_repository.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

var _id = 0;
RegistrationRow _row(int userId, String type, DateTime at, {bool manual = false, String? comment}) =>
    (id: ++_id, userId: userId, typeName: type, at: at, manualEntry: manual, comment: comment, active: true);

EmployeeSummary _employee(int id, String code, {bool activated = true, bool active = true}) => EmployeeSummary(
  id: id,
  firstName: 'First',
  lastName: code,
  code: code,
  groups: const [],
  isActive: active,
  isActivated: activated,
);

/// Local time in Brussels (UTC+2 before 25 October).
DateTime _at(int date, int hour, [int minute = 0]) => DateTime.utc(2026, 10, date, hour - 2, minute);

List<RegistrationRow> _start(int user, int date, int hour, [int minute = 0]) => [
  _row(user, 'Start – actual – Manual', _at(date, hour, minute)),
  _row(user, 'Start – rounded', _at(date, hour, minute)),
];

List<RegistrationRow> _finish(int user, int date, int hour, [int minute = 0]) => [
  _row(user, 'Finish – actual – Manual', _at(date, hour, minute)),
  _row(user, 'Finish – rounded', _at(date, hour, minute)),
];

/// Employees 11, 12 and 13 work Monday and Thursday 08:00–16:30, 30-minute
/// break, 5 minutes tolerance both ways. "Now" is Thursday 22 October, 13:00.
TestApp _app() {
  final app = TestApp()..now = _at(22, 13);
  app.companies.existingIds = {7};
  app.companies.companies = [company(7, 'Almeco', employees: 3)];
  app.employees.byCompany = {
    7: [_employee(11, 'AAA'), _employee(12, 'BBB'), _employee(13, 'CCC', activated: false)],
  };
  app.schedules.days = const [(id: 1, name: 'Monday'), (id: 4, name: 'Thursday')];
  app.schedules.userSchedules = [
    for (final userId in [11, 12, 13])
      for (final dayId in [1, 4])
        for (final (kind, type, sh, sm, eh, em, margin) in [
          (1, 'Work – start', 8, 0, 16, 30, 5),
          (2, 'Work – finish', 8, 0, 16, 30, 5),
          (3, 'Break', 12, 0, 12, 30, 0),
        ])
          (userId: userId, scheduleId: userId * 100 + dayId * 10 + kind, typeName: type, dayId: dayId, startHour: sh, startMinute: sm, stopHour: eh, stopMinute: em, marginMinutes: margin),
  ];
  return app;
}

Future<Dashboard> _dashboard(TestApp app, {String from = '2026-10-19', String to = '2026-10-22'}) async {
  final response = await app.get('/dashboard?from=$from&to=$to');
  expect(response.statusCode, 200);
  return Dashboard.fromJson(await jsonBody(response));
}

void main() {
  test('today: working, finished and not started, whatever the period', () async {
    final app = _app();
    app.timeRecords.rows = [..._start(11, 22, 8), ..._start(12, 22, 7), ..._finish(12, 22, 12)];

    final d = await _dashboard(app, from: '2026-10-05', to: '2026-10-06');

    expect((d.working, d.finished, d.notStarted), (1, 1, 1));
  });

  test('a day off is not "not started"', () async {
    final app = _app()..now = _at(23, 10);

    final d = await _dashboard(app);

    expect(d.notStarted, 0, reason: 'nobody is scheduled on Friday');
  });

  test('totals: each employee once, set-up counted, and companies from the server', () async {
    final app = _app();
    app.companies.existingIds = {7, 8};
    app.companies.companies = [company(7, 'Almeco', employees: 3), company(8, 'PCA', employees: 1)];
    app.employees.byCompany = {...app.employees.byCompany, 8: [_employee(11, 'AAA')]};

    final d = await _dashboard(app);

    expect((d.employees, d.employeesSetUp, d.employeesNotSetUp), (3, 2, 1));
    expect(d.companies.map((c) => (c.name, c.employees)), [('Almeco', 3), ('PCA', 1)]);
  });

  test('an inactive company and a deactivated employee are not in the totals or today', () async {
    final app = _app();
    app.companies.existingIds = {7, 8};
    app.companies.companies = [company(7, 'Almeco', employees: 3), company(8, 'PCA', employees: 1, active: false)];
    app.employees.byCompany = {
      7: [_employee(11, 'AAA'), _employee(12, 'BBB', active: false)],
      8: [_employee(21, 'OCO')],
    };

    final d = await _dashboard(app);

    expect(d.companies.map((c) => c.name), ['Almeco']);
    expect((d.employees, d.notStarted), (1, 1));
  });

  test('hours: only up to today, each day with its plan; a running day has no hours yet', () async {
    final app = _app();
    app.timeRecords.rows = [..._start(11, 19, 8), ..._finish(11, 19, 16, 30), ..._start(11, 22, 8)];

    final d = await _dashboard(app, from: '2026-10-19', to: '2026-10-25');

    expect(d.registeredMinutes, 480);
    expect(d.plannedMinutes, 6 * 480, reason: 'three employees, Monday and Thursday, none of the days to come');
    expect(d.buckets.first.registeredMinutes, 480);
    expect(d.buckets, hasLength(7));
    expect(d.bucketSize, DashboardBucketSize.day);
  });

  test('locations: the workplaces with a pin, as the Locations page lists them; not project sites', () async {
    final app = _app();
    Location place(int id, {bool active = true, GeoPoint? point = const GeoPoint(latitude: 50.7, longitude: 3.2)}) =>
        Location(id: id, name: 'Place $id', street: 'Street', point: point, radiusMeters: 100, isActive: active);
    app.locations.locations.addAll({
      1: place(1),
      2: place(2, active: false),
      3: place(3, point: null),
      4: place(4),
    });
    app.locations.projectIds.add(4);

    expect((await _dashboard(app)).locations, 1);
  });

  test('travel: next to the worked hours and never part of them (D46)', () async {
    final app = _app();
    app.timeRecords.rows = [
      ..._start(11, 19, 8),
      _row(11, 'Activity – Transport', _at(19, 8, 10)),
      _row(11, 'Activity – Client on site', _at(19, 9)),
      ..._finish(11, 19, 16, 30),
    ];

    final d = await _dashboard(app, from: '2026-10-19', to: '2026-10-25');

    expect(d.travelMinutes, 50);
    expect(d.registeredMinutes, 480 - 50, reason: 'worked leaves travel out, as in Reports');
  });

  group('attendance (D11b)', () {
    Future<Dashboard> withDay(List<RegistrationRow> rows) async {
      final app = _app();
      app.timeRecords.rows = rows;
      return _dashboard(app, from: '2026-10-19', to: '2026-10-19');
    }

    test('within the tolerance is on time, by the actual time', () async {
      final d = await withDay([..._start(11, 19, 8, 5), ..._finish(11, 19, 16, 25)]);

      expect((d.onTime, d.late, d.leftEarly), (1, 0, 0));
    });

    test('after the tolerance is late', () async {
      final d = await withDay([..._start(11, 19, 8, 6), ..._finish(11, 19, 16, 30)]);

      expect((d.onTime, d.late), (0, 1));
    });

    test('leaving before the tolerance is left early', () async {
      final d = await withDay([..._start(11, 19, 8), ..._finish(11, 19, 16)]);

      expect(d.leftEarly, 1);
    });

    test('late and left early counts once, as late', () async {
      final d = await withDay([..._start(11, 19, 9), ..._finish(11, 19, 15)]);

      expect((d.late, d.leftEarly), (1, 0));
    });

    test('a day with no schedule is not counted', () async {
      final app = _app();
      app.timeRecords.rows = [..._start(11, 20, 8), ..._finish(11, 20, 16)];

      final d = await _dashboard(app, from: '2026-10-20', to: '2026-10-20');

      expect((d.onTime, d.late, d.leftEarly, d.toReview), (0, 0, 0, 0));
    });

    test('a missing finish is to review, like Reports', () async {
      final d = await withDay(_start(11, 19, 8));

      expect((d.toReview, d.onTime), (1, 0));
    });
  });

  test('corrections waiting count whatever the period', () async {
    final app = _app();
    app.timeRecords.rows = [
      ..._start(11, 19, 8),
      _row(11, 'Finish – actual – Manual', _at(19, 16), manual: true, comment: 'Forgot'),
    ];

    final d = await _dashboard(app, from: '2026-10-05', to: '2026-10-06');

    expect(d.correctionsWaiting, 1);
  });

  group('long periods get wider bars', () {
    test('35 days: per day', () async {
      expect((await _dashboard(_app(), from: '2026-09-01', to: '2026-10-05')).bucketSize, DashboardBucketSize.day);
    });

    test('36 days: per week, Monday to Sunday, cut at the ends', () async {
      final d = await _dashboard(_app(), from: '2026-09-01', to: '2026-10-06');

      expect(d.bucketSize, DashboardBucketSize.week);
      expect((d.buckets.first.from, d.buckets.first.to), (DateTime.utc(2026, 9, 1), DateTime.utc(2026, 9, 6)));
      expect(d.buckets.last.to, DateTime.utc(2026, 10, 6));
    });

    test('a year: per month', () async {
      final d = await _dashboard(_app(), from: '2026-01-01', to: '2026-10-22');

      expect(d.bucketSize, DashboardBucketSize.month);
      expect(d.buckets, hasLength(10));
    });
  });

  group('checks', () {
    for (final (from, to) in [('', '2026-10-22'), ('2026-10-22', 'x'), ('2026-10-22', '2026-10-21'), ('2025-01-01', '2026-10-22')]) {
      test('from "$from" to "$to" → 400', () async {
        expect((await _app().get('/dashboard?from=$from&to=$to')).statusCode, 400);
      });
    }

    test('only companies the viewer may see', () async {
      final app = _app();
      app.companies.existingIds = {7, 8};
      app.companies.companies = [company(7, 'Almeco', employees: 3), company(8, 'PCA', employees: 1)];
      app.employees.byCompany = {...app.employees.byCompany, 8: [_employee(21, 'OCO')]};
      app.permissions.deniedCompanies = {7};

      final d = await _dashboard(app);

      expect(d.companies.map((c) => c.name), ['PCA']);
      expect(d.employees, 1);
      expect(app.permissions.checked.map((c) => c.$2).toSet(), contains(Permission.viewReports));
    });

    test('a session is required', () async {
      expect((await TestApp(devUserId: null).get('/dashboard?from=2026-10-01&to=2026-10-02')).statusCode, 401);
    });
  });
}
