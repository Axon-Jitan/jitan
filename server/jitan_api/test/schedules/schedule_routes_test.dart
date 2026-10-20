import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_api/src/schedules/schedule_names.dart';
import 'package:jitan_api/src/schedules/schedule_repository.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _days = <DayRow>[
  (id: 7, name: 'Sunday'),
  (id: 1, name: 'Monday'),
  (id: 2, name: 'Tuesday'),
];

UserScheduleRow _row(int userId, int scheduleId, String type, int dayId, String start, String stop, {int margin = 0}) {
  final [sh, sm] = start.split(':').map(int.parse).toList();
  final [eh, em] = stop.split(':').map(int.parse).toList();
  return (
    userId: userId,
    scheduleId: scheduleId,
    typeName: type,
    dayId: dayId,
    startHour: sh,
    startMinute: sm,
    stopHour: eh,
    stopMinute: em,
    marginMinutes: margin,
  );
}

/// Blue collar (2): employees 10 and 11 share Monday 08:00–16:30 (±10, 15 min,
/// favours the company) and a 30-minute break. White collar (1): nobody is
/// only in it.
TestApp _app() {
  final app = TestApp();
  app.groups.groups = const [GroupSummary(id: 1, name: 'White collar'), GroupSummary(id: 2, name: 'Blue collar')];
  app.schedules
    ..days = _days
    ..members = const [(groupId: 2, userId: 10), (groupId: 2, userId: 11)]
    ..userSchedules = [
      for (final user in [10, 11]) ...[
        _row(user, 100, ScheduleTypeNames.workStart, 1, '08:00', '16:30', margin: 10),
        _row(user, 101, ScheduleTypeNames.workFinish, 1, '08:00', '16:30', margin: 10),
        _row(user, 102, ScheduleTypeNames.breakTime, 1, '12:00', '12:30'),
      ],
    ]
    ..rules = const [
      (scheduleId: 100, intervalMinutes: 15, roundUp: true),
      (scheduleId: 101, intervalMinutes: 15, roundUp: false),
    ];
  return app;
}

Future<Map<int, GroupSchedule>> _groups(TestApp app) async {
  final response = await app.get('/schedules');
  expect(response.statusCode, 200);
  final list = GroupScheduleListResponse.fromJson(await jsonBody(response));
  return {for (final g in list.groups) g.group.id: g};
}

Future<Map<String, Object?>> _error(TestApp app, String path) async {
  final response = await app.get(path);
  return {'status': response.statusCode, ...(await jsonBody(response))['error']! as Map<String, Object?>};
}

