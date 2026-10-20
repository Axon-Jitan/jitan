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
  int arrivalTolerance = 1,
  int leavingTolerance = 5,
  Object? startRounding = const {'intervalMinutes': 15, 'roundUp': true},
  Object? finishRounding,
}) => {
  'days': days,
  'arrivalToleranceMinutes': arrivalTolerance,
  'leavingToleranceMinutes': leavingTolerance,
  'startRounding': startRounding,
  'finishRounding': finishRounding,
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
      ('a negative arrival tolerance', _workHours(arrivalTolerance: -1), 'arrivalToleranceMinutes'),
      ('a leaving tolerance over 60', _workHours(leavingTolerance: 61), 'leavingToleranceMinutes'),
      ('a start interval not in the list', _workHours(startRounding: {'intervalMinutes': 7, 'roundUp': true}), 'startRounding'),
      ('a finish interval not in the list', _workHours(finishRounding: {'intervalMinutes': 45, 'roundUp': false}), 'finishRounding'),
    ]) {
      test('$name → 400 naming "$field"', () async {
        final error = await _error(_app(), '$_path/work-hours', body);

        expect(error, containsPair('status', 400));
        expect(error, containsPair('code', 'validation_failed'));
        expect(error, containsPair('field', field));
      });
    }

    test('a rounding that is not an object (or null) is a bad request', () async {
      final error = await _error(_app(), '$_path/work-hours', _workHours(startRounding: 'up'));

      expect(error, containsPair('status', 400));
    });

    test('malformed JSON or a missing field is a bad request', () async {
      final app = _app();
      expect((await app.put('$_path/work-hours', '{')).statusCode, 400);
      expect((await app.put('$_path/work-hours', jsonEncode({'days': []}))).statusCode, 400);
    });
  });

  group('PUT a whole schedule: rejected before any write', () {
    test('a break length not in the list → 400 naming "breakMinutes"', () async {
      final error = await _error(_app(), _path, {'workHours': _workHours(), 'breakMinutes': 40});

      expect(error, containsPair('status', 400));
      expect(error, containsPair('code', 'validation_failed'));
      expect(error, containsPair('field', 'breakMinutes'));
    });

    test('a break as long as the working day → 400 naming "breakMinutes"', () async {
      final error = await _error(_app(), _path, {
        'workHours': _workHours(days: const [{'dayId': 1, 'start': '08:00', 'finish': '08:30'}]),
        'breakMinutes': 30,
      });

      expect(error, containsPair('field', 'breakMinutes'));
    });

    test('invalid work hours are named as in PUT work-hours', () async {
      final error = await _error(_app(), _path, {'workHours': _workHours(days: const []), 'breakMinutes': 30});

      expect(error, containsPair('field', 'days'));
    });

    test('a missing workHours or breakMinutes is a bad request', () async {
      expect((await _app().put(_path, jsonEncode({'breakMinutes': 30}))).statusCode, 400);
      expect((await _app().put(_path, jsonEncode({'workHours': _workHours()}))).statusCode, 400);
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
    final work = SetWorkHoursRequest.fromJson(_workHours(finishRounding: {'intervalMinutes': 30, 'roundUp': false}));
    expect((work.startRounding!.roundUp, work.finishRounding!.intervalMinutes, work.arrivalToleranceMinutes), (true, 30, 1));
    expect(SetWorkHoursRequest.fromJson(work.toJson()).days.single.finish, '16:30');

    final breaks = SetBreaksRequest.fromJson({
      'days': [
        {'dayId': 1, 'usualStart': '12:00', 'lengthMinutes': 30},
      ],
    });
    expect(SetBreaksRequest.fromJson(breaks.toJson()).days.single.lengthMinutes, 30);
  });
}
