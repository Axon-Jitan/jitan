import 'dart:convert';

import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/auth/permission.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _path = '/companies/1/employees/2/assignments/language';

/// HR user 9 manages Almeco (1); employee 2 belongs to Almeco and has
/// Nederlands (row 50). English, Nederlands, Français active; Deutsch
/// inactive.
TestApp _app() {
  final app = TestApp(devUserId: 9, activeUserIds: {9});
  app.companies.existingIds = {1, 2};
  app.employees.members = {(1, 2)};
  app.userLanguages.languages = {
    1: (name: 'English', code: 'en', active: true),
    2: (name: 'Nederlands', code: 'nl', active: true),
    3: (name: 'Français', code: 'fr', active: true),
    4: (name: 'Deutsch', code: 'de', active: false),
  };
  app.userLanguages.rows[2] = [(userLanguageId: 50, languageId: 2)];
  return app;
}

String _set(int languageId) => jsonEncode({'languageId': languageId});

void main() {
  group('GET language assignment', () {
    test('lists active languages with their codes; the current one is assigned', () async {
      final app = _app();

      final response = await app.get(_path);

      expect(response.statusCode, 200);
      final options = (await jsonBody(response))['options']! as List<Object?>;
      expect([for (final o in options.cast<Map<String, Object?>>()) (o['name'], o['code'], o['isAssigned'])], [
        ('English', 'en', false),
        ('Français', 'fr', false),
        ('Nederlands', 'nl', true),
      ]);
      expect(app.permissions.checked.last, (9, Permission.manageEmployeeAssignments, 1));
    });

    test('company-scoped: another company\'s employee is 404, denied is 403', () async {
      final app = _app();
      expect((await app.get('/companies/2/employees/2/assignments/language')).statusCode, 404);

      app.permissions.deniedCompanies = {1};
      expect((await app.get(_path)).statusCode, 403);
    });
  });

  group('PUT language assignment (preference update)', () {
    test('replaces Nederlands with Français in the same row, audited generically', () async {
      final app = _app();

      final response = await app.put(_path, _set(3));

      expect(response.statusCode, 200);
      expect(app.userLanguages.rows[2], [(userLanguageId: 50, languageId: 3)], reason: 'updated in place, not deleted');
      final event = app.audit.events.single;
      expect(event.type, AuditEventType.languageChanged);
      expect(event.actorUserId, 9);
      expect(event.references, {EventLogReference.user: 2});
      expect(app.employees.lockedUsers, [2]);
      expect(app.transactions.outcomes, ['commit']);
    });

    test('an employee without a language gets one row', () async {
      final app = _app()..userLanguages.rows.remove(2);

      expect((await app.put(_path, _set(1))).statusCode, 200);

      expect(app.userLanguages.rows[2]!.map((r) => r.languageId), [1]);
      expect(app.audit.events, hasLength(1));
    });

    test('choosing the current language changes and audits nothing', () async {
      final app = _app();

      expect((await app.put(_path, _set(2))).statusCode, 200);

      expect(app.audit.events, isEmpty);
    });

    test('inactive, MFD or unknown languages are refused on languageId', () async {
      for (final id in [4, 99]) {
        final app = _app();
        final response = await app.put(_path, _set(id));
        expect(response.statusCode, 400, reason: '$id');
        expect((await jsonBody(response))['error'], containsPair('field', 'languageId'));
        expect(app.userLanguages.rows[2], [(userLanguageId: 50, languageId: 2)]);
        expect(app.audit.events, isEmpty);
      }
    });

    test('several languages (inconsistent data) is a 409, nothing is picked or changed', () async {
      final app = _app();
      app.userLanguages.rows[2] = [(userLanguageId: 50, languageId: 2), (userLanguageId: 51, languageId: 1)];

      final response = await app.put(_path, _set(3));

      expect(response.statusCode, 409);
      expect((await jsonBody(response))['error'], containsPair('code', 'configuration_error'));
      expect(app.audit.events, isEmpty);
      expect(app.transactions.outcomes, ['rollback']);
    });

    test('denied or another company\'s employee: nothing is written', () async {
      final denied = _app()..permissions.deniedCompanies = {1};
      expect((await denied.put(_path, _set(3))).statusCode, 403);
      expect(denied.audit.events, isEmpty);

      final other = _app();
      expect((await other.put('/companies/2/employees/2/assignments/language', _set(3))).statusCode, 404);
      expect(other.userLanguages.rows[2], [(userLanguageId: 50, languageId: 2)]);
    });

    test('malformed body is refused', () async {
      final app = _app();

      expect((await app.put(_path, jsonEncode({'languageId': 'fr'}))).statusCode, 400);
      expect((await app.put(_path, '{oops')).statusCode, 400);
    });
  });
}
