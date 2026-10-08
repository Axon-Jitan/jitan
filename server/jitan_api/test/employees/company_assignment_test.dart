import 'dart:convert';

import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/auth/permission.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _path = '/companies/1/employees/2/assignments/companies';

/// HR user 9 manages Almeco (1). Employee 2 belongs to Almeco. PCA (2) is
/// active, Akwa (3) inactive, Proceq (4) inactive but already assigned.
TestApp _app() {
  final app = TestApp(devUserId: 9, activeUserIds: {9});
  app.companies.existingIds = {1, 2, 3, 4};
  app.employees.members = {(1, 2)};
  app.assignments.companies = {
    1: (name: 'Almeco', active: true),
    2: (name: 'PCA', active: true),
    3: (name: 'Akwa', active: false),
    4: (name: 'Proceq', active: false),
  };
  app.assignments.userCompanies[(2, 1)] = 11;
  app.assignments.userCompanies[(2, 4)] = 14;
  return app;
}

Future<List<(int, String, bool, bool)>> _options(Response response) async => [
  for (final o in (await jsonBody(response))['options']! as List<Object?>)
    if (o case {'id': final int id, 'name': final String name, 'isActive': final bool a, 'isAssigned': final bool s})
      (id, name, a, s),
];

String _add(List<int> ids) => jsonEncode({'ids': ids});

void main() {
  group('GET company assignments', () {
    test('lists active companies and current memberships (inactive only when assigned)', () async {
      final response = await _app().get(_path);

      expect(response.statusCode, 200);
      expect(await _options(response), [
        (1, 'Almeco', true, true),
        (2, 'PCA', true, false),
        (4, 'Proceq', false, true),
      ]);
    });

    test('company-scoped: needs the permission in that company; another company\'s employee is 404', () async {
      final app = _app();

      await app.get(_path);
      expect(app.permissions.checked.last, (9, Permission.manageEmployeeAssignments, 1));
      expect((await app.get('/companies/2/employees/2/assignments/companies')).statusCode, 404);

      app.permissions.deniedCompanies = {1};
      expect((await app.get(_path)).statusCode, 403);
    });
  });

  group('POST company assignments (adds only)', () {
    test('adds the employee to PCA, audited with user, company and membership', () async {
      final app = _app();

      final response = await app.post(_path, _add([2]));

      expect(response.statusCode, 200);
      expect((await _options(response)).firstWhere((o) => o.$1 == 2).$4, isTrue);
      final event = app.audit.events.single;
      expect(event.type, AuditEventType.companyAssigned);
      expect(event.actorUserId, 9);
      expect(event.references, {
        EventLogReference.user: 2,
        EventLogReference.company: 2,
        EventLogReference.userCompany: app.assignments.userCompanies[(2, 2)],
      });
      expect(app.transactions.outcomes, ['commit']);
    });

    test('needs the permission in the target company too', () async {
      final app = _app()..permissions.deniedCompanies = {2};

      final response = await app.post(_path, _add([2]));

      expect(response.statusCode, 403);
      expect(app.assignments.userCompanies.containsKey((2, 2)), isFalse);
      expect(app.audit.events, isEmpty);
    });

    test('existing memberships are skipped, never duplicated or removed', () async {
      final app = _app();

      final response = await app.post(_path, _add([1, 4]));

      expect(response.statusCode, 200);
      expect(app.audit.events, isEmpty, reason: 'nothing changed');
      expect(app.assignments.userCompanies.keys.where((k) => k.$1 == 2), hasLength(2));
    });

    test('a concurrent add of the same company is not duplicated or audited twice', () async {
      final app = _app()..assignments.raceOnCompany = 2;

      expect((await app.post(_path, _add([2]))).statusCode, 200);
      expect(app.audit.events, isEmpty);
    });

    test('inactive, MFD or unknown companies are refused on the ids field', () async {
      for (final ids in [[3], [99], [2, 99]]) {
        final app = _app();
        final response = await app.post(_path, _add(ids));
        expect(response.statusCode, 400, reason: '$ids');
        expect((await jsonBody(response))['error'], containsPair('field', 'ids'));
        expect(app.audit.events, isEmpty);
      }
    });

    test('empty, malformed or oversized requests are refused', () async {
      final app = _app();

      expect((await app.post(_path, _add([]))).statusCode, 400);
      expect((await app.post(_path, jsonEncode({'ids': ['2']}))).statusCode, 400);
      expect((await app.post(_path, '{oops')).statusCode, 400);
      expect((await app.post(_path, _add([for (var i = 1; i <= 101; i++) i]))).statusCode, 400);
    });

    test('another company\'s employee is 404 and nothing is written', () async {
      final app = _app();

      expect((await app.post('/companies/2/employees/2/assignments/companies', _add([2]))).statusCode, 404);
      expect(app.audit.events, isEmpty);
    });
  });
}
