import 'dart:convert';

import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _path = '/schedules/groups/2';

TestApp _app({bool allow = true}) {
  final app = TestApp(allowPermissions: allow);
  app.schedules.days = const [(id: 1, name: 'Monday'), (id: 2, name: 'Tuesday')];
  return app;
}

Map<String, Object?> _workHours({
  List<Map<String, Object?>> days = const [
    {'dayId': 1, 'start': '08:00', 'finish': '16:30'},
  ],
  int startTolerance = 10,
  int finishTolerance = 10,
  int startInterval = 15,
  int finishInterval = 15,
  String favour = 'company',
}) => {
  'days': days,
  'startToleranceMinutes': startTolerance,
  'finishToleranceMinutes': finishTolerance,
  'startIntervalMinutes': startInterval,
  'finishIntervalMinutes': finishInterval,
  'favour': favour,
};

Future<Map<String, Object?>> _error(TestApp app, String path, Object body) async {
  final response = await app.put(path, jsonEncode(body));
  return {'status': response.statusCode, ...(await jsonBody(response))['error']! as Map<String, Object?>};
}

void main() {
  group('PUT work hours: rejected before any write', () {
    for (final (name, body, field) in [
      ('no days', _workHours(days: const []), 'days'),
      ('an unknown day', _workHours(days: const [{'dayId': 9, 'start': '08:00', 'finish': '16:30'}]), 'days'),
      (
        'a day twice',
        _workHours(days: const [
          {'dayId': 1, 'start': '08:00', 'finish': '16:30'},
          {'dayId': 1, 'start': '09:00', 'finish': '17:00'},
        ]),
        'days',
      ),
      ('a time that is not HH:mm', _workHours(days: const [{'dayId': 1, 'start': '8:00', 'finish': '16:30'}]), 'days'),
      ('24:00', _workHours(days: const [{'dayId': 1, 'start': '08:00', 'finish': '24:00'}]), 'days'),
      ('finish not after start', _workHours(days: const [{'dayId': 1, 'start': '16:30', 'finish': '16:30'}]), 'days'),
      ('a tolerance not in the list', _workHours(startTolerance: 7), 'startToleranceMinutes'),
      ('a finish tolerance not in the list', _workHours(finishTolerance: 20), 'finishToleranceMinutes'),
      ('an interval not in the list', _workHours(startInterval: 20), 'startIntervalMinutes'),
      ('a finish interval not in the list', _workHours(finishInterval: 45), 'finishIntervalMinutes'),
    ]) {
      test('$name → 400 naming "$field"', () async {
        final error = await _error(_app(), '$_path/work-hours', body);

        expect(error, containsPair('status', 400));
        expect(error, containsPair('code', 'validation_failed'));
        expect(error, containsPair('field', field));
      });
    }

    test('a favour other than company or employee is a bad request', () async {
      for (final favour in ['mixed', 'nobody']) {
        final error = await _error(_app(), '$_path/work-hours', _workHours(favour: favour));
        expect(error, containsPair('status', 400), reason: favour);
      }
    });

    test('malformed JSON or a missing field is a bad request', () async {
      final app = _app();
      expect((await app.put('$_path/work-hours', '{')).statusCode, 400);
      expect((await app.put('$_path/work-hours', jsonEncode({'days': []}))).statusCode, 400);
    });
  });

  group('PUT breaks: rejected before any write', () {
    for (final (name, day) in [
      ('a length not in the list', {'dayId': 1, 'usualStart': '12:00', 'lengthMinutes': 40}),
      ('a time that is not HH:mm', {'dayId': 1, 'usualStart': '12h', 'lengthMinutes': 30}),
      ('an unknown day', {'dayId': 9, 'usualStart': '12:00', 'lengthMinutes': 30}),
    ]) {
      test('$name → 400 naming "days"', () async {
        final error = await _error(_app(), '$_path/breaks', {'days': [day]});

        expect(error, containsPair('code', 'validation_failed'));
        expect(error, containsPair('field', 'days'));
      });
    }
  });

  group('permissions and paths', () {
    test('every write needs manageSchedules, not company-scoped', () async {
      final app = _app(allow: false);

      expect((await app.put('$_path/work-hours', jsonEncode(_workHours()))).statusCode, 403);
      expect((await app.delete('$_path/work-hours')).statusCode, 403);
      expect((await app.put('$_path/breaks', jsonEncode({'days': []}))).statusCode, 403);
      expect((await app.delete('$_path/breaks')).statusCode, 403);
      expect(app.permissions.checked.map((c) => c.$2).toSet(), {Permission.manageSchedules});
      expect(app.permissions.checked.map((c) => c.$3).toSet(), {null});
    });

    test('a group id too large for an int is 404', () async {
      final response = await _app().put('/schedules/groups/99999999999999999999/work-hours', jsonEncode(_workHours()));

      expect(response.statusCode, 404);
    });
  });

  test('request bodies round-trip through the shared models', () {
    final work = SetWorkHoursRequest.fromJson(_workHours(favour: 'employee'));
    expect(work.favour, ScheduleRoundingFavour.employee);
    expect(SetWorkHoursRequest.fromJson(work.toJson()).days.single.finish, '16:30');

    final breaks = SetBreaksRequest.fromJson({
      'days': [
        {'dayId': 1, 'usualStart': '12:00', 'lengthMinutes': 30},
      ],
    });
    expect(SetBreaksRequest.fromJson(breaks.toJson()).days.single.lengthMinutes, 30);
  });
}
