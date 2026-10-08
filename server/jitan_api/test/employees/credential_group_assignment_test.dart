import 'dart:convert';

import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/auth/permission.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _path = '/companies/1/employees/2/assignments/credential-groups';

/// HR user 9 manages Almeco (1) and holds HR (2) and Employee (1).
/// Employee 2 belongs to Almeco and PCA (2). Credential groups come from the
/// database: Employee (1) assigned, HR (2) and Admin (3) active, Legacy (4)
/// inactive.
TestApp _app() {
  final app = TestApp(devUserId: 9, activeUserIds: {9});
  app.companies.existingIds = {1, 2};
  app.employees.members = {(1, 2)};
  app.assignments.userCompanies[(2, 1)] = 11;
  app.assignments.userCompanies[(2, 2)] = 12;
  app.assignments.credentialGroups = {
    1: (name: 'Employee', active: true),
    2: (name: 'HR', active: true),
    3: (name: 'Admin', active: true),
    4: (name: 'Legacy', active: false),
  };
  app.assignments.userCredentialGroups[(2, 1)] = 31;
  app.assignments.userCredentialGroups[(9, 1)] = 91;
  app.assignments.userCredentialGroups[(9, 2)] = 92;
  return app;
}

Future<List<(int, String, bool)>> _options(Response response) async => [
  for (final o in (await jsonBody(response))['options']! as List<Object?>)
    if (o case {'id': final int id, 'name': final String name, 'isAssigned': final bool s}) (id, name, s),
];

String _add(List<int> ids) => jsonEncode({'ids': ids});

void main() {
  group('GET credential-group assignments', () {
    test('lists active credential groups from the database with the current assignment', () async {
      final app = _app();

      final response = await app.get(_path);

      expect(response.statusCode, 200);
      expect(await _options(response), [(1, 'Employee', true), (2, 'HR', false), (3, 'Admin', false)]);
      final assignable = [
        for (final o in ((await jsonBody(await app.get(_path)))['options']! as List<Object?>).cast<Map<String, Object?>>())
          if (o['isAssignable'] == true) o['name'],
      ];
      expect(assignable, ['HR'], reason: 'Admin is not held by the actor: not offered');
      expect(app.permissions.checked.last, (9, Permission.manageEmployeeAccess, 1));
    });

    test('needs manageEmployeeAccess in the path company; another company\'s employee is 404', () async {
      final app = _app();
      expect((await app.get('/companies/2/employees/3/assignments/credential-groups')).statusCode, 404);

      app.permissions.deniedCompanies = {1};
      expect((await app.get(_path)).statusCode, 403);
    });
  });

  group('POST credential-group assignments (adds only)', () {
    test('adds HR, audited with user, credential group and userCredGroup', () async {
      final app = _app();

      final response = await app.post(_path, _add([2]));

      expect(response.statusCode, 200);
      expect((await _options(response)).firstWhere((o) => o.$1 == 2).$3, isTrue);
      final event = app.audit.events.single;
      expect(event.type, AuditEventType.credentialGroupAssigned);
      expect(event.actorUserId, 9);
      expect(event.references, {
        EventLogReference.user: 2,
        EventLogReference.credGroup: 2,
        EventLogReference.userCredGroup: app.assignments.userCredentialGroups[(2, 2)],
      });
      expect(app.transactions.outcomes, ['commit']);
    });

    test('user-wide access needs the permission in every company of the employee', () async {
      final app = _app();
      await app.post(_path, _add([2]));
      expect(
        app.permissions.checked.where((c) => c.$2 == Permission.manageEmployeeAccess).map((c) => c.$3).toSet(),
        {1, 2},
      );

      final denied = _app()..permissions.deniedCompanies = {2};
      expect((await denied.post(_path, _add([2]))).statusCode, 403, reason: 'HR of Almeco only cannot grant access that also applies in PCA');
      expect(denied.assignments.userCredentialGroups.containsKey((2, 2)), isFalse);
      expect(denied.audit.events, isEmpty);
    });

    test('no privilege escalation: a group the actor does not hold is refused (403), nothing written', () async {
      final app = _app();

      final response = await app.post(_path, _add([3]));

      expect(response.statusCode, 403);
      expect((await jsonBody(response))['error'], containsPair('code', 'forbidden'));
      expect(app.assignments.userCredentialGroups.containsKey((2, 3)), isFalse);
      expect(app.audit.events, isEmpty);
      expect(app.transactions.outcomes, isEmpty);
    });

    test('mixing a held and a not-held group is refused as a whole', () async {
      final app = _app();

      expect((await app.post(_path, _add([2, 3]))).statusCode, 403);
      expect(app.assignments.userCredentialGroups.containsKey((2, 2)), isFalse);
    });

    test('nobody can raise their own access', () async {
      final app = _app()..employees.members = {(1, 2), (1, 9)};
      app.assignments.userCompanies[(9, 1)] = 19;

      final response = await app.post('/companies/1/employees/9/assignments/credential-groups', _add([3]));

      expect(response.statusCode, 403);
      expect(app.assignments.userCredentialGroups.containsKey((9, 3)), isFalse);
    });

    test('the dev permission evaluator allowing everything does not bypass the rule', () async {
      final app = _app();
      expect(app.permissions.allow, isTrue);

      expect((await app.post(_path, _add([3]))).statusCode, 403);
    });

    test('the assignments permission alone is not enough to change access', () async {
      final app = _app();

      await app.post(_path, _add([2]));

      expect(app.permissions.checked.map((c) => c.$2).toSet(), {Permission.manageEmployeeAccess});
    });

    test('an existing assignment is skipped, never duplicated or removed', () async {
      final app = _app();

      final response = await app.post(_path, _add([1]));

      expect(response.statusCode, 200);
      expect(app.audit.events, isEmpty);
      expect(app.transactions.outcomes, isEmpty, reason: 'nothing to write');
      expect(app.assignments.userCredentialGroups.keys.where((k) => k.$1 == 2), hasLength(1));
    });

    test('inactive, MFD or unknown credential groups are refused on the ids field', () async {
      for (final ids in [[4], [99], [2, 99]]) {
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
}
