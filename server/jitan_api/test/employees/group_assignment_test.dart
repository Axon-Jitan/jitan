import 'dart:convert';

import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/auth/permission.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _path = '/companies/1/employees/2/assignments/groups';

/// HR user 9 manages Almeco (1); employee 2 belongs to Almeco. Groups are
/// universal: White collar (1) assigned, Blue collar (2) active, Interim (3)
/// inactive, Retired (4) inactive but assigned.
TestApp _app() {
  final app = TestApp(devUserId: 9, activeUserIds: {9});
  app.companies.existingIds = {1, 2};
  app.employees.members = {(1, 2)};
  app.assignments.groups = {
    1: (name: 'White collar', active: true),
    2: (name: 'Blue collar', active: true),
    3: (name: 'Interim', active: false),
    4: (name: 'Retired', active: false),
  };
  app.assignments.userGroups[(2, 1)] = 21;
  app.assignments.userGroups[(2, 4)] = 24;
  return app;
}

Future<List<(int, String, bool, bool)>> _options(Response response) async => [
  for (final o in (await jsonBody(response))['options']! as List<Object?>)
    if (o case {'id': final int id, 'name': final String name, 'isActive': final bool a, 'isAssigned': final bool s})
      (id, name, a, s),
];

String _add(List<int> ids) => jsonEncode({'ids': ids});

void main() {
  group('GET group assignments', () {
    test('lists all active groups (no company filter) and inactive ones only when assigned', () async {
      final response = await _app().get(_path);

      expect(response.statusCode, 200);
      expect(await _options(response), [
        (2, 'Blue collar', true, false),
        (4, 'Retired', false, true),
        (1, 'White collar', true, true),
      ]);
    });

    test('company-scoped: needs the permission in the path company; another company\'s employee is 404', () async {
      final app = _app();

      await app.get(_path);
      expect(app.permissions.checked.last, (9, Permission.manageEmployeeAssignments, 1));
      expect((await app.get('/companies/2/employees/2/assignments/groups')).statusCode, 404);

      app.permissions.deniedCompanies = {1};
      expect((await app.get(_path)).statusCode, 403);
    });
  });

  group('POST group assignments (adds only)', () {
    test('adds a group, audited with user, group and userGroup', () async {
      final app = _app();

      final response = await app.post(_path, _add([2]));

      expect(response.statusCode, 200);
      expect((await _options(response)).firstWhere((o) => o.$1 == 2).$4, isTrue);
      final event = app.audit.events.single;
      expect(event.type, AuditEventType.groupAssigned);
      expect(event.actorUserId, 9);
      expect(event.references, {
        EventLogReference.user: 2,
        EventLogReference.group: 2,
        EventLogReference.userGroup: app.assignments.userGroups[(2, 2)],
      });
      expect(app.transactions.outcomes, ['commit']);
    });

    test('a group grants no company access: no membership is written, only the path company is checked', () async {
      final app = _app();

      await app.post(_path, _add([2]));

      expect(app.assignments.userCompanies, isEmpty);
      expect(app.permissions.checked.map((c) => c.$3).toSet(), {1});
    });

    test('existing groups are skipped, never duplicated or removed', () async {
      final app = _app();

      final response = await app.post(_path, _add([1, 4]));

      expect(response.statusCode, 200);
      expect(app.audit.events, isEmpty, reason: 'nothing changed');
      expect(app.assignments.userGroups.keys.where((k) => k.$1 == 2), hasLength(2));
    });

    test('inactive, MFD or unknown groups are refused on the ids field', () async {
      for (final ids in [[3], [99], [2, 99]]) {
        final app = _app();
        final response = await app.post(_path, _add(ids));
        expect(response.statusCode, 400, reason: '$ids');
        expect((await jsonBody(response))['error'], containsPair('field', 'ids'));
        expect(app.audit.events, isEmpty);
      }
    });

    test('denied in the path company, or another company\'s employee: nothing is written', () async {
      final denied = _app()..permissions.deniedCompanies = {1};
      expect((await denied.post(_path, _add([2]))).statusCode, 403);
      expect(denied.assignments.userGroups.containsKey((2, 2)), isFalse);

      final other = _app();
      expect((await other.post('/companies/2/employees/2/assignments/groups', _add([2]))).statusCode, 404);
      expect(other.audit.events, isEmpty);
    });

    test('a deadlock victim is retried as a whole: one row, one audit', () async {
      final app = _app()..assignments.groupDeadlocks = 2;

      expect((await app.post(_path, _add([2]))).statusCode, 200);

      expect(app.transactions.outcomes, ['rollback', 'rollback', 'commit']);
      expect(app.audit.events, hasLength(1));
    });

    test('a deadlock that keeps recurring fails after three attempts', () async {
      final app = _app()..assignments.groupDeadlocks = 3;

      expect((await app.post(_path, _add([2]))).statusCode, 500);
      expect(app.transactions.outcomes, ['rollback', 'rollback', 'rollback']);
      expect(app.audit.events, isEmpty);
    });

    test('existing groups are removable; removal is a soft delete, audited, and reversible', () async {
      final app = _app();
      final options = (await jsonBody(await app.get(_path)))['options']! as List<Object?>;
      expect(
        [for (final o in options.cast<Map<String, Object?>>()) if (o['isRemovable'] == true) o['name']],
        ['Retired', 'White collar'],
      );

      final removed = await app.delete('$_path/1');

      expect(removed.statusCode, 200);
      expect(app.assignments.removedGroups, {(2, 1): 21}, reason: 'Active = 0, MFD = 1, row kept');
      expect(app.audit.events.single.type, AuditEventType.groupRemoved);
      expect(app.audit.events.single.references, {
        EventLogReference.user: 2,
        EventLogReference.group: 1,
        EventLogReference.userGroup: 21,
      });

      await app.post(_path, _add([1]));

      expect(app.assignments.userGroups[(2, 1)], 21, reason: 'reactivated, not duplicated');
      expect(app.audit.events.last.type, AuditEventType.groupAssigned);
    });

    test("removing a group needs the permission in the path company; another company's employee is 404", () async {
      final denied = _app()..permissions.deniedCompanies = {1};
      expect((await denied.delete('$_path/1')).statusCode, 403);
      expect(denied.assignments.userGroups.containsKey((2, 1)), isTrue);

      expect((await _app().delete('/companies/2/employees/2/assignments/groups/1')).statusCode, 404);
    });

    test('empty or malformed requests are refused', () async {
      final app = _app();

      expect((await app.post(_path, _add([]))).statusCode, 400);
      expect((await app.post(_path, '{oops')).statusCode, 400);
    });
  });
}