void main() {
  group('GET /schedules/options', () {
    test('days Monday first with their weekday, and the form choices', () async {
      final app = _app();

      final response = await app.get('/schedules/options');

      expect(response.statusCode, 200);
      final options = ScheduleOptions.fromJson(await jsonBody(response));
      expect([for (final d in options.days) (d.id, d.name, d.weekday)], [(1, 'Monday', 1), (2, 'Tuesday', 2), (7, 'Sunday', 7)]);
      expect(options.roundingIntervalMinutes, [15, 30, 60]);
      expect(options.toleranceMinutes, [0, 5, 10, 15]);
      expect(options.breakLengthMinutes, [15, 30, 45, 60]);
      expect(app.permissions.checked.last, (1, Permission.viewSchedules, null));
    });

    test('a day name Jitan does not know, or two rows for one weekday, is a configuration error', () async {
      final unknown = _app()..schedules.days = const [(id: 1, name: 'Maandag')];
      final twice = _app()..schedules.days = const [(id: 1, name: 'Monday'), (id: 8, name: 'Monday')];

      expect(await _error(unknown, '/schedules/options'), containsPair('code', 'configuration_error'));
      expect(await _error(twice, '/schedules/options'), containsPair('code', 'configuration_error'));
    });

    test('403 without the permission', () async {
      expect((await TestApp(allowPermissions: false).get('/schedules/options')).statusCode, 403);
    });
  });

  group('GET /schedules', () {
    test('a group whose employees share one set: configured, with work hours, rounding and break', () async {
      final blue = (await _groups(_app()))[2]!;

      expect(blue.status, GroupScheduleStatus.configured);
      expect(blue.singleGroupEmployeeCount, 2);
      final variant = blue.variants.single;
      expect(variant.employeeCount, 2);
      expect(variant.favour, ScheduleRoundingFavour.company);
      final monday = variant.workDays.single;
      expect(monday.day.name, 'Monday');
      expect((monday.start!.time, monday.start!.toleranceMinutes), ('08:00', 10));
      expect((monday.start!.rounding!.intervalMinutes, monday.start!.rounding!.roundUp), (15, true));
      expect((monday.finish!.time, monday.finish!.rounding!.roundUp), ('16:30', false));
      final lunch = variant.breaks.single;
      expect((lunch.day.name, lunch.usualStart, lunch.lengthMinutes), ('Monday', '12:00', 30));
    });

    test('a group nobody is only in: no schedule of its own', () async {
      final white = (await _groups(_app()))[1]!;

      expect(white.status, GroupScheduleStatus.noSingleGroupEmployees);
      expect(white.singleGroupEmployeeCount, 0);
      expect(white.variants, isEmpty);
    });

    test('employees without schedules: noSchedule', () async {
      final app = _app()..schedules.userSchedules = const [];

      final blue = (await _groups(app))[2]!;

      expect((blue.status, blue.singleGroupEmployeeCount), (GroupScheduleStatus.noSchedule, 2));
      expect(blue.variants, isEmpty);
    });

    test('employees with different sets: every set is a variant, largest first, none picked', () async {
      final app = _app();
      app.schedules
        ..members = [...app.schedules.members, (groupId: 2, userId: 12)]
        ..userSchedules = [
          ...app.schedules.userSchedules,
          _row(12, 200, ScheduleTypeNames.workStart, 2, '07:00', '15:30'),
        ];

      final blue = (await _groups(app))[2]!;

      expect(blue.status, GroupScheduleStatus.employeesDiffer);
      expect(blue.singleGroupEmployeeCount, 3);
      expect([for (final v in blue.variants) v.employeeCount], [2, 1]);
      expect(blue.variants.last.workDays.single.day.name, 'Tuesday');
      expect(blue.variants.last.workDays.single.finish, isNull, reason: 'a missing finish row is shown as missing');
    });

    test('an employee with no schedule among others with one is a difference too', () async {
      final app = _app();
      app.schedules.members = [...app.schedules.members, (groupId: 2, userId: 13)];

      final blue = (await _groups(app))[2]!;

      expect(blue.status, GroupScheduleStatus.employeesDiffer);
      expect(blue.variants.last.workDays, isEmpty);
    });

    test('rounding favouring the employee, and mixed rules, are reported as such', () async {
      final employee = _app()
        ..schedules.rules = const [
          (scheduleId: 100, intervalMinutes: 30, roundUp: false),
          (scheduleId: 101, intervalMinutes: 30, roundUp: true),
        ];
      final mixed = _app()
        ..schedules.rules = const [
          (scheduleId: 100, intervalMinutes: 15, roundUp: true),
          (scheduleId: 101, intervalMinutes: 15, roundUp: true),
        ];

      expect((await _groups(employee))[2]!.variants.single.favour, ScheduleRoundingFavour.employee);
      expect((await _groups(mixed))[2]!.variants.single.favour, ScheduleRoundingFavour.mixed);
    });

    test('a start or finish with no rule, or with two, has no rounding (shown as missing)', () async {
      final none = _app()..schedules.rules = const [(scheduleId: 101, intervalMinutes: 15, roundUp: false)];
      final two = _app()
        ..schedules.rules = const [
          (scheduleId: 100, intervalMinutes: 15, roundUp: true),
          (scheduleId: 100, intervalMinutes: 30, roundUp: true),
          (scheduleId: 101, intervalMinutes: 15, roundUp: false),
        ];

      expect((await _groups(none))[2]!.variants.single.workDays.single.start!.rounding, isNull);
      expect((await _groups(two))[2]!.variants.single.workDays.single.start!.rounding, isNull);
    });

    test('two starts on one day in one set is a configuration error, not a guess', () async {
      final app = _app();
      app.schedules.userSchedules = [
        ...app.schedules.userSchedules,
        for (final user in [10, 11]) _row(user, 103, ScheduleTypeNames.workStart, 1, '09:00', '17:00'),
      ];

      expect(await _error(app, '/schedules'), containsPair('code', 'configuration_error'));
    });

    test('403 without the permission; checked without a company (schedules are global)', () async {
      final app = _app();
      await app.get('/schedules');
      expect(app.permissions.checked.last, (1, Permission.viewSchedules, null));

      expect((await TestApp(allowPermissions: false).get('/schedules')).statusCode, 403);
    });
  });
}
