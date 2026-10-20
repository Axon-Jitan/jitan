import 'dart:convert';

import 'package:jitan_api/src/auth/permission.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

void main() {
  test('listing members needs viewGroups; finding and changing them needs manageGroups; not company-scoped', () async {
    final app = TestApp(allowPermissions: false);

    for (final response in [
      await app.get('/groups/3/members'),
      await app.get('/groups/3/candidates?search=an'),
      await app.post('/groups/3/members', jsonEncode({'ids': [1]})),
      await app.delete('/groups/3/members/7'),
    ]) {
      expect(response.statusCode, 403);
    }
    expect(
      app.permissions.checked.map((c) => (c.$2, c.$3)).toSet(),
      {(Permission.viewGroups, null), (Permission.manageGroups, null)},
      reason: 'refused before any company is looked at',
    );
  });

  test('a malformed add body is a bad request', () async {
    final app = TestApp();

    expect((await app.post('/groups/3/members', '{')).statusCode, 400);
    expect((await app.post('/groups/3/members', jsonEncode({'ids': 'all'}))).statusCode, 400);
  });

  test('ids too large for an int are 404', () async {
    final app = TestApp();

    expect((await app.get('/groups/99999999999999999999/members')).statusCode, 404);
    expect((await app.delete('/groups/3/members/99999999999999999999')).statusCode, 404);
  });
}
