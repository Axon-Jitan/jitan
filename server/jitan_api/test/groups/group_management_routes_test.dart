import 'dart:convert';

import 'package:jitan_api/src/auth/permission.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

/// Create group's body: the name, an employee and the work hours.
String _create(String name) => jsonEncode({
  'name': name,
  'employeeIds': [11],
  'schedule': {
    'workHours': {
      'days': [
        {'dayId': 1, 'start': '08:00', 'finish': '16:30'},
      ],
      'arrivalToleranceMinutes': 0,
      'leavingToleranceMinutes': 0,
    },
    'breakMinutes': 30,
  },
});

Future<Map<String, Object?>> _error(Future<Response> request) async {
  final response = await request;
  return {'status': response.statusCode, ...(await jsonBody(response))['error']! as Map<String, Object?>};
}

void main() {
  group('names are checked before any write', () {
    for (final (name, value) in [('empty', '   '), ('too long', 'x' * 101), ('too long in characters', '😀' * 101)]) {
      test('$name → 400 naming "name"', () async {
        final app = TestApp();

        for (final request in [
          app.post('/groups', _create(value)),
          app.put('/groups/3', jsonEncode({'name': value})),
        ]) {
          final error = await _error(request);
          expect(error, containsPair('status', 400));
          expect(error, containsPair('code', 'validation_failed'));
          expect(error, containsPair('field', 'name'));
        }
      });
    }

    test('a missing name, employees or work hours, or malformed JSON, is a bad request', () async {
      final app = TestApp();

      expect((await app.post('/groups', jsonEncode({}))).statusCode, 400);
      expect((await app.post('/groups', jsonEncode({'name': 'Drivers'}))).statusCode, 400, reason: 'every group has work hours');
      expect((await app.post('/groups', '{')).statusCode, 400);
    });
  });

  test('every change needs manageGroups, not company-scoped; the overview needs viewGroups', () async {
    final app = TestApp(allowPermissions: false);

    for (final response in [
      await app.post('/groups', _create('Drivers')),
      await app.put('/groups/3', jsonEncode({'name': 'Drivers'})),
      await app.post('/groups/3/deactivate', ''),
      await app.post('/groups/3/reactivate', ''),
      await app.get('/groups/overview'),
    ]) {
      expect(response.statusCode, 403);
    }
    expect(
      app.permissions.checked.map((c) => (c.$2, c.$3)).toSet(),
      {(Permission.manageGroups, null), (Permission.viewGroups, null)},
    );
  });

  test('a group id too large for an int is 404', () async {
    final response = await TestApp().post('/groups/99999999999999999999/deactivate', '');

    expect(response.statusCode, 404);
  });
}
