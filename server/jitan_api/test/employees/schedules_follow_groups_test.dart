import 'dart:convert';

import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _groups = '/companies/1/employees/2/assignments/groups';
const _source = '/companies/1/employees/2/assignments/schedule-source';

/// HR user 9 manages Almeco (1); employee 2 is in White collar (1); Blue
/// collar (2) is active and not assigned.
TestApp _app() {
  final app = TestApp(devUserId: 9, activeUserIds: {9});
  app.companies.existingIds = {1};
  app.employees.members = {(1, 2)};
  app.assignments.groups = {
    1: (name: 'White collar', active: true),
    2: (name: 'Blue collar', active: true),
  };
  app.assignments.userGroups[(2, 1)] = 21;
  return app;
}

void main() {
  group('the employee\'s schedules follow their groups', () {
    test('adding a group brings the schedules in line, once, in the same transaction', () async {
      final app = _app();

      await app.post(_groups, jsonEncode({'ids': [2]}));

      expect(app.scheduleSync.groupChanges, [(9, 2)]);
      expect(app.transactions.outcomes, ['commit']);
    });

    test('adding only groups the employee already has changes nothing, so nothing is synced', () async {
      final app = _app();

      await app.post(_groups, jsonEncode({'ids': [1]}));

      expect(app.scheduleSync.groupChanges, isEmpty);
    });

    test('removing a group brings the schedules in line; removing one already gone does not', () async {
      final app = _app();

      await app.delete('$_groups/1');
      await app.delete('$_groups/2');

      expect(app.scheduleSync.groupChanges, [(9, 2)]);
    });

    test('a new employee with a group gets its schedule; without a group nothing is synced', () async {
      final app = TestApp(devUserId: 9, activeUserIds: {9});
      app.companies.existingIds = {7};
      app.groups.groups = const [GroupSummary(id: 3, name: 'White collar')];
      String body({int? groupId}) =>
          jsonEncode({'firstName': 'A', 'lastName': 'B', 'code': 'C${groupId ?? 0}', 'groupId': groupId, 'phone': null});

      expect((await app.post('/companies/7/employees', body(groupId: 3))).statusCode, 201);
      expect((await app.post('/companies/7/employees', body())).statusCode, 201);

      expect(app.scheduleSync.groupChanges, hasLength(1));
      expect(app.scheduleSync.groupChanges.single.$1, 9);
    });
  });

  group('Schedules come from', () {
    test('GET lists the employee\'s active groups and the current source, company-scoped', () async {
      final app = _app()..assignments.userGroups[(2, 2)] = 22;
      app.scheduleSync.currentSourceGroupId = 2;

      final response = await app.get(_source);

      expect(response.statusCode, 200);
      final source = ScheduleSourceResponse.fromJson(await jsonBody(response));
      expect([for (final g in source.groups) g.name], unorderedEquals(['White collar', 'Blue collar']));
      expect(source.sourceGroupId, 2);
      expect(app.permissions.checked.last, (9, Permission.manageEmployeeAssignments, 1));
    });

    test('PUT gives the employee the chosen group\'s schedule, in a transaction', () async {
      final app = _app();

      final response = await app.put(_source, jsonEncode({'groupId': 1}));

      expect(response.statusCode, 200);
      expect(app.scheduleSync.sources, [(9, 2, 1)]);
      expect(app.transactions.outcomes, ['commit']);
    });

    test('a malformed body is a bad request; another company\'s employee is 404; no permission is 403', () async {
      expect((await _app().put(_source, jsonEncode({}))).statusCode, 400);
      expect((await _app().put('/companies/1/employees/5/assignments/schedule-source', jsonEncode({'groupId': 1}))).statusCode, 404);
      final denied = _app()..permissions.deniedCompanies = {1};
      expect((await denied.put(_source, jsonEncode({'groupId': 1}))).statusCode, 403);
      expect(denied.scheduleSync.sources, isEmpty);
    });
  });
}
