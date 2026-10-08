import 'dart:convert';

import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/auth/permission.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _path = '/companies/1/employees/2/assignments/companies';

/// HR user 9 manages Almeco (1). Employee 2 belongs to Almeco. PCA (2) is
/// active, Akwa (3) inactive. Employees may work for several companies.
TestApp _app() {
  final app = TestApp(devUserId: 9, activeUserIds: {9});
  app.companies.existingIds = {1, 2, 3, 4};
  app.employees.members = {(1, 2)};
  app.assignments.companies = {
    1: (name: 'Almeco', active: true),
    2: (name: 'PCA', active: true),
    3: (name: 'Akwa', active: false),
  };
  app.assignments.userCompanies[(2, 1)] = 11;
  return app;
}

Future<List<(int, String, bool, bool, bool)>> _options(Response response) async => [
  for (final o in (await jsonBody(response))['options']! as List<Object?>)
    if (o case {
      'id': final int id,
      'name': final String name,
      'isAssigned': final bool assigned,
      'isAssignable': final bool assignable,
      'isRemovable': final bool removable,
    })
      (id, name, assigned, assignable, removable),
];

String _add(List<int> ids) => jsonEncode({'ids': ids});

Future<Response> _delete(TestApp app, String path) => app.delete(path);

void main() {
  group('GET company assignments', () {
    test('the current company is assigned but not removable here; other active companies can be added', () async {
      final response = await _app().get(_path);

      expect(response.statusCode, 200);
      expect(await _options(response), [(1, 'Almeco', true, false, false), (2, 'PCA', false, true, false)]);
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

  group('POST company assignments (several companies)', () {
    test('adds PCA as a second company, audited with user, company and membership', () async {
      final app = _app();

      final response = await app.post(_path, _add([2]));

      expect(response.statusCode, 200);
      expect((await _options(response)).firstWhere((o) => o.$1 == 2), (2, 'PCA', true, false, true));
      expect(app.assignments.userCompanies.keys.toSet(), {(2, 1), (2, 2)}, reason: 'one employee, two memberships');
      final event = app.audit.events.single;
      expect(event.type, AuditEventType.companyAssigned);
      expect(event.references, {
        EventLogReference.user: 2,
        EventLogReference.company: 2,
        EventLogReference.userCompany: app.assignments.userCompanies[(2, 2)],
      });
      expect(app.transactions.outcomes, ['commit']);
    });

    test('needs the permission in the target company too', () async {
      final app = _app()..permissions.deniedCompanies = {2};

      expect((await app.post(_path, _add([2]))).statusCode, 403);
      expect(app.assignments.userCompanies.containsKey((2, 2)), isFalse);
      expect(app.audit.events, isEmpty);
    });

    test('a current membership is skipped, never duplicated', () async {
      final app = _app();

      expect((await app.post(_path, _add([1]))).statusCode, 200);
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

    test('empty or malformed requests are refused', () async {
      final app = _app();

      expect((await app.post(_path, _add([]))).statusCode, 400);
      expect((await app.post(_path, '{oops')).statusCode, 400);
    });
  });

  group('DELETE company assignment (soft delete)', () {
    Future<TestApp> withPca() async {
      final app = _app();
      await app.post(_path, _add([2]));
      app.audit.events.clear();
      return app;
    }

    test('removes PCA: kept as a removed row, hidden, audited; the employee and Almeco are untouched', () async {
      final app = await withPca();
      final membership = app.assignments.userCompanies[(2, 2)];

      final response = await _delete(app, '$_path/2');

      expect(response.statusCode, 200);
      expect((await _options(response)).firstWhere((o) => o.$1 == 2), (2, 'PCA', false, true, false));
      expect(app.assignments.removedCompanies, {(2, 2): membership}, reason: 'Active = 0, MFD = 1, row kept');
      expect(app.assignments.userCompanies.keys, [(2, 1)]);
      final event = app.audit.events.single;
      expect(event.type, AuditEventType.companyRemoved);
      expect(event.actorUserId, 9);
      expect(event.references, {
        EventLogReference.user: 2,
        EventLogReference.company: 2,
        EventLogReference.userCompany: membership,
      });
    });

    test('adding PCA again reactivates the same membership, audited as assigned', () async {
      final app = await withPca();
      final membership = app.assignments.userCompanies[(2, 2)];
      await _delete(app, '$_path/2');

      await app.post(_path, _add([2]));

      expect(app.assignments.userCompanies[(2, 2)], membership, reason: 'no second row for the pair');
      expect(app.audit.events.map((e) => e.type), [AuditEventType.companyRemoved, AuditEventType.companyAssigned]);
    });

    test('the company you are working in cannot be removed here, so one company always remains', () async {
      final app = await withPca();

      final response = await _delete(app, '$_path/1');

      expect(response.statusCode, 400);
      expect((await jsonBody(response))['error'], containsPair('field', 'id'));
      expect(app.assignments.userCompanies.containsKey((2, 1)), isTrue);
    });

    test('needs the permission in the removed company too', () async {
      final app = await withPca();
      app.permissions.deniedCompanies = {2};

      expect((await _delete(app, '$_path/2')).statusCode, 403);
      expect(app.assignments.userCompanies.containsKey((2, 2)), isTrue);
      expect(app.audit.events, isEmpty);
    });

    test('removing a membership that is already gone changes nothing', () async {
      final app = _app();

      expect((await _delete(app, '$_path/2')).statusCode, 200);
      expect(app.audit.events, isEmpty);
    });

    test('another company\'s employee is 404', () async {
      final app = await withPca();

      expect((await _delete(app, '/companies/2/employees/3/assignments/companies/1')).statusCode, 404);
    });
  });
}
